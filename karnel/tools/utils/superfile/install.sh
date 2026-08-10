#!/usr/bin/env bash

import "@/utils/log"

SUPERFILE_VERSION="v1.5.0"
SUPERFILE_COMMIT="fe41cef5e9ee5b16e79981540c49f932a3d4d249"
SUPERFILE_REPOSITORY="https://github.com/yorukot/superfile.git"
SUPERFILE_DATA_DIR="$KARNEL_DATA/superfile"
SUPERFILE_BIN="$PREFIX/bin/spf"

_superfile_dependencies() {
  local package binary
  while IFS=: read -r package binary; do
    if ! command -v "$binary" &>/dev/null; then
      if ! pkg install "$package" -y &>>"$KARNEL_CACHE/install_utils.log"; then
        log_error "Failed to install $package"
        return 1
      fi
    fi
  done <<'EOF'
git:git
golang:go
EOF
}

_superfile_binary_owned() {
  local marker="$SUPERFILE_DATA_DIR/.karnel-wrapper-spf"
  [[ -f "$marker" && -f "$SUPERFILE_BIN" ]] || return 1
  [[ "$(sha256sum "$SUPERFILE_BIN" 2>/dev/null)" == "$(<"$marker")" ]]
}

_superfile_verify_ownership() {
  if [[ -e "$SUPERFILE_DATA_DIR" && ! -f "$SUPERFILE_DATA_DIR/.karnel-managed" ]]; then
    log_error "Refusing to replace unowned data directory: $SUPERFILE_DATA_DIR"
    return 1
  fi
  if [[ -e "$SUPERFILE_BIN" ]] && ! _superfile_binary_owned; then
    log_error "Refusing to replace unowned command: $SUPERFILE_BIN"
    return 1
  fi
}

_build_superfile() {
	local staging_dir old_dir temporary_bin
	mkdir -p "$KARNEL_DATA" "$PREFIX/bin" "${KARNEL_CACHE}"
	_superfile_verify_ownership || return 1
  staging_dir="$(mktemp -d "$KARNEL_DATA/.superfile.XXXXXX")" || return 1

  if ! git clone --depth 1 --branch "$SUPERFILE_VERSION" "$SUPERFILE_REPOSITORY" "$staging_dir/source" &>>"$KARNEL_CACHE/install_utils.log" ||
    [[ "$(git -C "$staging_dir/source" rev-parse HEAD)" != "$SUPERFILE_COMMIT" ]] ||
    ! go build -C "$staging_dir/source" -trimpath -ldflags='-s -w' -o "$staging_dir/spf" . &>>"$KARNEL_CACHE/install_utils.log" ||
    [[ ! -x "$staging_dir/spf" ]]; then
    rm -rf "$staging_dir"
    log_error "Failed to build SuperFile $SUPERFILE_VERSION"
    return 1
  fi

	old_dir="$KARNEL_DATA/.superfile.previous.$$"
  if [[ -d "$SUPERFILE_DATA_DIR" ]]; then
    mv "$SUPERFILE_DATA_DIR" "$old_dir" || { rm -rf "$staging_dir"; return 1; }
  fi
	temporary_bin="$(mktemp "$PREFIX/bin/.spf.XXXXXX")" || { rm -rf "$staging_dir"; return 1; }
	if ! mv "$staging_dir/source" "$SUPERFILE_DATA_DIR" ||
		! install -m 755 "$staging_dir/spf" "$temporary_bin" ||
		! mv -f "$temporary_bin" "$SUPERFILE_BIN"; then
		rm -f "$temporary_bin"
		rm -rf "$staging_dir" "$SUPERFILE_DATA_DIR"
		[[ -d "$old_dir" ]] && mv "$old_dir" "$SUPERFILE_DATA_DIR"
		log_error "Failed to replace SuperFile"
		return 1
	fi
	sha256sum "$SUPERFILE_BIN" >"$SUPERFILE_DATA_DIR/.karnel-wrapper-spf" || return 1
	: >"$SUPERFILE_DATA_DIR/.karnel-managed"
	rm -rf "$staging_dir" "$old_dir"
}

install_superfile() {
  if command -v spf &>/dev/null; then
    log_info "SuperFile is already installed"
    return 2
  fi

  log_info "Installing SuperFile $SUPERFILE_VERSION..."
  _superfile_dependencies || return 1
  _build_superfile || return 1
  log_success "SuperFile installed"
}

uninstall_superfile() {
  if [[ ! -e "$SUPERFILE_BIN" && ! -d "$SUPERFILE_DATA_DIR" ]]; then
    log_info "SuperFile is not installed"
    return 2
  fi

  log_info "Uninstalling SuperFile..."
	if _superfile_binary_owned && ! rm -f "$SUPERFILE_BIN"; then
		log_error "Failed to remove SuperFile command"
		return 1
	fi
	if [[ -f "$SUPERFILE_DATA_DIR/.karnel-managed" ]] && ! rm -rf "$SUPERFILE_DATA_DIR"; then
		log_error "Failed to uninstall SuperFile"
		return 1
  fi
  log_success "SuperFile uninstalled"
}

update_superfile() {
  log_info "Updating SuperFile to $SUPERFILE_VERSION..."
  _superfile_dependencies || return 1
  _build_superfile || return 1
  log_success "SuperFile updated"
}

reinstall_superfile() {
  uninstall_superfile || [[ $? -eq 2 ]] || return 1
  install_superfile
}
