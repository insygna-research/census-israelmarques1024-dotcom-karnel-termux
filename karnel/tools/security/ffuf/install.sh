#!/usr/bin/env bash

_FFUF_MARKER="$PREFIX/share/karnel-installers/ffuf"

inc_ffuf_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    aarch64) echo "arm64" ;;
    armv7l|arm) echo "arm" ;;
    x86_64) echo "amd64" ;;
    *) echo ""; return 1 ;;
  esac
}

_download_ffuf() (
  local version arch url tmpdir archive staged_bin
  version=$(curl -fsSL "https://api.github.com/repos/ffuf/ffuf/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  [ -z "$version" ] && version="v2.1.0"
  arch=$(inc_ffuf_arch) || return 1
  url="https://github.com/ffuf/ffuf/releases/download/${version}/ffuf_${version}_linux_${arch}.tar.gz"
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/ffuf.XXXXXX") || return 1
  staged_bin=""
  trap 'rm -rf "$tmpdir"; [ -z "$staged_bin" ] || rm -f "$staged_bin"' EXIT
  archive="$tmpdir/ffuf.tar.gz"
  curl -fsSL "$url" -o "$archive" || return 1
  tar -zxf "$archive" -C "$tmpdir" ffuf 2>/dev/null || tar -zxf "$archive" -C "$tmpdir" 2>/dev/null || return 1
  [ -f "$tmpdir/ffuf" ] || { log_error "Pacote ffuf inválido"; return 1; }
  mkdir -p "$PREFIX/bin" || return 1
  staged_bin=$(mktemp "$PREFIX/bin/.ffuf.XXXXXX") || return 1
  mv "$tmpdir/ffuf" "$staged_bin" && chmod +x "$staged_bin" && [ -x "$staged_bin" ] || return 1
  mv -f "$staged_bin" "$PREFIX/bin/ffuf" || return 1
  staged_bin=""
  mkdir -p "$(dirname "$_FFUF_MARKER")" || return 1
  sha256sum "$PREFIX/bin/ffuf" > "$_FFUF_MARKER"
  return 0
)

install_ffuf() {
  if command -v ffuf &>/dev/null; then
    log_info "ffuf já está instalado"
    return 2
  fi
  log_info "Instalando ffuf..."
  if pkg install -y ffuf 2>/dev/null || apt install -y ffuf 2>/dev/null; then
    log_success "ffuf instalado"
    return 0
  fi
  if _download_ffuf; then
    log_success "ffuf instalado"
    return 0
  fi
  log_error "Falha ao instalar ffuf"
  return 1
}

uninstall_ffuf() {
  log_info "Removendo ffuf..."
  if [ -f "$_FFUF_MARKER" ]; then
    [ "$(sha256sum "$PREFIX/bin/ffuf" 2>/dev/null)" = "$(<"$_FFUF_MARKER")" ] && rm -f "$PREFIX/bin/ffuf"
    rm -f "$_FFUF_MARKER"
  fi
  log_success "ffuf removido"
}

update_ffuf() {
  uninstall_ffuf
  install_ffuf
}

reinstall_ffuf() {
  uninstall_ffuf
  install_ffuf
}
