#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
CURSOR_DATA_DIR="$HOME/.local/share/karnel-data/cursor"

_cursor_detect_ubuntu_root() {
  local root
  root="$(find /data/data/com.termux -maxdepth 10 -type d \
    -name "rootfs" -path "*/containers/ubuntu/*" 2>/dev/null | head -1)"
  if [ -z "$root" ]; then
    root="$(find /data/data/com.termux -maxdepth 10 -type d \
      -name "ubuntu" -path "*/installed-rootfs/*" 2>/dev/null | head -1)"
  fi
  echo "$root"
}

_cursor_proot_ubuntu() {
  proot-distro login --shared-tmp ubuntu -- "$@"
}

_get_latest_cursor_version_raw() {
  curl -fsS "https://cursor.com/install" 2>/dev/null | grep -oP 'downloads\.cursor\.com/lab/\K[^/]+'
}

_get_latest_cursor_version() {
  local raw
  raw=$(_spin_capture "Checking cursor.com" _get_latest_cursor_version_raw)
  [ -n "$raw" ] && echo "$raw" || echo ""
}

_get_latest_cursor_version_silent() {
  _get_latest_cursor_version_raw
}

_cursor_install_deps_native() {
  loading "Installing glibc and dependencies" _cursor_install_deps_native_impl
}

_cursor_install_deps_native_impl() {
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
  for pkg in curl tar; do
    if ! command -v "$pkg" &>/dev/null; then
      if ! pkg install "$pkg" -y &>>"$LOG_FILE"; then
        log_error "Failed to install $pkg"
        return 1
      fi
    fi
  done
  return 0
}

_download_cursor_binary() {
  loading "Downloading Cursor CLI" _download_cursor_binary_impl
}

_download_cursor_binary_impl() {
  local v
  v=$(_get_latest_cursor_version_silent)
  if [ -z "$v" ]; then
    log_error "Failed to fetch latest Cursor CLI version"
    return 1
  fi
  mkdir -p "$CURSOR_DATA_DIR"
  local url="https://downloads.cursor.com/lab/$v/linux/arm64/agent-cli-package.tar.gz"
  if ! curl -fsSL "$url" -o "$CURSOR_DATA_DIR/agent.tar.gz" &>>"$LOG_FILE"; then
    log_error "Failed to download Cursor CLI"
    return 1
  fi
  if ! tar -zxf "$CURSOR_DATA_DIR/agent.tar.gz" --strip-components=1 -C "$CURSOR_DATA_DIR" &>>"$LOG_FILE"; then
    log_error "Failed to extract Cursor CLI"
    return 1
  fi
  rm -f "$CURSOR_DATA_DIR/agent.tar.gz"
  if [ ! -f "$CURSOR_DATA_DIR/cursor-agent" ]; then
    log_error "cursor-agent not found after extraction"
    return 1
  fi
  chmod +x "$CURSOR_DATA_DIR/cursor-agent" "$CURSOR_DATA_DIR/node" 2>/dev/null
  return 0
}

_create_cursor_wrapper() {
  cat >"$PREFIX/bin/cursor" <<'WRAPPER'
#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
unset LD_PRELOAD LD_LIBRARY_PATH

export GODEBUG=netdns=cgo
export SSL_CERT_FILE="/data/data/com.termux/files/usr/etc/tls/cert.pem"
export CURSOR_INVOKED_AS="${0##*/}"

CURSOR_DATA_DIR="$HOME/.local/share/karnel-data/cursor"

# compile cache = startup mais rapido (Node >= 22.1.0)
export NODE_COMPILE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cursor-compile-cache"

# OAuth callback precisa de HOST local
export HOST="${HOST:-127.0.0.1}"

# BROWSER: termux-open-url ou fallback
if [ -z "${BROWSER:-}" ] && command -v termux-open-url &>/dev/null; then
  BROWSER="termux-open-url"
fi
export BROWSER

# gambiarra: rodar node do bundle via ld-linux glibc
exec /data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1 \
  --library-path /data/data/com.termux/files/usr/glibc/lib \
  "$CURSOR_DATA_DIR/node" \
  "$CURSOR_DATA_DIR/index.js" \
  "$@"
WRAPPER
  chmod +x "$PREFIX/bin/cursor"
  ln -sf "$PREFIX/bin/cursor" "$PREFIX/bin/cursor-agent" 2>/dev/null || true
}

install_cursor_cli() {
  if command -v cursor &>/dev/null || command -v cursor-agent &>/dev/null; then
    log_info "Cursor CLI is already installed"
    return 2
  fi

  _cursor_install_deps_native || return 1
  _download_cursor_binary || return 1
  _create_cursor_wrapper

  log_success "Cursor CLI installed"
  log_info "Run: cursor"
  return 0
}

uninstall_cursor_cli() {
  if [ ! -f "$PREFIX/bin/cursor" ] && [ ! -f "$PREFIX/bin/cursor-agent" ]; then
    log_info "Cursor CLI is not installed"
    return 2
  fi
  rm -f "$PREFIX/bin/cursor" "$PREFIX/bin/cursor-agent"
  rm -rf "$CURSOR_DATA_DIR"
  log_success "Cursor CLI uninstalled"
}

update_cursor_cli() {
  _check_update_needed "Cursor CLI" \
    "$(_get_installed_version cursor-agent 2>/dev/null || echo 0)" \
    "$(_parse_version "$(_get_latest_cursor_version_silent)")" \
    _update_cursor_cli_impl
}

_update_cursor_cli_impl() {
  rm -f "$PREFIX/bin/cursor" "$PREFIX/bin/cursor-agent"
  rm -rf "$CURSOR_DATA_DIR"
  install_cursor_cli
}

reinstall_cursor_cli() {
  uninstall_cursor_cli
  install_cursor_cli
}
