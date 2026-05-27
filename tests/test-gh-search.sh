#!/usr/bin/env bash
# Unit tests for scripts/gh-search.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== test-gh-search ==="

# Shorten the backoff so retry tests don't sleep 5+10s.
# gh-search.sh uses `sleep 5` literal; we shim sleep via a wrapper bin.
SHIM_DIR=$(mktemp -d)
trap 'rm -rf "$SHIM_DIR" /tmp/mock-gh-counter-* 2>/dev/null || true' EXIT
cat > "$SHIM_DIR/sleep" <<'EOF'
#!/usr/bin/env bash
exec /bin/sleep 0.05
EOF
chmod +x "$SHIM_DIR/sleep"
export PATH="$SHIM_DIR:$PATH"

# The gh mock with --jq filter applied — gh-search.sh passes --jq to gh, but
# our mock ignores filters and emits the fixture verbatim. So fixture must
# already be the jq-filtered output (an array).
unset MOCK_GH_FAIL MOCK_GH_FAIL_FIRST_N MOCK_GH_ARGS_LOG || true

# Case: happy path — returns array JSON
export MOCK_GH_FIXTURE='[{"full_name":"foo/bar","stars":10}]'
OUT=$(bash "$ROOT/scripts/gh-search.sh" "test query" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "happy path returns 0"
assert_contains 'foo/bar' "$OUT" "emits search results"

# Case: topic-only query — routed via topic index (no `in:` qualifier)
ARGS_LOG=$(mktemp)
export MOCK_GH_ARGS_LOG="$ARGS_LOG"
export MOCK_GH_FIXTURE='[]'
bash "$ROOT/scripts/gh-search.sh" "topic:cli-tool" >/dev/null 2>&1
ARGS_CONTENT=$(cat "$ARGS_LOG")
assert_not_contains 'in:name' "$ARGS_CONTENT" "topic-only query omits in: qualifier"
assert_contains 'q=topic:cli-tool' "$ARGS_CONTENT" "topic query forwarded literally"
rm -f "$ARGS_LOG"
unset MOCK_GH_ARGS_LOG

# Case: --in flag applied
ARGS_LOG=$(mktemp)
export MOCK_GH_ARGS_LOG="$ARGS_LOG"
bash "$ROOT/scripts/gh-search.sh" "foo" --in description >/dev/null 2>&1
ARGS_CONTENT=$(cat "$ARGS_LOG")
assert_contains 'in:description' "$ARGS_CONTENT" "--in description passed through"
rm -f "$ARGS_LOG"
unset MOCK_GH_ARGS_LOG

# Case: --per-page override
ARGS_LOG=$(mktemp)
export MOCK_GH_ARGS_LOG="$ARGS_LOG"
bash "$ROOT/scripts/gh-search.sh" "foo" --per-page 7 >/dev/null 2>&1
ARGS_CONTENT=$(cat "$ARGS_LOG")
assert_contains 'per_page=7' "$ARGS_CONTENT" "--per-page override applied"
rm -f "$ARGS_LOG"
unset MOCK_GH_ARGS_LOG

# Case: unknown flag → exit 2
unset MOCK_GH_FIXTURE
export MOCK_GH_FIXTURE='[]'
bash "$ROOT/scripts/gh-search.sh" "foo" --bogus 2>/dev/null; RC=$?
assert_exit_code 2 "$RC" "unknown flag exits 2"

# Case: retry succeeds — first call rate-limited, second call returns
COUNTER=$(mktemp); rm -f "$COUNTER"
export MOCK_GH_COUNTER_FILE="$COUNTER"
export MOCK_GH_FAIL_FIRST_N=1
export MOCK_GH_FIXTURE='[{"full_name":"x/y"}]'
OUT=$(bash "$ROOT/scripts/gh-search.sh" "retry-test" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "succeeds after 1 retry"
assert_contains 'x/y' "$OUT" "retry returns fixture"
unset MOCK_GH_FAIL_FIRST_N MOCK_GH_COUNTER_FILE
rm -f "$COUNTER"

# Case: secondary rate-limit exhausts retries → exit 78
export MOCK_GH_FAIL=secondary
bash "$ROOT/scripts/gh-search.sh" "exhaust" >/dev/null 2>&1; RC=$?
assert_exit_code 78 "$RC" "secondary rate-limit exhaustion → 78"
unset MOCK_GH_FAIL

# Case: generic rate-limit exhaustion → exit 78
export MOCK_GH_FAIL=ratelimit
bash "$ROOT/scripts/gh-search.sh" "exhaust" >/dev/null 2>&1; RC=$?
assert_exit_code 78 "$RC" "ratelimit exhaustion → 78"
unset MOCK_GH_FAIL

# Case: 404 / non-rate-limit failure → exit 1
export MOCK_GH_FAIL=404
bash "$ROOT/scripts/gh-search.sh" "fail" >/dev/null 2>&1; RC=$?
assert_exit_code 1 "$RC" "non-rate-limit failure → 1"
unset MOCK_GH_FAIL

test_summary
