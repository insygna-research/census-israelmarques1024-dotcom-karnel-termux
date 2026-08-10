#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

LOG_FILE="$KARNEL_CACHE/install_auto.log"

install_auto() {
	separator
	box "Installing Automation Tools"
	separator
	echo

	log_info "Installing Automation Tools..."
	echo
	mkdir -p "$(dirname "$LOG_FILE")"

	local rc=0
	_install_auto_wrapper || rc=$?
	if [ "$rc" -eq 0 ]; then
		log_success "Automation Tools installed successfully"
	else
		log_warn "$rc automation tool(s) failed to install"
	fi
	separator
	echo
	list_item "n8n"
	echo
	return "$rc"
}

_install_auto_wrapper() {
	import "@/tools/auto/all"
	install_all_auto_tools
	return $?
}

uninstall_auto() {
	separator
	box "Uninstalling Automation Tools"
	separator
	echo

	log_info "Uninstalling Automation Tools..."

	local rc=0
	_uninstall_auto_wrapper || rc=$?
	if [ "$rc" -eq 0 ]; then
		log_success "Automation Tools uninstalled"
	else
		log_warn "$rc automation tool(s) failed to uninstall"
	fi
	return "$rc"
}

_uninstall_auto_wrapper() {
	import "@/tools/auto/all"
	uninstall_all_auto_tools
	return $?
}

update_auto() {
	separator
	box "Updating Automation Tools"
	separator
	echo

	log_info "Updating Automation Tools..."

	local rc=0
	_update_auto_wrapper || rc=$?
	if [ "$rc" -eq 0 ]; then
		log_success "Automation Tools updated"
	else
		log_warn "$rc automation tool(s) failed to update"
	fi
	return "$rc"
}

_update_auto_wrapper() {
  import "@/tools/auto/all"
  update_all_auto_tools
  return $?
}

reinstall_auto() {
  separator
  box "Reinstalling Automation Tools"
  separator
  echo

  log_info "Reinstalling Automation Tools..."
  echo
  mkdir -p "$(dirname "$LOG_FILE")"

  local rc=0
  _reinstall_auto_wrapper || rc=$?
  if [ "$rc" -eq 0 ]; then
		log_success "Automation Tools reinstalled successfully"
  else
		log_warn "$rc automation tool(s) failed to reinstall"
  fi
  separator
  echo
	list_item "n8n"
	echo
	return "$rc"
}

_reinstall_auto_wrapper() {
  import "@/tools/auto/all"
  reinstall_all_auto_tools
  return $?
}
