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

printf 'Uninstall contracts: 2 passed\n'
