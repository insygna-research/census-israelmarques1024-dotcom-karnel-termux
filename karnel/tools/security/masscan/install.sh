#!/usr/bin/env bash

_MASSCAN_DIR="${KARNEL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}/tools/masscan"

install_masscan() {
  if command -v masscan &>/dev/null; then
    log_info "masscan já está instalado"
    return 2
  fi
  log_info "Instalando masscan..."
  if pkg install -y masscan 2>/dev/null || apt install -y masscan 2>/dev/null; then
    log_success "masscan instalado"
    return 0
  fi

  pkg install -y git make clang 2>/dev/null

  if [ -e "$_MASSCAN_DIR" ]; then
    log_error "Karnel source directory already exists: $_MASSCAN_DIR"
    return 1
  fi

  mkdir -p "$(dirname "$_MASSCAN_DIR")" || return 1
  git clone --depth 1 https://github.com/robertdavidgraham/masscan "$_MASSCAN_DIR" 2>/dev/null || return 1
  make -C "$_MASSCAN_DIR" -j4 2>/dev/null || return 1
  install -m 755 "$_MASSCAN_DIR/bin/masscan" "$PREFIX/bin/masscan"
  chmod +x "$PREFIX/bin/masscan"
  sha256sum "$PREFIX/bin/masscan" > "$_MASSCAN_DIR/.karnel-wrapper"
  log_success "masscan instalado"
  return 0
}

uninstall_masscan() {
  log_info "Removendo masscan..."
  if [ -f "$_MASSCAN_DIR/.karnel-wrapper" ]; then
    [ "$(sha256sum "$PREFIX/bin/masscan" 2>/dev/null)" = "$(<"$_MASSCAN_DIR/.karnel-wrapper")" ] && rm -f "$PREFIX/bin/masscan"
    rm -rf "$_MASSCAN_DIR"
  fi
  log_success "masscan removido"
}

update_masscan() {
  if [ -d "$_MASSCAN_DIR" ]; then
    git -C "$_MASSCAN_DIR" pull
    make -C "$_MASSCAN_DIR" -j4 2>/dev/null
  install -m 755 "$_MASSCAN_DIR/bin/masscan" "$PREFIX/bin/masscan"
    sha256sum "$PREFIX/bin/masscan" > "$_MASSCAN_DIR/.karnel-wrapper"
    log_success "masscan atualizado"
    return 0
  fi
  install_masscan
}

reinstall_masscan() {
  uninstall_masscan
  install_masscan
}
