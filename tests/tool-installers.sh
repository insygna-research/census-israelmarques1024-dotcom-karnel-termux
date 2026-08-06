#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

pass=0

assert_keelcode_lifecycle() (
  export PATH="$TEST_ROOT/prefix/bin:$PATH"
  export KARNEL_CACHE="$TEST_ROOT/cache"
  mkdir -p "$KARNEL_CACHE" "$TEST_ROOT/prefix/bin"
  import() { :; }
  log_info() { :; }
  log_success() { :; }
  log_error() { :; }
  npm() {
    case "$1" in
    install) touch "$TEST_ROOT/prefix/bin/keelcode"; chmod +x "$TEST_ROOT/prefix/bin/keelcode" ;;
    uninstall) rm -f "$TEST_ROOT/prefix/bin/keelcode" ;;
    update) : ;;
    esac
  }
  # shellcheck source=../karnel/tools/ai/keelcode/install.sh
  source "$ROOT_DIR/karnel/tools/ai/keelcode/install.sh"

  install_keelcode
  command -v keelcode >/dev/null
  uninstall_keelcode
  ! command -v keelcode
)
assert_keelcode_lifecycle
((pass += 1))

assert_superfile_staged_build() (
  export KARNEL_DATA="$TEST_ROOT/data"
  export KARNEL_CACHE="$TEST_ROOT/cache"
  export PREFIX="$TEST_ROOT/prefix"
  mkdir -p "$KARNEL_CACHE" "$PREFIX/bin"
  import() { :; }
  log_info() { :; }
  log_success() { :; }
  log_error() { :; }
  git() {
    if [[ "$1" == "-C" ]]; then
      printf '%s\n' 'fe41cef5e9ee5b16e79981540c49f932a3d4d249'
      return
    fi
    local destination="${!#}"
    [[ "$1" == "clone" && "$4" == "--branch" && "$5" == "v1.5.0" ]] || return 1
    mkdir -p "$destination"
  }
  go() {
    local previous="" arg output=""
    for arg in "$@"; do
      if [[ "$previous" == "-o" ]]; then
        output="$arg"
        break
      fi
      previous="$arg"
    done
    printf '#!/usr/bin/env bash\nexit 0\n' >"$output"
    chmod +x "$output"
  }
  pkg() { return 1; }
  # shellcheck source=../karnel/tools/utils/superfile/install.sh
  source "$ROOT_DIR/karnel/tools/utils/superfile/install.sh"

  install_superfile
  [[ -x "$PREFIX/bin/spf" ]]
  [[ -d "$KARNEL_DATA/superfile/.git" || -d "$KARNEL_DATA/superfile" ]]
  update_superfile
  [[ -x "$PREFIX/bin/spf" ]]
  [[ ! -d "$KARNEL_DATA/.superfile.previous.$$" ]]
  uninstall_superfile
  [[ ! -e "$PREFIX/bin/spf" && ! -d "$KARNEL_DATA/superfile" ]]
)
assert_superfile_staged_build
((pass += 1))

printf 'Tool installer contracts: %d passed\n' "$pass"
