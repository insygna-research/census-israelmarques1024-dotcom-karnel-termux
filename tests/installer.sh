#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

assert_release_ref_checkout() (
  source "$ROOT_DIR/install.sh"
  progress_bar() { :; }
  log_step() { :; }
  log_ok() { :; }
  log_fail() { :; }
  log_info() { :; }

  KARNEL_REPO="$ROOT_DIR"
  BRANCH="v4.14.0"
  RELEASE_REF="$BRANCH"
  PREFIX="$TEST_ROOT/prefix"
  mkdir -p "$PREFIX/share/zsh/site-functions"
  GIT_LOG="$TEST_ROOT/git.log"
  git() { printf '%s\n' "$*" >>"$GIT_LOG"; }

  clone_repo
  grep -Fx -- "-C $ROOT_DIR fetch --depth=1 origin refs/tags/v4.14.0" "$GIT_LOG" >/dev/null
  grep -Fx -- "-C $ROOT_DIR checkout --detach FETCH_HEAD" "$GIT_LOG" >/dev/null
  ! grep -Fqx -- "-C $ROOT_DIR pull origin main" "$GIT_LOG"
)

if ! assert_release_ref_checkout; then
  printf 'FAIL: release ref did not use an immutable tag checkout\n' >&2
  exit 1
fi

if bash "$ROOT_DIR/install.sh" --ref main >/dev/null 2>&1; then
  printf 'FAIL: mutable release ref was accepted\n' >&2
  exit 1
fi

printf 'Installer contracts: 2 passed\n'
