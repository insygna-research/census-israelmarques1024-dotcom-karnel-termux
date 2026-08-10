#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

LOG_FILE="$KARNEL_CACHE/install_network.log"

install_network() {
  separator
  box "Installing Network Tools"
  separator
  echo

  log_info "Installing network tools..."

  mkdir -p "$(dirname "$LOG_FILE")"

  local rc=0
  import "@/tools/network/all"
  install_all_network || rc=$?
  if [ "$rc" -eq 0 ]; then
    log_success "Network tools installed"
  else
    log_warn "$rc network tool(s) failed to install"
  fi
  separator
  echo
  return "$rc"
}

uninstall_network() {
  separator
  box "Uninstalling Network Tools"
  separator
  echo

  log_info "Uninstalling network tools..."

  local rc=0
  import "@/tools/network/all"
  uninstall_all_network || rc=$?
  if [ "$rc" -eq 0 ]; then
    log_success "Network tools uninstalled"
  else
    log_warn "$rc network tool(s) failed to uninstall"
  fi
  return "$rc"
}

update_network() {
  separator
  box "Updating Network Tools"
  separator
  echo

  log_info "Updating network tools..."

  local rc=0
  import "@/tools/network/all"
  update_all_network || rc=$?
  if [ "$rc" -eq 0 ]; then
    log_success "Network tools updated"
  else
    log_warn "$rc network tool(s) failed to update"
  fi
  return "$rc"
}

reinstall_network() {
  separator
  box "Reinstalling Network Tools"
  separator
  echo

  log_info "Reinstalling network tools..."

  local rc=0
  import "@/tools/network/all"
  reinstall_all_network || rc=$?
  if [ "$rc" -eq 0 ]; then
    log_success "Network tools reinstalled"
  else
    log_warn "$rc network tool(s) failed to reinstall"
  fi
  separator
  echo
  return "$rc"
}
