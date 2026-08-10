#!/usr/bin/env bash

_AMASS_MARKER="$PREFIX/share/karnel-installers/amass"

_amass_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    aarch64) echo "arm64" ;;
    armv7l|arm) echo "armv7" ;;
    x86_64) echo "amd64" ;;
    *) echo ""; return 1 ;;
  esac
}

install_amass() (
  if command -v amass &>/dev/null; then
    log_info "amass já está instalado"
    return 2
  fi
  log_info "Instalando amass..."
  if pkg install -y amass 2>/dev/null || apt install -y amass 2>/dev/null; then
    log_success "amass instalado"
    return 0
  fi

  local arch version url tmpdir archive amass_bin staged_bin
  arch=$(_amass_arch) || { log_error "Arquitetura não suportada"; return 1; }
  version=$(curl -fsSL "https://api.github.com/repos/owasp-amass/amass/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  [ -z "$version" ] && version="v4.2.0"
  url="https://github.com/owasp-amass/amass/releases/download/${version}/amass_linux_${arch}.zip"

  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/amass.XXXXXX") || return 1
  staged_bin=""
  trap 'rm -rf "$tmpdir"; [ -z "$staged_bin" ] || rm -f "$staged_bin"' EXIT
  archive="$tmpdir/amass.zip"
  curl -fsSL "$url" -o "$archive" 2>/dev/null || return 1
  unzip -o "$archive" -d "$tmpdir" >/dev/null 2>&1 || return 1
  amass_bin=$(find "$tmpdir" -name amass -type f -print -quit 2>/dev/null)
  [ -n "$amass_bin" ] || { log_error "Pacote amass inválido"; return 1; }
  mkdir -p "$PREFIX/bin" || return 1
  staged_bin=$(mktemp "$PREFIX/bin/.amass.XXXXXX") || return 1
  mv "$amass_bin" "$staged_bin" && chmod +x "$staged_bin" && [ -x "$staged_bin" ] || return 1
  mv -f "$staged_bin" "$PREFIX/bin/amass" || return 1
  staged_bin=""
  mkdir -p "$(dirname "$_AMASS_MARKER")" || return 1
  sha256sum "$PREFIX/bin/amass" > "$_AMASS_MARKER"
  log_success "amass instalado"
  return 0
)

uninstall_amass() {
  log_info "Removendo amass..."
  if [ -f "$_AMASS_MARKER" ]; then
    [ "$(sha256sum "$PREFIX/bin/amass" 2>/dev/null)" = "$(<"$_AMASS_MARKER")" ] && rm -f "$PREFIX/bin/amass"
    rm -f "$_AMASS_MARKER"
  fi
  log_success "amass removido"
}

update_amass() {
  uninstall_amass
  install_amass
}

reinstall_amass() {
  uninstall_amass
  install_amass
}
