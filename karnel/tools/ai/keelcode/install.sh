#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"

KEELCODE_PACKAGE="@keelcode-ai/keelcode"

install_keelcode() {
  if command -v keelcode &>/dev/null; then
    log_info "KeelCode is already installed"
    return 2
  fi

  log_info "Installing KeelCode..."
  local output rc
  output="$(npm install -g "$KEELCODE_PACKAGE" 2>&1)"
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
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v keelcode)" &>/dev/null || true
  log_success "KeelCode installed"
}

uninstall_keelcode() {
  if ! command -v keelcode &>/dev/null; then
    log_info "KeelCode is not installed"
    return 2
  fi

  log_info "Uninstalling KeelCode..."
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
  output="$(npm update -g "$KEELCODE_PACKAGE" 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to update KeelCode"
    return 1
  fi
  command -v keelcode &>/dev/null && command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v keelcode)" &>/dev/null || true
}

reinstall_keelcode() {
  uninstall_keelcode || [[ $? -eq 2 ]] || return 1
  install_keelcode
}
