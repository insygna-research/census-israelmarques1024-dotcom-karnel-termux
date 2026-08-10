#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/uninstall"
import "@/utils/version"

LOG_FILE="$KARNEL_CACHE/install_editor.log"
NVCHAD_REPO="https://github.com/DevCoreXOfficial/nvchad-termux.git"
NVCHAD_DIR="$KARNEL_DATA/nvchad-termux"

_nvchad_dependencies() {
  declare -A DEPS=(
    ["git"]="git"
    ["neovim"]="nvim"
    ["nodejs-lts"]="node"
    ["python"]="python"
    ["perl"]="perl"
    ["curl"]="curl"
    ["wget"]="wget"
    ["lua-language-server"]="lua-language-server"
    ["ripgrep"]="rg"
    ["stylua"]="stylua"
    ["tree-sitter"]="tree-sitter"
  )

  local pkg_name bin_name
  for pkg_name in "${!DEPS[@]}"; do
    bin_name="${DEPS[$pkg_name]}"
    if ! command -v "$bin_name" &>/dev/null; then
      if ! yes | pkg install "$pkg_name" &>>"$LOG_FILE"; then
        log_error "Failed to install $pkg_name"
        return 1
      fi
    fi
  done

  log_success "NvChad dependencies installed"
  return 0
}

_install_nvchad_impl() {
  _nvchad_dependencies

  mkdir -p "$(dirname "$LOG_FILE")"

  rm -rf "$NVCHAD_DIR" &>>"$LOG_FILE"
  if git clone "$NVCHAD_REPO" "$NVCHAD_DIR" &>>"$LOG_FILE"; then
    cp -r "$NVCHAD_DIR/nvim" ~/.config/ &>>"$LOG_FILE"
    nvim --headless "+Lazy! sync" +qa &>>"$LOG_FILE"
    nvim --headless "+Lazy! clean nvim-treesitter" +qa &>>"$LOG_FILE"
    nvim --headless "+Lazy! install nvim-treesitter" +qa &>>"$LOG_FILE"
    log_success "NvChad installed"
    return 0
  else
    log_error "Failed to install NvChad"
    return 1
  fi
}

install_nvchad() {
  if [[ -d "$NVCHAD_DIR/.git" && -d "$HOME/.config/nvim" ]]; then
    log_info "NvChad already installed"
    return 0
  fi
  log_info "Installing NvChad..."
  loading "Installing NvChad" _install_nvchad_impl
}

_uninstall_nvchad_impl() {
  if [[ -d "$HOME/.config/nvim" ]]; then
    local remove_rc=0
    confirm_remove_paths "NvChad" "$HOME/.config/nvim" "$HOME/.local/state/nvim" "$HOME/.local/share/nvim" &>>"$LOG_FILE" || remove_rc=$?
    if [[ "$remove_rc" -eq 2 ]]; then
      log_info "NvChad configuration preserved"
    elif [[ "$remove_rc" -ne 0 ]]; then
      log_error "Failed to remove NvChad configuration"
      return 1
    fi
    rm -rf "$NVCHAD_DIR" &>>"$LOG_FILE"
    log_success "NvChad uninstalled"
  else
    log_warn "NvChad not installed"
  fi
}

uninstall_nvchad() {
  if [[ ! -d "$HOME/.config/nvim" ]]; then
    log_info "NvChad is not installed"
    return 2
  fi
  log_info "Uninstalling NvChad..."
  loading "Uninstalling NvChad" _uninstall_nvchad_impl
}

_update_nvchad() {
  loading "Updating NvChad" _do_nvchad_update
}

_do_nvchad_update() {
  if [[ ! -d "$NVCHAD_DIR/.git" || ! -d "$NVCHAD_DIR/nvim" ]]; then
    log_error "NvChad source is not managed by Karnel; refusing to replace Neovim configuration"
    return 1
  fi
  git -C "$NVCHAD_DIR" pull --ff-only &>>"$LOG_FILE" || return 1
  log_success "NvChad source updated; existing Neovim configuration was preserved"
}

update_nvchad() {
  _check_update_needed "NvChad" "$(_get_installed_git_version "$NVCHAD_DIR")" "$(_get_remote_github_version DevCoreXOfficial/nvchad-termux)" _do_nvchad_update
}

reinstall_nvchad() {
  uninstall_nvchad
  install_nvchad
}
