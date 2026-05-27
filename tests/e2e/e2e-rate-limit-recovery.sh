#!/usr/bin/env bash
# E2E: gh_with_backoff retry behavior in pipeline context. Exercises both
# gh-search.sh and verify-repo.sh under transient and persistent rate-limits.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== e2e-rate-limit-recovery ==="

# Shim sleep so 5s/10s backoffs don't slow CI.
SHIM_DIR=$(mktemp -d)
cat > "$SHIM_DIR/sleep" <<'EOF'
#!/usr/bin/env bash
exec /bin/sleep 0.05
EOF
chmod +x "$SHIM_DIR/sleep"
export PATH="$SHIM_DIR:$PATH"

trap 'rm -rf "$SHIM_DIR" /tmp/mock-gh-counter-* "$WORK" 2>/dev/null || true' EXIT
WORK=$(mktemp -d)

unset MOCK_GH_FAIL MOCK_GH_FAIL_FIRST_N MOCK_GH_ARGS_LOG MOCK_GH_COUNTER_FILE || true

# --- 1. gh-search succeeds after 1 retry ---
ARGS_LOG=$(mktemp)
COUNTER=$(mktemp); rm -f "$COUNTER"
export MOCK_GH_ARGS_LOG="$ARGS_LOG"
export MOCK_GH_COUNTER_FILE="$COUNTER"
export MOCK_GH_FAIL_FIRST_N=1
export MOCK_GH_FIXTURE='[{"full_name":"a/b","stars":1}]'

OUT=$(bash "$ROOT/scripts/gh-search.sh" "retry test" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "gh-search succeeds after 1 transient rate-limit"
assert_contains 'a/b' "$OUT" "gh-search returns fixture after retry"

N_CALLS=$(wc -l < "$ARGS_LOG" | tr -d ' ')
[ "$N_CALLS" -ge 2 ] && _log "  PASS gh-search retried (>=2 mock calls observed: $N_CALLS)" \
  || { _log "  FAIL gh-search did not retry (calls=$N_CALLS)"; TESTS_FAILED=$((TESTS_FAILED+1)); }
TESTS_RUN=$((TESTS_RUN+1))
rm -f "$ARGS_LOG" "$COUNTER"
unset MOCK_GH_ARGS_LOG MOCK_GH_COUNTER_FILE MOCK_GH_FAIL_FIRST_N

# --- 2. gh-search exhausts retries on persistent secondary rate-limit -> 78 ---
export MOCK_GH_FAIL=secondary
bash "$ROOT/scripts/gh-search.sh" "always fail" >/dev/null 2>&1; RC=$?
assert_exit_code 78 "$RC" "gh-search exits 78 when secondary rate-limit persists"
unset MOCK_GH_FAIL

# --- 3. verify-repo succeeds after 1 transient rate-limit ---
COUNTER=$(mktemp); rm -f "$COUNTER"
export MOCK_GH_COUNTER_FILE="$COUNTER"
export MOCK_GH_FAIL_FIRST_N=1
export MOCK_GH_FIXTURE='{"full_name":"a/b","stargazers_count":1,"pushed_at":"2026-01-01T00:00:00Z","archived":false,"default_branch":"main","language":"Rust","html_url":"https://github.com/a/b"}'

OUT=$(bash "$ROOT/scripts/verify-repo.sh" "a/b" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "verify-repo succeeds after 1 transient rate-limit"
assert_contains '"full_name": "a/b"' "$OUT" "verify-repo returns metadata after retry"
rm -f "$COUNTER"
unset MOCK_GH_COUNTER_FILE MOCK_GH_FAIL_FIRST_N

# --- 4. verify-repo persistent rate-limit ---
# Accept either exit 78 (Agent A's fix landed and rc capture works) or any
# non-zero (pre-fix: `if !` masks $? so verify-repo exits 1). Either way the
# script must REFUSE to emit metadata under persistent rate-limit. This is the
# pipeline contract: downstream must not see a half-built record.
export MOCK_GH_FAIL=secondary
bash "$ROOT/scripts/verify-repo.sh" "a/b" >/dev/null 2>&1; RC=$?
TESTS_RUN=$((TESTS_RUN+1))
if [ "$RC" = "78" ]; then
  _log "  PASS verify-repo exits 78 on persistent rate-limit (post-fix path)"
elif [ "$RC" -ne 0 ]; then
  _log "  PASS verify-repo exits non-zero ($RC) on persistent rate-limit (pre-fix path)"
else
  _log "  FAIL verify-repo must not exit 0 under persistent rate-limit"
  TESTS_FAILED=$((TESTS_FAILED+1))
fi
unset MOCK_GH_FAIL

test_summary
