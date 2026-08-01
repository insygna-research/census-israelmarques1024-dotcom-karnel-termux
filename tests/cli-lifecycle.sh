#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

export KARNEL_PATH="$ROOT_DIR/karnel"
export KARNEL_CACHE="$TEST_ROOT/cache"

pass=0

assert_failure() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'FAIL: %s unexpectedly succeeded\n' "$description" >&2
    exit 1
  fi
  ((pass += 1))
}

import() { :; }
log_error() { :; }
log_warn() { :; }
log_info() { :; }
log_success() { :; }
separator() { :; }
box() { :; }
list_item() { :; }

# shellcheck source=../karnel/cli/commands/update.sh
source "$KARNEL_PATH/cli/commands/update.sh"
update_attempts=()
_update_try_curl() { update_attempts+=(curl); return 1; }
_update_try_git() { update_attempts+=(git); return 1; }
_update_try_npm() { update_attempts+=(npm); return 1; }
_update_try_npm_install() { update_attempts+=(npm-install); return 1; }
_update_try_pnpm() { update_attempts+=(pnpm); return 1; }
_update_show_manual() { :; }
assert_failure "all update methods fail" update_karnel
if [[ "${update_attempts[*]}" != "curl git npm npm-install pnpm" ]]; then
  printf 'FAIL: update methods ran in unexpected order: %s\n' "${update_attempts[*]}" >&2
  exit 1
fi
((pass += 1))

# shellcheck source=../karnel/cli/commands/upgrade.sh
source "$KARNEL_PATH/cli/commands/upgrade.sh"
update_karnel() { return 1; }
assert_failure "upgrade stops when update fails" upgrade_main

# shellcheck source=../karnel/cli/commands/install.sh
source "$KARNEL_PATH/cli/commands/install.sh"
# shellcheck source=../karnel/cli/commands/uninstall.sh
source "$KARNEL_PATH/cli/commands/uninstall.sh"
assert_failure "unknown install target" install_main not-a-target
assert_failure "unknown install target with flags" install_main not-a-target --tool
assert_failure "unknown update target" update_main not-a-target
assert_failure "unknown uninstall target" uninstall_main not-a-target

# shellcheck source=../karnel/modules/network.sh
source "$KARNEL_PATH/modules/network.sh"
install_all_network() { return 1; }
assert_failure "module install preserves batch failure" install_network

printf 'CLI lifecycle contracts: %d passed\n' "$pass"
