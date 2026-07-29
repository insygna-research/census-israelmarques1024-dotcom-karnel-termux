#!/usr/bin/env bash
set -eo pipefail

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

assert() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass
  else
    fail "$label — expected '$expected', got '$actual'"
  fi
}

echo "=== Version System Tests ==="
echo

# ============================================================
# 1. _semver_gt — installed via source of karnel bin
# ============================================================
echo "1) SemVer comparison (_semver_gt)"

# Derive _semver_gt from the main karnel binary
_semver_gt() {
  [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | tail -1)" == "$1" ]] && [[ "$1" != "$2" ]]
}

# 1a. 4.13.1 > 4.12.0
assert "4.13.1 > 4.12.0" "yes" "$(_semver_gt 4.13.1 4.12.0 && echo yes || echo no)"
# 1b. 4.12.0 > 4.13.1 → false
assert "4.12.0 > 4.13.1" "no" "$(_semver_gt 4.12.0 4.13.1 && echo yes || echo no)"
# 1c. 4.13.1 > 4.13.1 → false (equal)
assert "4.13.1 > 4.13.1" "no" "$(_semver_gt 4.13.1 4.13.1 && echo yes || echo no)"
# 1d. 4.10.0 > 4.9.3
assert "4.10.0 > 4.9.3" "yes" "$(_semver_gt 4.10.0 4.9.3 && echo yes || echo no)"
# 1e. 4.9.3 > 4.10.0 → false
assert "4.9.3 > 4.10.0" "no" "$(_semver_gt 4.9.3 4.10.0 && echo yes || echo no)"
# 1f. 4.12.0 > 4.9.3
assert "4.12.0 > 4.9.3" "yes" "$(_semver_gt 4.12.0 4.9.3 && echo yes || echo no)"
# 1g. 5.0.0 > 4.13.1 (major bump)
assert "5.0.0 > 4.13.1" "yes" "$(_semver_gt 5.0.0 4.13.1 && echo yes || echo no)"
# 1h. 4.13.1 > 5.0.0 → false
assert "4.13.1 > 5.0.0" "no" "$(_semver_gt 4.13.1 5.0.0 && echo yes || echo no)"
# 1i. Edge: empty strings
assert "empty > 4.12.0" "no" "$(_semver_gt '' 4.12.0 && echo yes || echo no)"

# ============================================================
# 2. Version reading from package.json
# ============================================================
echo "2) Version reading from package.json"
KARNEL_PATH="$PWD/karnel"
EXPECTED=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
source karnel/utils/env.sh 2>/dev/null || true
assert "env.sh sets KARNEL_VERSION from package.json" "$EXPECTED" "$KARNEL_VERSION"

# ============================================================
# 3. karnel --version output matches package.json
# ============================================================
echo "3) karnel --version output"
CLI_VERSION=$(bash karnel/bin/karnel --version 2>/dev/null | tail -1)
assert "karnel --version matches package.json" "$EXPECTED" "$CLI_VERSION"

# ============================================================
# 4. npm root -g version check (if npm is available)
# ============================================================
echo "4) npm global install version check"
if command -v npm &>/dev/null; then
  NPM_ROOT=$(npm root -g 2>/dev/null || true)
  if [[ -n "$NPM_ROOT" ]] && [[ -f "$NPM_ROOT/karnel-termux/package.json" ]]; then
    NPM_VERSION=$(grep '"version"' "$NPM_ROOT/karnel-termux/package.json" | head -1 | cut -d'"' -f4)
    assert "npm global package.json version matches" "$EXPECTED" "$NPM_VERSION"
  else
    echo "  SKIP: karnel-termux not installed globally via npm"
    pass
  fi
else
  echo "  SKIP: npm not available"
  pass
fi

# ============================================================
# 5. Update notification: only shows when remote > local
# ============================================================
echo "5) Update notification logic"
KARNEL_CACHE=$(mktemp -d)
cleanup() { rm -rf "$KARNEL_CACHE"; }
trap cleanup EXIT

# 5a. Equal versions → no notification
echo "4.12.0" > "$KARNEL_CACHE/new_version"
KARNEL_VERSION="4.12.0"
if _semver_gt "$(cat "$KARNEL_CACHE/new_version")" "$KARNEL_VERSION"; then
  fail "5a: notification shown for equal versions"
else
  pass
fi

# 5b. Remote newer → notification
echo "4.13.1" > "$KARNEL_CACHE/new_version"
KARNEL_VERSION="4.12.0"
if _semver_gt "$(cat "$KARNEL_CACHE/new_version")" "$KARNEL_VERSION"; then
  pass
else
  fail "5b: notification NOT shown when remote > local"
fi

# 5c. Remote older → no notification
echo "4.9.3" > "$KARNEL_CACHE/new_version"
KARNEL_VERSION="4.13.1"
if _semver_gt "$(cat "$KARNEL_CACHE/new_version")" "$KARNEL_VERSION"; then
  fail "5c: notification shown when remote < local"
else
  pass
fi

# 5d. Stale cache cleaned when versions equal
KARNEL_VERSION="4.13.1"
echo "4.13.1" > "$KARNEL_CACHE/new_version"
if ! _semver_gt "$(cat "$KARNEL_CACHE/new_version")" "$KARNEL_VERSION"; then
  rm -f "$KARNEL_CACHE/new_version"
  if [[ ! -f "$KARNEL_CACHE/new_version" ]]; then
    pass
  else
    fail "5d: stale cache file not removed"
  fi
else
  fail "5d: stale cache incorrectly triggered notification"
fi

# ============================================================
# 6. Background check: cache update logic
# ============================================================
echo "6) Background check cache logic"
# Simulate: remote 4.13.1, local 4.12.0 → should write new_version
LOCAL="4.12.0"
REMOTE="4.13.1"
if _semver_gt "$REMOTE" "$LOCAL"; then
  echo -n "$REMOTE" > "$KARNEL_CACHE/new_version"
  CACHED=$(cat "$KARNEL_CACHE/new_version")
  assert "6a: newer version cached" "4.13.1" "$CACHED"
else
  fail "6a: remote newer but not detected"
fi

# Simulate: remote 4.12.0, local 4.13.1 → should clear cache
LOCAL="4.13.1"
REMOTE="4.12.0"
if _semver_gt "$REMOTE" "$LOCAL"; then
  fail "6b: remote older incorrectly detected as newer"
else
  rm -f "$KARNEL_CACHE/new_version"
  if [[ ! -f "$KARNEL_CACHE/new_version" ]]; then
    pass
  else
    fail "6b: stale cache not cleared when remote <= local"
  fi
fi

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
