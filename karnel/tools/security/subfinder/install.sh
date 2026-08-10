#!/usr/bin/env bash

_SUBFINDER_MARKER="$PREFIX/share/karnel-installers/subfinder"

_subfinder_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    aarch64) echo "arm64" ;;
    armv7l|arm) echo "armv7" ;;
    x86_64) echo "amd64" ;;
    *) echo ""; return 1 ;;
  esac
}

install_subfinder() (
  if command -v subfinder &>/dev/null; then
    log_info "subfinder já está instalado"
    return 2
  fi
  log_info "Instalando subfinder..."
  if pkg install -y subfinder 2>/dev/null || apt install -y subfinder 2>/dev/null; then
    log_success "subfinder instalado"
    return 0
  fi

  local arch version url tmpdir archive staged_bin
  arch=$(_subfinder_arch) || { log_error "Arquitetura não suportada"; return 1; }
  version=$(curl -fsSL "https://api.github.com/repos/projectdiscovery/subfinder/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  [ -z "$version" ] && version="v2.6.6"
  url="https://github.com/projectdiscovery/subfinder/releases/download/${version}/subfinder_${version#v}_linux_${arch}.zip"

  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/subfinder.XXXXXX") || return 1
  staged_bin=""
  trap 'rm -rf "$tmpdir"; [ -z "$staged_bin" ] || rm -f "$staged_bin"' EXIT
  archive="$tmpdir/subfinder.zip"
  curl -fsSL "$url" -o "$archive" 2>/dev/null || return 1
  unzip -o "$archive" -d "$tmpdir" >/dev/null 2>&1 || return 1
  [ -f "$tmpdir/subfinder" ] || { log_error "Pacote subfinder inválido"; return 1; }
  mkdir -p "$PREFIX/bin" || return 1
  staged_bin=$(mktemp "$PREFIX/bin/.subfinder.XXXXXX") || return 1
  mv "$tmpdir/subfinder" "$staged_bin" && chmod +x "$staged_bin" && [ -x "$staged_bin" ] || return 1
  mv -f "$staged_bin" "$PREFIX/bin/subfinder" || return 1
  staged_bin=""
  mkdir -p "$(dirname "$_SUBFINDER_MARKER")" || return 1
  sha256sum "$PREFIX/bin/subfinder" > "$_SUBFINDER_MARKER"
  log_success "subfinder instalado"
  return 0
)

uninstall_subfinder() {
  log_info "Removendo subfinder..."
  if [ -f "$_SUBFINDER_MARKER" ]; then
    [ "$(sha256sum "$PREFIX/bin/subfinder" 2>/dev/null)" = "$(<"$_SUBFINDER_MARKER")" ] && rm -f "$PREFIX/bin/subfinder"
    rm -f "$_SUBFINDER_MARKER"
  fi
  log_success "subfinder removido"
}

update_subfinder() {
  uninstall_subfinder
  install_subfinder
}

reinstall_subfinder() {
  uninstall_subfinder
  install_subfinder
}
