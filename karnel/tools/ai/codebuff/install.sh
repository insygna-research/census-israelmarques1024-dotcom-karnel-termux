#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
CODEBUFF_DATA_DIR="$HOME/.local/share/karnel-data/codebuff"

_codebuff_detect_ubuntu_root() {
  local root
  root="$(find /data/data/com.termux -maxdepth 10 -type d \
    -name "rootfs" -path "*/containers/ubuntu/*" 2>/dev/null | head -1)"

  if [ -z "$root" ]; then
    root="$(find /data/data/com.termux -maxdepth 10 -type d \
      -name "ubuntu" -path "*/installed-rootfs/*" 2>/dev/null | head -1)"
  fi

  echo "$root"
}

_codebuff_proot_ubuntu() {
  proot-distro login \
    --shared-tmp \
    ubuntu \
    -- "$@"
}

_get_latest_codebuff_version() {
  curl -fsSL https://api.github.com/repos/CodebuffAI/codebuff-community/releases/latest |
    grep '"tag_name":' | sed -E 's/.*"tag_name":\s*"v([0-9]+\.[0-9]+\.[0-9]+)".*/\1/'
}

_codebuff_install_deps_native() {
  loading "Installing glibc and dependencies" _codebuff_install_deps_native_impl
}

_codebuff_install_deps_native_impl() {
  if [[ ! -f $PREFIX/etc/apt/sources.list.d/glibc.list ]]; then
    if ! pkg install glibc-repo -y &>>"$LOG_FILE"; then
      log_error "Failed to install glibc-repo"
      return 1
    fi
  fi

  if [[ ! -f $PREFIX/glibc/lib/libc.so.6 ]]; then
    if ! pkg install glibc -y &>>"$LOG_FILE"; then
      log_error "Failed to install glibc"
      return 1
    fi
  fi

  declare -A DEPS=(
    ["git"]="git"
    ["curl"]="curl"
    ["tar"]="tar"
    ["clang"]="cc"
  )

  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if ! command -v "$bin_name" &>/dev/null; then
      if ! pkg install "$pkg_name" -y &>>"$LOG_FILE"; then
        log_error "Failed to install $pkg_name"
        return 1
      fi
    fi
  done

  return 0
}

_download_codebuff_binary() {
  loading "Downloading Codebuff" _download_codebuff_binary_impl
}

_download_codebuff_binary_impl() {
  local latest_version
  latest_version=$(_get_latest_codebuff_version)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest Codebuff version"
    return 1
  fi

  mkdir -p "$CODEBUFF_DATA_DIR"

  local tarball="codebuff-linux-arm64.tar.gz"
  local download_url="https://github.com/CodebuffAI/codebuff-community/releases/download/v${latest_version}/${tarball}"

  if ! curl -fsSL "$download_url" -o "$CODEBUFF_DATA_DIR/$tarball" &>>"$LOG_FILE"; then
    log_error "Failed to download Codebuff binary"
    return 1
  fi

  if ! tar -zxf "$CODEBUFF_DATA_DIR/$tarball" -C "$CODEBUFF_DATA_DIR" &>>"$LOG_FILE"; then
    log_error "Failed to extract Codebuff binary"
    return 1
  fi

  rm -f "$CODEBUFF_DATA_DIR/$tarball"

  if [ ! -f "$CODEBUFF_DATA_DIR/codebuff" ]; then
    log_error "Codebuff binary not found after extraction"
    return 1
  fi

  chmod +x "$CODEBUFF_DATA_DIR/codebuff"
  return 0
}

_compile_codebuff_helper() {
  loading "Compiling helper" _compile_codebuff_helper_impl
}

_compile_codebuff_helper_impl() {
  local HELPER_SRC="$KARNEL_PATH/tools/ai/codebuff/helper/codebuff_helper.c"
  if [ ! -f "$HELPER_SRC" ]; then
    log_error "Helper source not found at $HELPER_SRC"
    return 1
  fi

  if ! cc -O2 -o "$PREFIX/bin/codebuff" "$HELPER_SRC" &>>"$LOG_FILE"; then
    log_error "Failed to compile codebuff helper"
    return 1
  fi

  chmod +x "$PREFIX/bin/codebuff"
  return 0
}

_install_codebuff_native() {
  _codebuff_install_deps_native || return 1
  _download_codebuff_binary || return 1
  _compile_codebuff_helper || return 1
  log_success "Codebuff installed natively"
  return 0
}

_install_codebuff_proot() {
  loading "Installing Codebuff (proot-distro)" _install_codebuff_proot_impl
}

_install_codebuff_proot_impl() {
  mkdir -p "$(dirname "$LOG_FILE")"

  if ! command -v proot-distro &>/dev/null; then
    pkg install proot-distro -y &>>"$LOG_FILE"
  fi

  if [ ! -d "$(_codebuff_detect_ubuntu_root)" ]; then
    proot-distro install ubuntu:24.04 &>>"$LOG_FILE"
  fi

  _codebuff_proot_ubuntu /bin/bash -c \
    'apt-get update && apt-get upgrade -y && apt-get install -y curl ca-certificates tar' \
    &>>"$LOG_FILE"

  _codebuff_proot_ubuntu /bin/bash -c '
    export SHELL=/bin/bash
    export TMPDIR=/tmp
    export HOME=/root
    LATEST=$(curl -fsSL https://api.github.com/repos/CodebuffAI/codebuff-community/releases/latest | grep '"'"'tag_name'"'"' | sed -E '"'"'s/.*"tag_name":\s*"v([0-9]+\.[0-9]+\.[0-9]+)".*/\1/'"'"')
    TARBALL=$(mktemp /tmp/codebuff.XXXXXX.tar.gz)
    curl -fsSL "https://github.com/CodebuffAI/codebuff-community/releases/download/v${LATEST}/codebuff-linux-arm64.tar.gz" -o "$TARBALL"
    mkdir -p /root/.codebuff
    tar -zxf "$TARBALL" -C /root/.codebuff
    rm -f "$TARBALL"
    chmod +x /root/.codebuff/codebuff
  ' &>>"$LOG_FILE"

  local ubuntu_root
  ubuntu_root="$(_codebuff_detect_ubuntu_root)"

  if [ -z "$ubuntu_root" ]; then
    log_error "Ubuntu rootfs not found"
    return 1
  fi

  local codebuff_bin="$ubuntu_root/root/.codebuff/codebuff"

  if [ ! -f "$codebuff_bin" ]; then
    log_error "Codebuff binary not found after install"
    return 1
  fi

  local wrapper_src="$KARNEL_PATH/tools/ai/codebuff/bin/codebuff"
  if [ ! -f "$wrapper_src" ]; then
    log_error "Wrapper template not found at $wrapper_src"
    return 1
  fi
  sed "s|__UBUNTU_ROOTFS__|$ubuntu_root|g" "$wrapper_src" >"$PREFIX/bin/codebuff"
  chmod +x "$PREFIX/bin/codebuff"

  if ! grep -q '.codebuff' "$ubuntu_root/root/.bashrc" 2>/dev/null; then
    printf '\n# codebuff\nexport PATH=/root/.codebuff:$PATH\n' >>"$ubuntu_root/root/.bashrc"
  fi

  return 0
}

install_codebuff() {
  if command -v codebuff &>/dev/null; then
    log_info "Codebuff is already installed"
    return 2
  fi

  log_info "Installing Codebuff..."

  if [[ -t 0 ]] && [[ -t 1 ]]; then
    log_info "Select installation method for Codebuff:"
    read_select "Installation method" SELECTED_METHOD \
      "Native (recommended) - Compile with glibc support" \
      "Proot-distro (alternative) - Ubuntu container"

    case "$SELECTED_METHOD" in
    *Native*)
      _install_codebuff_native
      ;;
    *Proot-distro*)
      _install_codebuff_proot
      ;;
    esac
  else
    _install_codebuff_native
  fi
}

uninstall_codebuff() {
  log_info "Uninstalling Codebuff..."
  mkdir -p "$(dirname "$LOG_FILE")"

  if [ ! -f "$PREFIX/bin/codebuff" ]; then
    log_warn "Codebuff is not installed"
    return 1
  fi

  if [ -f "$CODEBUFF_DATA_DIR/codebuff" ]; then
    rm -f "$PREFIX/bin/codebuff"
    rm -rf "$CODEBUFF_DATA_DIR"
    log_success "Codebuff (native) uninstalled"
    return 0
  fi

  _codebuff_proot_ubuntu /bin/bash -c 'rm -rf /root/.codebuff' &>>"$LOG_FILE"

  local ubuntu_bashrc
  ubuntu_bashrc="$(_codebuff_detect_ubuntu_root)/root/.bashrc"

  if [ -f "$ubuntu_bashrc" ]; then
    sed -i '/# codebuff/d; /export PATH=\/root\/.codebuff/d' "$ubuntu_bashrc"
  fi

  if rm -f "$PREFIX/bin/codebuff" &>>"$LOG_FILE"; then
    log_success "Codebuff (proot-distro) uninstalled"
    return 0
  else
    log_error "Failed to uninstall Codebuff"
    return 1
  fi
}

update_codebuff() {
  _check_update_needed "Codebuff" "$(_get_installed_version codebuff)" "$(_get_remote_github_version CodebuffAI/codebuff-community)" _update_codebuff_impl
}

_update_codebuff_impl() {
  if [ -f "$CODEBUFF_DATA_DIR/codebuff" ]; then
    _install_codebuff_native
    return $?
  fi

  _codebuff_proot_ubuntu /bin/bash -c 'rm -rf /root/.codebuff' &>>"$LOG_FILE"

  _codebuff_proot_ubuntu /bin/bash -c '
    export SHELL=/bin/bash
    export TMPDIR=/tmp
    export HOME=/root
    LATEST=$(curl -fsSL https://api.github.com/repos/CodebuffAI/codebuff-community/releases/latest | grep '"'"'tag_name'"'"' | sed -E '"'"'s/.*"tag_name":\s*"v([0-9]+\.[0-9]+\.[0-9]+)".*/\1/'"'"')
    TARBALL=$(mktemp /tmp/codebuff.XXXXXX.tar.gz)
    curl -fsSL "https://github.com/CodebuffAI/codebuff-community/releases/download/v${LATEST}/codebuff-linux-arm64.tar.gz" -o "$TARBALL"
    mkdir -p /root/.codebuff
    tar -zxf "$TARBALL" -C /root/.codebuff
    rm -f "$TARBALL"
    chmod +x /root/.codebuff/codebuff
  ' &>>"$LOG_FILE"

  local ubuntu_root
  ubuntu_root="$(_codebuff_detect_ubuntu_root)"
  local codebuff_bin="$ubuntu_root/root/.codebuff/codebuff"

  if [ ! -f "$codebuff_bin" ]; then
    log_error "Codebuff binary not found after update"
    return 1
  fi

  log_success "Codebuff (proot-distro) updated"
  return 0
}

reinstall_codebuff() {
  uninstall_codebuff
  install_codebuff
}
