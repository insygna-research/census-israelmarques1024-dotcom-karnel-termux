#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_ai.log"
DROID_DATA_DIR="$HOME/.local/share/karnel-data/droid"

_droid_detect_ubuntu_root() {
  local root
  root="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs"
  [ -d "$root" ] || root=""
  echo "$root"
}

_droid_ensure_proot() {
  if ! command -v proot-distro &>/dev/null; then
    loading "Installing proot-distro" pkg install proot-distro -y
    if ! command -v proot-distro &>/dev/null; then
      log_error "Failed to install proot-distro"
      return 1
    fi
  fi
    if [ ! -d "/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs" ]; then
    loading "Installing Ubuntu 24.04 container" proot-distro install ubuntu:24.04
  if [ ! -d "/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs" ]; then
      log_error "Failed to install Ubuntu container"
      return 1
    fi
  fi
  return 0
}

_droid_install_inside_ubuntu() {
  loading "Installing Droid CLI in Ubuntu container" _droid_install_inside_ubuntu_impl
}

_droid_install_inside_ubuntu_impl() {
  if ! proot-distro login --shared-tmp ubuntu -- bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq ca-certificates nodejs npm

    npm install -g @factory/cli@0.190.0
    command -v droid
  ' >>"$LOG_FILE" 2>&1; then
    log_error "Failed to install Droid CLI in Ubuntu container"
    return 1
  fi
}

_droid_create_termux_wrapper() {
  loading "Creating Termux wrapper" _droid_create_termux_wrapper_impl
}

_droid_create_termux_wrapper_impl() {
  local ubuntu_root
  ubuntu_root="$(_droid_detect_ubuntu_root)"
  if [ -z "$ubuntu_root" ]; then
    log_error "Ubuntu rootfs not found"
    return 1
  fi

  local droid_bin_in_ubuntu=""
  for candidate in "/usr/local/bin/droid" "/usr/bin/droid" "/usr/lib/node_modules/@factory/cli/bin/droid" "/root/.local/bin/droid"; do
    if [ -f "$ubuntu_root/$candidate" ]; then
      droid_bin_in_ubuntu="$candidate"
      break
    fi
  done

  # Se nao achou o binario direto, procura no node_modules
  if [ -z "$droid_bin_in_ubuntu" ]; then
    local found
    found=$(find "$ubuntu_root/usr/lib/node_modules/@factory/cli" -maxdepth 2 -name "*.js" -path "*/bin/*" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
      local rel_path="${found#$ubuntu_root}"
      droid_bin_in_ubuntu="$rel_path"
    fi
  fi


  if [ -z "$droid_bin_in_ubuntu" ]; then
    log_error "Could not find Droid CLI binary in Ubuntu container"
    return 1
  fi

  local wrapper_path="$PREFIX/bin/droid"
  cat > "$wrapper_path" << PROOT_WRAPPER
#!/data/data/com.termux/files/usr/bin/bash
# Droid CLI wrapper — gerado pelo Karnel
# Executa Droid dentro do container proot-distro Ubuntu

exec proot-distro login --shared-tmp ubuntu -- ${droid_bin_in_ubuntu} "\$@"
PROOT_WRAPPER
  chmod +x "$wrapper_path"

  if [ ! -f "$wrapper_path" ]; then
    log_error "Failed to create Droid wrapper"
    return 1
  fi

  return 0
}

install_droid() {
  if command -v droid &>/dev/null; then
    log_info "Droid CLI is already installed"
    return 2
  fi

  _droid_ensure_proot || return 1
  _droid_install_inside_ubuntu || true
  _droid_create_termux_wrapper || return 1

  if command -v droid &>/dev/null; then
    log_success "Droid CLI installed (proot-distro Ubuntu)"
    log_info "Run: ${D_CYAN}droid login${NC} to authenticate"
    log_info "Then: ${D_CYAN}droid${NC} to start"
    return 0
  fi

  log_error "Droid CLI installation failed"
  return 1
}

uninstall_droid() {
  if [ ! -f "$PREFIX/bin/droid" ]; then
    log_info "Droid CLI is not installed"
    return 2
  fi

  rm -f "$PREFIX/bin/droid"

  local ubuntu_root
  ubuntu_root="$(_droid_detect_ubuntu_root)"
  if [ -n "$ubuntu_root" ]; then
    rm -f "$ubuntu_root/usr/local/bin/droid"
    rm -f "$ubuntu_root/root/.local/bin/droid"
    rm -rf "$ubuntu_root/usr/lib/node_modules/@factory/cli" 2>/dev/null || true
  fi

  log_success "Droid CLI uninstalled"
  return 0
}

update_droid() {
  _check_update_needed "Droid CLI" \
    "$(_get_installed_npm_version @factory/cli 2>/dev/null || echo 0)" \
    "$(_get_remote_npm_version @factory/cli 2>/dev/null)" \
    _update_droid_impl
}

_update_droid_impl() {
  uninstall_droid
  install_droid
}

reinstall_droid() {
  uninstall_droid
  install_droid
}
