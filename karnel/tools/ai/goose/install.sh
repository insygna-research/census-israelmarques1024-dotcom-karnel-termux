#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
GOOSE_DATA_DIR="$HOME/.local/share/karnel-data/goose"
GOOSE_BIN_PATH="$PREFIX/bin/goose"

_get_latest_goose_version() {
  local raw
  raw=$(_spin_capture "Checking GitHub" curl -fsSL "https://api.github.com/repos/aaif-goose/goose/releases/latest" 2>/dev/null)
  echo "$raw" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/' 2>/dev/null
}

_get_latest_goose_version_silent() {
  curl -fsSL "https://api.github.com/repos/aaif-goose/goose/releases/latest" 2>/dev/null | \
    grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/'
}

_goose_download_binary() {
  loading "Downloading Goose CLI" _goose_download_binary_impl
}

_goose_download_binary_impl() {
  if [ -x "$GOOSE_BIN_PATH" ] && [ "${1:-}" != "force" ]; then
    return 0
  fi

  local latest_version
  latest_version=$(_get_latest_goose_version_silent)
  if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest Goose version"
    return 1
  fi

  local arch
  arch=$(uname -m)
  local arch_suffix
  case "$arch" in
    aarch64|arm64) arch_suffix="aarch64-unknown-linux-musl" ;;
    x86_64) arch_suffix="x86_64-unknown-linux-musl" ;;
    *) arch_suffix="aarch64-unknown-linux-musl" ;;
  esac

  local tarball="goose-${arch_suffix}.tar.gz"
  local download_url="https://github.com/aaif-goose/goose/releases/download/v${latest_version}/${tarball}"

  local staging_dir old_data old_bin goose_bin
  mkdir -p "$(dirname "$GOOSE_DATA_DIR")" "$(dirname "$GOOSE_BIN_PATH")"
  staging_dir=$(mktemp -d "$(dirname "$GOOSE_DATA_DIR")/.goose.XXXXXX") || return 1

  if ! curl -fsSL "$download_url" -o "$staging_dir/$tarball" &>>"$LOG_FILE"; then
    rm -rf "$staging_dir"
    log_error "Failed to download Goose CLI"
    return 1
  fi

  if ! tar -xzf "$staging_dir/$tarball" -C "$staging_dir" &>>"$LOG_FILE"; then
    log_error "Failed to extract Goose CLI"
    rm -rf "$staging_dir"
    return 1
  fi

  rm -f "$staging_dir/$tarball"

  goose_bin=$(find "$staging_dir" -name "goose" -type f 2>/dev/null | head -1)
  if [ -z "$goose_bin" ]; then
    rm -rf "$staging_dir"
    log_error "Goose binary not found after extraction"
    return 1
  fi

  cp "$goose_bin" "$staging_dir/.goose-bin" || { rm -rf "$staging_dir"; return 1; }
  chmod +x "$staging_dir/.goose-bin"

  if [ ! -x "$staging_dir/.goose-bin" ]; then
    rm -rf "$staging_dir"
    log_error "Goose CLI is not executable"
    return 1
  fi

  old_data="${GOOSE_DATA_DIR}.previous.$$"
  old_bin="${GOOSE_BIN_PATH}.previous.$$"
  if { [ -d "$GOOSE_DATA_DIR" ] && ! mv "$GOOSE_DATA_DIR" "$old_data"; } ||
    { [ -e "$GOOSE_BIN_PATH" ] && ! mv "$GOOSE_BIN_PATH" "$old_bin"; } ||
    ! mv "$staging_dir" "$GOOSE_DATA_DIR" ||
    ! mv "$GOOSE_DATA_DIR/.goose-bin" "$GOOSE_BIN_PATH"; then
    rm -rf "$staging_dir" "$GOOSE_DATA_DIR"
    [[ -e "$old_bin" ]] && mv "$old_bin" "$GOOSE_BIN_PATH"
    [[ -d "$old_data" ]] && mv "$old_data" "$GOOSE_DATA_DIR"
    log_error "Failed to replace Goose CLI"
    return 1
  fi
  rm -rf "$old_data" "$old_bin"

  return 0
}

install_goose() {
  if command -v goose &>/dev/null; then
    log_info "Goose CLI is already installed"
    return 2
  fi

  _goose_download_binary || return 1

  if command -v goose &>/dev/null; then
    log_success "Goose CLI installed (native Termux)"
    log_info "Run: ${D_CYAN}goose session${NC}"
    log_info "First-time setup: ${D_CYAN}goose configure${NC}"
    return 0
  fi

  log_error "Goose CLI installation failed"
  return 1
}

uninstall_goose() {
  if [ ! -f "$PREFIX/bin/goose" ]; then
    log_info "Goose CLI is not installed"
    return 2
  fi

  rm -f "$PREFIX/bin/goose"
  rm -rf "$GOOSE_DATA_DIR"

  log_success "Goose CLI uninstalled"
  return 0
}

update_goose() {
  _check_update_needed "Goose CLI" \
    "$(_get_installed_version goose 2>/dev/null || echo 0)" \
    "$(_parse_version "$(_get_latest_goose_version_silent)")" \
    _update_goose_impl
}

_update_goose_impl() {
  _goose_download_binary_impl force
}

reinstall_goose() {
  uninstall_goose
  install_goose
}
