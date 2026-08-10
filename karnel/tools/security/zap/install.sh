#!/usr/bin/env bash

_ZAP_DIR="$PREFIX/share/zap"
_ZAP_VERSION="2.16.1"

install_zap() (
  if command -v zap &>/dev/null; then
    log_info "zap já está instalado"
    return 2
  fi
  log_info "Instalando ZAP (Zed Attack Proxy)..."

  if pkg install -y zaproxy 2>/dev/null || apt install -y zaproxy 2>/dev/null; then
    log_success "zap instalado"
    return 0
  fi

  pkg install -y curl openjdk-17 2>/dev/null

  local arch tmpdir archive zap_home wrapper
  arch="$(uname -m)"
  case "$arch" in
    aarch64|armv7l|arm) ZAP_ASSET="ZAP_${_ZAP_VERSION}-Linux.tar.gz" ;;
    x86_64) ZAP_ASSET="ZAP_${_ZAP_VERSION}-Linux-x64.tar.gz" ;;
    *) log_error "Arquitetura não suportada: $arch"; return 1 ;;
  esac

  local url="https://github.com/zaproxy/zaproxy/releases/download/v${_ZAP_VERSION}/$ZAP_ASSET"

  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/zap.XXXXXX") || {
    log_error "Falha ao criar diretório temporário"
    return 1
  }
  wrapper=""
  trap 'rm -rf "$tmpdir"; [ -z "$wrapper" ] || rm -f "$wrapper"' EXIT
  archive="$tmpdir/zap.tar.gz"

  curl -fsSL "$url" -o "$archive" 2>/dev/null || {
    log_error "Falha ao baixar ZAP"
    return 1
  }

  tar -zxf "$archive" -C "$tmpdir" 2>/dev/null || {
    log_error "Falha ao extrair ZAP"
    return 1
  }
  zap_home=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d -name 'ZAP*' -print -quit)
  if [ -z "$zap_home" ] || [ ! -x "$zap_home/zap.sh" ]; then
    log_error "Pacote ZAP inválido"
    return 1
  fi

  mkdir -p "$_ZAP_DIR" "$PREFIX/bin" || return 1
  if [ -e "$_ZAP_DIR/$(basename "$zap_home")" ]; then
    log_error "Instalação ZAP existente inválida"
    return 1
  fi
  wrapper=$(mktemp "$PREFIX/bin/.zap.XXXXXX") || return 1
  cat > "$wrapper" << 'SCRIPT'
#!/usr/bin/env bash
ZAP_HOME=$(find "$PREFIX/share/zap" -maxdepth 1 -type d -name "ZAP*" | head -1)
exec "$ZAP_HOME/zap.sh" "$@"
SCRIPT
  chmod +x "$wrapper" || return 1
  mv "$zap_home" "$_ZAP_DIR/" && mv -f "$wrapper" "$PREFIX/bin/zap" || {
    log_error "Falha ao instalar ZAP"
    return 1
  }
  wrapper=""
  sha256sum "$PREFIX/bin/zap" > "$_ZAP_DIR/.karnel-wrapper"
  log_success "zap instalado"
  return 0
)

uninstall_zap() {
  log_info "Removendo ZAP..."
  if [ -f "$_ZAP_DIR/.karnel-wrapper" ]; then
    [ "$(sha256sum "$PREFIX/bin/zap" 2>/dev/null)" = "$(<"$_ZAP_DIR/.karnel-wrapper")" ] && rm -f "$PREFIX/bin/zap"
    rm -rf "$_ZAP_DIR"
  fi
  log_success "zap removido"
}

update_zap() {
  uninstall_zap
  install_zap
}

reinstall_zap() {
  uninstall_zap
  install_zap
}
