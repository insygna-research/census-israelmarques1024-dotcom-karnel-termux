#!/usr/bin/env bash

METASPLOIT_DIR="${KARNEL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data}/tools/metasploit-framework"

install_metasploit() {
  if command -v msfconsole &>/dev/null; then
    log_info "metasploit já está instalado"
    return 2
  fi
  log_info "Instalando Metasploit Framework..."

  if pkg install -y metasploit 2>/dev/null || apt install -y metasploit 2>/dev/null; then
    log_success "metasploit instalado"
    return 0
  fi

  pkg install -y ruby git curl autoconf bison flex openssl libxml2 libxslt libyaml ncurses zlib 2>/dev/null

  if [ ! -d "$METASPLOIT_DIR" ]; then
    mkdir -p "$(dirname "$METASPLOIT_DIR")" || return 1
    git clone --depth 1 https://github.com/rapid7/metasploit-framework "$METASPLOIT_DIR" 2>/dev/null || {
      log_error "Falha ao clonar Metasploit"
      return 1
    }
  fi

  cd "$METASPLOIT_DIR"
  gem install bundler 2>/dev/null
  bundle install --jobs 4 2>/dev/null

  for bin in msfconsole msfvenom msfrpc msfrpcd msfdb; do
    cat > "$PREFIX/bin/$bin" << BINEOF
#!/usr/bin/env bash
exec bundle exec ruby "$METASPLOIT_DIR/$bin" "\$@"
BINEOF
    chmod +x "$PREFIX/bin/$bin"
    sha256sum "$PREFIX/bin/$bin" > "$METASPLOIT_DIR/.karnel-wrapper-$bin"
  done
  : > "$METASPLOIT_DIR/.karnel-installed"

  log_success "metasploit instalado"
  return 0
}

uninstall_metasploit() {
  log_info "Removendo Metasploit..."
  for bin in msfconsole msfvenom msfrpc msfrpcd msfdb; do
    if [ -f "$METASPLOIT_DIR/.karnel-wrapper-$bin" ]; then
      [ "$(sha256sum "$PREFIX/bin/$bin" 2>/dev/null)" = "$(<"$METASPLOIT_DIR/.karnel-wrapper-$bin")" ] && rm -f "$PREFIX/bin/$bin"
    fi
  done
  [ -f "$METASPLOIT_DIR/.karnel-installed" ] && rm -rf "$METASPLOIT_DIR"
  log_success "metasploit removido"
}

update_metasploit() {
  if [ -d "$METASPLOIT_DIR" ]; then
    git -C "$METASPLOIT_DIR" pull
    cd "$METASPLOIT_DIR" && bundle install --jobs 4 2>/dev/null
    log_success "metasploit atualizado"
    return 0
  fi
  log_warn "metasploit não encontrado"
  return 1
}

reinstall_metasploit() {
  uninstall_metasploit
  install_metasploit
}
