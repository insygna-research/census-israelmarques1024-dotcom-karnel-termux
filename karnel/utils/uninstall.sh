#!/usr/bin/env bash

confirm_remove_paths() {
  local label="$1"
  shift
  local answer path
  local -a existing=()

  for path in "$@"; do
    [[ -e "$path" || -L "$path" ]] && existing+=("$path")
  done
  (( ${#existing[@]} > 0 )) || return 0

  read_confirm_default "Remove $label configuration and data?" "n" answer || return 2
  [[ "$answer" == "y" ]] || return 2

  rm -rf -- "${existing[@]}"
}
