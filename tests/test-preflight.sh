#!/usr/bin/env bash
# Unit tests for scripts/preflight.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== test-preflight ==="

# Case: happy path — sufficient budget
unset MOCK_GH_FAIL MOCK_GH_FAIL_FIRST_N || true
export MOCK_GH_FIXTURE='{"resources":{"core":{"remaining":4500},"search":{"remaining":28}}}'
OUT=$(bash "$ROOT/scripts/preflight.sh" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "happy path returns 0"
assert_contains '"core_remaining":4500' "$OUT" "emits core_remaining"
assert_contains '"search_remaining":28' "$OUT" "emits search_remaining"

# Case: low budget — core too low → exit 3
export MOCK_GH_FIXTURE='{"resources":{"core":{"remaining":10},"search":{"remaining":20}}}'
OUT=$(bash "$ROOT/scripts/preflight.sh" 2>/dev/null); RC=$?
assert_exit_code 3 "$RC" "low core budget exits 3"

# Case: low search budget → exit 3
export MOCK_GH_FIXTURE='{"resources":{"core":{"remaining":500},"search":{"remaining":2}}}'
OUT=$(bash "$ROOT/scripts/preflight.sh" 2>/dev/null); RC=$?
assert_exit_code 3 "$RC" "low search budget exits 3"

# Case: malformed JSON → exit 2 (jq -e guard converts parse failure to exit 2)
export MOCK_GH_FIXTURE='not-json'
OUT=$(bash "$ROOT/scripts/preflight.sh" 2>/dev/null); RC=$?
assert_exit_code 2 "$RC" "malformed rate_limit JSON exits 2"

# Case: gh api rate_limit fails → exit 2
unset MOCK_GH_FIXTURE
export MOCK_GH_FAIL=ratelimit
OUT=$(bash "$ROOT/scripts/preflight.sh" 2>/dev/null); RC=$?
# Mock gh auth status returns 0 always, but rate_limit call hits MOCK_GH_FAIL → exit 1 in mock,
# preflight maps that to exit 2.
assert_exit_code 2 "$RC" "gh api rate_limit failure exits 2"

unset MOCK_GH_FAIL MOCK_GH_FIXTURE
test_summary
