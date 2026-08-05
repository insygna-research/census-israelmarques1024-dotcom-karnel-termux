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

# shellcheck source=../karnel/cli/commands/update.sh
source "$KARNEL_PATH/cli/commands/update.sh"

mkdir -p "$KARNEL_CACHE"

mock_installer='touch "$KARNEL_CACHE/curl-installed"'
mock_sum=$(printf '%s\n' "$mock_installer" | sha256sum | awk '{print $1}')
mock_sumfile_line=""
mock_tag="v4.14.0"
mock_fail=0

curl() {
  local url="" out="" prev=""
  for arg in "$@"; do
    if [[ "$prev" == "-o" ]]; then
      out="$arg"
      prev=""
    elif [[ "$arg" == "-o" ]]; then
      prev="-o"
    elif [[ "$arg" != -* ]]; then
      url="$arg"
    fi
  done
  if [[ "$mock_fail" == "1" ]]; then
    return 1
  fi
  case "$url" in
  *"/releases/latest")
    printf '{"tag_name":"%s"}\n' "$mock_tag" > "$out"
    ;;
  *"/releases/download/"*"/karnel-termux-install.sh.sha256")
    printf '%s\n' "${mock_sumfile_line:-$mock_sum  karnel-termux-install.sh}" > "$out"
    ;;
  *"/releases/download/"*"/karnel-termux-install.sh")
    printf '%s\n' "$mock_installer" > "$out"
    ;;
  *)
    printf 'FAIL: unexpected curl URL: %s\n' "$url" >&2
    return 1
    ;;
  esac
}
export -f curl

rm -f "$KARNEL_CACHE/curl-installed"
if ! _update_try_curl >/dev/null 2>&1; then
  printf 'FAIL: curl update did not succeed\n' >&2
  exit 1
fi
test -f "$KARNEL_CACHE/curl-installed"
((pass += 1))

rm -f "$KARNEL_CACHE/curl-installed" "$KARNEL_CACHE/curl-args"
mock_installer='printf "%s\n" "$*" > "$KARNEL_CACHE/curl-args"'
mock_sum=$(printf '%s\n' "$mock_installer" | sha256sum | awk '{print $1}')
if ! _update_try_curl >/dev/null 2>&1; then
  printf 'FAIL: curl update did not pass the verified ref\n' >&2
  exit 1
fi
test "$(cat "$KARNEL_CACHE/curl-args")" = "--ref $mock_tag"
((pass += 1))

mock_installer='touch "$KARNEL_CACHE/curl-installed"'
mock_sum=$(printf '%s\n' "$mock_installer" | sha256sum | awk '{print $1}')
rm -f "$KARNEL_CACHE/curl-installed"
mock_sum="0000000000000000000000000000000000000000000000000000000000000000"
if _update_try_curl >/dev/null 2>&1; then
  printf 'FAIL: checksum mismatch was not rejected\n' >&2
  exit 1
fi
test ! -f "$KARNEL_CACHE/curl-installed"
((pass += 1))

rm -f "$KARNEL_CACHE/curl-installed"
mock_sum=$(printf '%s\n' "$mock_installer" | sha256sum | awk '{print $1}')
mock_sumfile_line="$mock_sum  unexpected-file"
if _update_try_curl >/dev/null 2>&1; then
  printf 'FAIL: checksum for an unexpected filename was accepted\n' >&2
  exit 1
fi
test ! -f "$KARNEL_CACHE/curl-installed"
((pass += 1))

printf -v mock_sumfile_line '%s  karnel-termux-install.sh\n%s  karnel-termux-install.sh' "$mock_sum" "$mock_sum"
if _update_try_curl >/dev/null 2>&1; then
  printf 'FAIL: multiple checksum lines were accepted\n' >&2
  exit 1
fi
test ! -f "$KARNEL_CACHE/curl-installed"
((pass += 1))

mock_sumfile_line="not-a-checksum  karnel-termux-install.sh"
if _update_try_curl >/dev/null 2>&1; then
  printf 'FAIL: malformed checksum line was accepted\n' >&2
  exit 1
fi
test ! -f "$KARNEL_CACHE/curl-installed"
((pass += 1))

mock_sumfile_line=""
mock_tag="v4.14.0-rc1"
if _update_try_curl >/dev/null 2>&1; then
  printf 'FAIL: invalid release tag was not rejected\n' >&2
  exit 1
fi
test ! -f "$KARNEL_CACHE/curl-installed"
((pass += 1))

mock_tag="v4.14.0"
mock_fail=1
if _update_try_curl >/dev/null 2>&1; then
  printf 'FAIL: network failure did not fall through\n' >&2
  exit 1
fi
mock_fail=0
test ! -f "$KARNEL_CACHE/curl-installed"
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
