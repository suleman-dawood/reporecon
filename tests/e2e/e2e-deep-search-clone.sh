#!/usr/bin/env bash
# E2E: deep-search clone + vapor-check pipeline.
#
#   safe-clone (mocked git) -> vapor-check (real, reads planted tree)
#
# Profiles drive vapor verdict:
#   normal_repo  -> 10 src files, plain README -> vapor=false  (exit 1)
#   vapor_repo   -> 1 src file, 5 feature claims -> vapor=true (exit 0)
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== e2e-deep-search-clone ==="

unset MOCK_GH_FAIL MOCK_GH_FAIL_FIRST_N MOCK_GH_ARGS_LOG || true

WORK=$(mktemp -d)
trap 'rm -rf "$WORK" /tmp/reporecon/reporecon-* 2>/dev/null || true' EXIT

# --- Case 1: normal_repo -> not vapor ---
export MOCK_GIT_PROFILE=normal_repo
# safe-clone calls `gh api repos/<r> --jq .size`. Our mock ignores --jq so the
# fixture must already be the post-jq scalar value (raw integer string).
export MOCK_GH_FIXTURE='1024'

CLONE_DIR=$(bash "$ROOT/scripts/safe-clone.sh" "alpha/normal" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "safe-clone succeeds for normal_repo"
[ -d "$CLONE_DIR" ] && _log "  clone dir: $CLONE_DIR"
SRC_COUNT=$(find "$CLONE_DIR" -name '*.py' -type f | wc -l | tr -d ' ')
assert_eq "10" "$SRC_COUNT" "normal_repo profile planted 10 .py files"

# Run vapor-check against the normal clone -> exit 1 (not vapor)
bash "$ROOT/scripts/vapor-check.sh" "$CLONE_DIR" >/dev/null 2>&1; RC=$?
assert_exit_code 1 "$RC" "vapor-check returns 1 (not vapor) on normal_repo"

rm -rf "$CLONE_DIR"

# --- Case 2: vapor_repo -> IS vapor ---
export MOCK_GIT_PROFILE=vapor_repo
export MOCK_GH_FIXTURE='512'

CLONE_DIR=$(bash "$ROOT/scripts/safe-clone.sh" "beta/vapor" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "safe-clone succeeds for vapor_repo"
CLAIMS=$(grep -ciE '^## .*(feature|capabilit|support)' "$CLONE_DIR/README.md" || true)
assert_eq "5" "$CLAIMS" "vapor_repo profile planted 5 feature claims"

bash "$ROOT/scripts/vapor-check.sh" "$CLONE_DIR" >/dev/null 2>&1; RC=$?
assert_exit_code 0 "$RC" "vapor-check returns 0 (IS vapor) on vapor_repo"

rm -rf "$CLONE_DIR"

# --- Case 3: oversize repo -> exit 11 BEFORE clone ---
export MOCK_GIT_PROFILE=normal_repo
export MOCK_GH_FIXTURE='99999'

bash "$ROOT/scripts/safe-clone.sh" "gamma/huge" >/dev/null 2>&1; RC=$?
assert_exit_code 11 "$RC" "safe-clone rejects oversize repo with exit 11"

test_summary
