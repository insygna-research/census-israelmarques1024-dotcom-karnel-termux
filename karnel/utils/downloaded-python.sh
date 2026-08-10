#!/usr/bin/env bash

_downloaded_python_owned() {
  local bin_name="$1" tool_dir="$2" payload="$2/$1.py" marker
  marker="$tool_dir/.karnel-installed"
  [[ -L "$PREFIX/bin/$bin_name" && "$(readlink "$PREFIX/bin/$bin_name")" == "$payload" && -f "$marker" ]] || return 1
  [[ "$(sha256sum "$payload" 2>/dev/null)" == "$(<"$marker")" ]]
}

_downloaded_python_install() {
  local bin_name="$1" tool_dir="$2" download_url="$3" force_update="${4:-}"
  local payload="$tool_dir/$bin_name.py" marker staging marker_staging python3_path
  marker="$tool_dir/.karnel-installed"

  if [[ "$force_update" != force ]] && _downloaded_python_owned "$bin_name" "$tool_dir"; then
    log_info "$bin_name is already installed"
    return 2
  fi
  if [[ -e "$PREFIX/bin/$bin_name" || -L "$PREFIX/bin/$bin_name" || -e "$payload" ]] && ! _downloaded_python_owned "$bin_name" "$tool_dir"; then
    log_error "$bin_name is already owned by another installation"
    return 1
  fi
  mkdir -p "$tool_dir" "$PREFIX/bin" || return 1
  python3_path=$(command -v python3) || return 1
  staging=$(mktemp "$tool_dir/.${bin_name}.XXXXXX") || return 1
  if ! curl -fsSL "$download_url" -o "$staging" || ! sed -i "1s|.*|#!$python3_path|" "$staging" || ! chmod +x "$staging"; then
    rm -f "$staging"
    return 1
  fi
  mv -f "$staging" "$payload" || { rm -f "$staging"; return 1; }
  [[ -e "$PREFIX/bin/$bin_name" || -L "$PREFIX/bin/$bin_name" ]] || ln -s "$payload" "$PREFIX/bin/$bin_name" || return 1
  marker_staging=$(mktemp "$tool_dir/.karnel-installed.XXXXXX") || return 1
  sha256sum "$payload" >"$marker_staging" && mv -f "$marker_staging" "$marker" || { rm -f "$marker_staging"; return 1; }
}

_downloaded_python_uninstall() {
  local bin_name="$1" tool_dir="$2" payload="$2/$1.py" marker
  marker="$tool_dir/.karnel-installed"
  if ! _downloaded_python_owned "$bin_name" "$tool_dir"; then
    log_info "$bin_name is not installed by Karnel"
    return 2
  fi
  rm -f "$PREFIX/bin/$bin_name" "$payload" "$marker"
  rmdir "$tool_dir" 2>/dev/null || true
}

_downloaded_python_update() {
  _downloaded_python_owned "$1" "$2" || { log_error "$1 is not installed by Karnel"; return 1; }
  _downloaded_python_install "$1" "$2" "$3" force
}
