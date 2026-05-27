#!/usr/bin/env bash
# Unit tests for scripts/verify-repo.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== test-verify-repo ==="

# Shorten retry backoff via local sleep shim.
SHIM_DIR=$(mktemp -d)
trap 'rm -rf "$SHIM_DIR" /tmp/mock-gh-counter-* 2>/dev/null || true' EXIT
cat > "$SHIM_DIR/sleep" <<'EOF'
#!/usr/bin/env bash
exec /bin/sleep 0.05
EOF
chmod +x "$SHIM_DIR/sleep"
export PATH="$SHIM_DIR:$PATH"

unset MOCK_GH_FAIL MOCK_GH_FAIL_FIRST_N || true

# verify-repo.sh makes TWO gh calls: repos/<r> and repos/<r>/contributors.
# Mock returns same fixture for both, but the contributors call uses --jq 'length'.
# Our mock ignores --jq, so contributors call returns the same JSON which jq won't
# transform — verify-repo will set contributor_count to "null" via `|| echo null`.
# That's acceptable for these tests.

# Case: happy path — emits metadata with verified_at
export MOCK_GH_FIXTURE='{"full_name":"foo/bar","stargazers_count":42,"pushed_at":"2026-01-01T00:00:00Z","archived":false,"default_branch":"main","language":"Rust","html_url":"https://github.com/foo/bar"}'
OUT=$(bash "$ROOT/scripts/verify-repo.sh" "foo/bar" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "happy path returns 0"
assert_contains '"full_name": "foo/bar"' "$OUT" "emits full_name"
assert_contains '"stars": 42' "$OUT" "emits stars"
assert_match '"verified_at": "[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$OUT" "verified_at ISO timestamp present"
assert_contains '"url": "https://github.com/foo/bar"' "$OUT" "emits url"

# Case: 404 — exit 1
unset MOCK_GH_FIXTURE
export MOCK_GH_FAIL=404
bash "$ROOT/scripts/verify-repo.sh" "ghost/none" >/dev/null 2>&1; RC=$?
assert_exit_code 1 "$RC" "404 → exit 1"
unset MOCK_GH_FAIL

# Case: rate-limit exhaustion → exit 78 (documented code from gh_with_backoff,
# propagated through the call site).
export MOCK_GH_FAIL=secondary
bash "$ROOT/scripts/verify-repo.sh" "foo/bar" >/dev/null 2>&1; RC=$?
assert_exit_code 78 "$RC" "rate-limit exhaustion exits 78"
unset MOCK_GH_FAIL

# Case: missing arg → exit non-zero
bash "$ROOT/scripts/verify-repo.sh" >/dev/null 2>&1; RC=$?
assert_match '^[1-9][0-9]*$' "$RC" "missing arg exits non-zero (rc=$RC)"

test_summary
