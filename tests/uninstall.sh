#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

# shellcheck source=../karnel/utils/uninstall.sh
source "$ROOT_DIR/karnel/utils/uninstall.sh"

read_confirm_default() {
  local _prompt="$1" _default="$2" var="$3"
  printf -v "$var" '%s' "n"
  return 1
}

mkdir -p "$TEST_ROOT/keep"
if confirm_remove_paths "test data" "$TEST_ROOT/keep"; then
  printf 'FAIL: declined configuration removal succeeded\n' >&2
  exit 1
fi
test -d "$TEST_ROOT/keep"

read_confirm_default() {
  local _prompt="$1" _default="$2" var="$3"
  printf -v "$var" '%s' "y"
}

if ! confirm_remove_paths "test data" "$TEST_ROOT/keep"; then
  printf 'FAIL: confirmed configuration removal failed\n' >&2
  exit 1
fi
test ! -e "$TEST_ROOT/keep"

test_shell_plugin_uninstall_decline() (
  import() { :; }
  loading() {
    printf 'FAIL: shell plugin uninstall used loading spinner\n' >&2
    return 1
  }
  progress_start() { :; }
  progress_update() { :; }
  progress_done() { :; }
  local -a info_messages=()
  log_info() { info_messages+=("$*"); }

  HOME="$TEST_ROOT/home"
  KARNEL_CACHE="$TEST_ROOT/cache"
  # shellcheck source=../karnel/tools/shell/all.sh
  source "$ROOT_DIR/karnel/tools/shell/all.sh"

  local -a plugin_dirs=(
    powerlevel10k zsh-defer zsh-autosuggestions zsh-syntax-highlighting
    zsh-history-substring-search zsh-completions fzf-tab zsh-you-should-use
    zsh-autopair zsh-better-npm-completion
  )
  local -a uninstall_functions=(
    uninstall_powerlevel10k uninstall_zsh_defer uninstall_zsh_autosuggestions
    uninstall_zsh_syntax_highlighting uninstall_history_substring
    uninstall_zsh_completions uninstall_fzf_tab uninstall_you_should_use
    uninstall_zsh_autopair uninstall_better_npm
  )
  local dir func

  for dir in "${plugin_dirs[@]}"; do
    mkdir -p "$ZSH_PLUGINS_DIR/$dir"
  done
  confirm_remove_paths() { return 2; }

  for func in "${uninstall_functions[@]}"; do
    "$func"
  done
  for dir in "${plugin_dirs[@]}"; do
    test -d "$ZSH_PLUGINS_DIR/$dir"
  done
  [[ "${#info_messages[@]}" -eq "${#plugin_dirs[@]}" ]]

  uninstall_all_shell_plugins
  for dir in "${plugin_dirs[@]}"; do
    test -d "$ZSH_PLUGINS_DIR/$dir"
  done
)

if ! test_shell_plugin_uninstall_decline; then
  exit 1
fi

printf 'Uninstall contracts: 3 passed\n'
