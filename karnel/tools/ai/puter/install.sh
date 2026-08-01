#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/version"

PUTER_PACKAGE="@heyputer/cli"

install_puter() {
  if command -v puter &>/dev/null; then
    log_info "Puter CLI is already installed"
    return 2
  fi

  log_info "Installing Puter CLI..."
  local output rc
  output="$(npm install -g "$PUTER_PACKAGE" 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to install Puter CLI"
    return 1
  fi
  if ! command -v puter &>/dev/null; then
    log_error "Puter CLI binary was not found after npm installation"
    return 1
  fi
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v puter)" &>/dev/null || true
  log_success "Puter CLI installed"
}

uninstall_puter() {
  if ! command -v puter &>/dev/null; then
    log_info "Puter CLI is not installed"
    return 2
  fi

  log_info "Uninstalling Puter CLI..."
  local output rc
  output="$(npm uninstall -g "$PUTER_PACKAGE" 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to uninstall Puter CLI"
    return 1
  fi
  log_success "Puter CLI uninstalled"
}

update_puter() {
  _check_update_needed "Puter CLI" \
    "$(_get_installed_npm_version "$PUTER_PACKAGE")" \
    "$(_get_remote_npm_version "$PUTER_PACKAGE")" \
    _do_update_puter
}

_do_update_puter() {
  local output rc
  output="$(npm update -g "$PUTER_PACKAGE" 2>&1)"
  rc=$?
  printf '%s\n' "$output" | tail -3
  if ((rc != 0)); then
    log_error "Failed to update Puter CLI"
    return 1
  fi
  command -v termux-fix-shebang &>/dev/null && termux-fix-shebang "$(command -v puter)" &>/dev/null || true
}

reinstall_puter() {
  uninstall_puter || [[ $? -eq 2 ]] || return 1
  install_puter
}
