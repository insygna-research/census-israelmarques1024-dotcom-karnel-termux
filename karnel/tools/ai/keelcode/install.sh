#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"

KEELCODE_PACKAGE="@keelcode-ai/keelcode"
: "${KARNEL_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}"
KEELCODE_DATA_DIR="$KARNEL_DATA/keelcode"
KEELCODE_WRAPPER_MARKER="Karnel KeelCode Termux wrapper"

_keelcode_install_termux_wrapper() {
  local version staging archive native_dir wrapper
  version="$(npm view "$KEELCODE_PACKAGE" version 2>/dev/null)" || return 1
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1

  command -v grun &>/dev/null || pkg install glibc-runner -y || return 1
  mkdir -p "$KARNEL_DATA" "$PREFIX/bin"
  staging="$(mktemp -d "$KARNEL_DATA/.keelcode.XXXXXX")" || return 1
  archive="$staging/keelcode.tgz"

  if ! curl --fail --silent --show-error --location \
    "https://registry.npmjs.org/@keelcode-ai/keelcode/-/keelcode-${version}-linux-arm64.tgz" \
    -o "$archive" || ! tar -xzf "$archive" -C "$staging" ||
    [[ ! -x "$staging/package/bin/keelcode" || ! -x "$staging/package/bin/rg" ]]; then
    rm -rf "$staging"
    log_error "Failed to download the official KeelCode linux-arm64 binary"
    return 1
  fi

  native_dir="$KEELCODE_DATA_DIR/native"
  rm -rf "$native_dir"
  mkdir -p "$KEELCODE_DATA_DIR"
  mv "$staging/package" "$native_dir" || { rm -rf "$staging"; return 1; }
  rm -rf "$staging"

  wrapper="$PREFIX/bin/keelcode"
  rm -f "$wrapper"
  cat >"$wrapper" <<EOF
#!$PREFIX/bin/bash
# $KEELCODE_WRAPPER_MARKER
export KEELCODE_RG_PATH="$native_dir/bin/rg"
exec grun "$native_dir/bin/keelcode" "\$@"
EOF
  chmod 755 "$wrapper"
  "$wrapper" --version >/dev/null || return 1
}

install_keelcode() {
  if command -v keelcode &>/dev/null && keelcode --version >/dev/null 2>&1; then
    log_info "KeelCode is already installed"
    return 2
  fi

  log_info "Installing KeelCode..."
  local output rc
  output="$(npm install -g "$KEELCODE_PACKAGE" --force 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to install KeelCode"
    return 1
  fi
  if ! command -v keelcode &>/dev/null; then
    log_error "KeelCode binary was not found after npm installation"
    return 1
  fi

  _keelcode_install_termux_wrapper || return 1
  log_success "KeelCode installed"
}

uninstall_keelcode() {
  if ! command -v keelcode &>/dev/null; then
    log_info "KeelCode is not installed"
    return 2
  fi

  log_info "Uninstalling KeelCode..."
  if grep -qF "$KEELCODE_WRAPPER_MARKER" "$PREFIX/bin/keelcode" 2>/dev/null; then
    rm -f "$PREFIX/bin/keelcode"
  fi
  rm -rf "$KEELCODE_DATA_DIR"
  local output rc
  output="$(npm uninstall -g "$KEELCODE_PACKAGE" 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to uninstall KeelCode"
    return 1
  fi
  log_success "KeelCode uninstalled"
}

update_keelcode() {
  _check_update_needed "KeelCode" \
    "$(_get_installed_npm_version "$KEELCODE_PACKAGE")" \
    "$(_get_remote_npm_version "$KEELCODE_PACKAGE")" \
    _do_update_keelcode
}

_do_update_keelcode() {
  local output rc
  output="$(npm update -g "$KEELCODE_PACKAGE" --force 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to update KeelCode"
    return 1
  fi
  _keelcode_install_termux_wrapper || return 1
}

reinstall_keelcode() {
  uninstall_keelcode || [[ $? -eq 2 ]] || return 1
  install_keelcode
}
