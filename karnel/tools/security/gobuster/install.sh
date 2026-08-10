#!/usr/bin/env bash

_GOBUSTER_VERSION="3.6"
_GOBUSTER_DIR="$PREFIX/share/gobuster"
_GOBUSTER_MARKER="$PREFIX/share/karnel-installers/gobuster"

_install_gobuster_bin() (
  local arch tmpdir archive staged_bin
  arch="$(uname -m)"
  case "$arch" in
    aarch64) _GOBUSTER_ARCH="arm64" ;;
    armv7l|arm) _GOBUSTER_ARCH="arm" ;;
    x86_64) _GOBUSTER_ARCH="amd64" ;;
    *) log_error "Arquitetura não suportada: $arch"; return 1 ;;
  esac
  local url="https://github.com/OJ/gobuster/releases/download/v${_GOBUSTER_VERSION}/gobuster_Linux-${_GOBUSTER_ARCH}.tar.gz"
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gobuster.XXXXXX") || return 1
  staged_bin=""
  trap 'rm -rf "$tmpdir"; [ -z "$staged_bin" ] || rm -f "$staged_bin"' EXIT
  archive="$tmpdir/gobuster.tar.gz"
  curl -fsSL "$url" -o "$archive" || return 1
  tar -zxf "$archive" -C "$tmpdir" || return 1
  [ -f "$tmpdir/gobuster" ] || { log_error "Pacote gobuster inválido"; return 1; }
  mkdir -p "$PREFIX/bin" || return 1
  staged_bin=$(mktemp "$PREFIX/bin/.gobuster.XXXXXX") || return 1
  mv "$tmpdir/gobuster" "$staged_bin" && chmod +x "$staged_bin" && [ -x "$staged_bin" ] || return 1
  mv -f "$staged_bin" "$PREFIX/bin/gobuster" || return 1
  staged_bin=""
  mkdir -p "$(dirname "$_GOBUSTER_MARKER")" || return 1
  sha256sum "$PREFIX/bin/gobuster" > "$_GOBUSTER_MARKER"
  return 0
)

install_gobuster() {
  if command -v gobuster &>/dev/null; then
    log_info "gobuster já está instalado"
    return 2
  fi
  log_info "Instalando gobuster..."
  if pkg install -y gobuster 2>/dev/null || apt install -y gobuster 2>/dev/null; then
    log_success "gobuster instalado"
    return 0
  fi
  if _install_gobuster_bin; then
    log_success "gobuster instalado"
    return 0
  fi
  log_error "Falha ao instalar gobuster"
  return 1
}

uninstall_gobuster() {
  log_info "Removendo gobuster..."
  if [ -f "$_GOBUSTER_MARKER" ]; then
    [ "$(sha256sum "$PREFIX/bin/gobuster" 2>/dev/null)" = "$(<"$_GOBUSTER_MARKER")" ] && rm -f "$PREFIX/bin/gobuster"
    rm -f "$_GOBUSTER_MARKER"
  fi
  log_success "gobuster removido"
}

update_gobuster() {
  log_info "gobuster atualizado via download"
  uninstall_gobuster
  install_gobuster
}

reinstall_gobuster() {
  uninstall_gobuster
  install_gobuster
}
