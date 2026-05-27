#!/usr/bin/env bash
# Unit tests for scripts/verify-url.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== test-verify-url ==="

unset MOCK_CURL_CODE MOCK_CURL_URL MOCK_CURL_FAIL || true

# Case: HTTP 200 → exit 0, JSON emitted
export MOCK_CURL_CODE=200
export MOCK_CURL_URL="https://example.com/final"
OUT=$(bash "$ROOT/scripts/verify-url.sh" "https://example.com" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "200 exits 0"
assert_contains '"http_code":200' "$OUT" "emits http_code"
assert_contains '"final_url":"https://example.com/final"' "$OUT" "emits final_url"
assert_match '"checked_at":"[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$OUT" "emits checked_at ISO"

# Case: HTTP 301 (redirect) → still exit 0 (2xx-3xx success per script)
export MOCK_CURL_CODE=301
bash "$ROOT/scripts/verify-url.sh" "https://example.com" >/dev/null 2>&1; RC=$?
assert_exit_code 0 "$RC" "301 (3xx) exits 0"

# Case: HTTP 404 → exit 20
export MOCK_CURL_CODE=404
bash "$ROOT/scripts/verify-url.sh" "https://example.com" >/dev/null 2>&1; RC=$?
assert_exit_code 20 "$RC" "404 → exit 20"

# Case: HTTP 503 → exit 21
export MOCK_CURL_CODE=503
bash "$ROOT/scripts/verify-url.sh" "https://example.com" >/dev/null 2>&1; RC=$?
assert_exit_code 21 "$RC" "503 → exit 21"

# Case: connection refused (curl exit 7) → exit 22
unset MOCK_CURL_CODE
export MOCK_CURL_FAIL=7
bash "$ROOT/scripts/verify-url.sh" "https://example.com" >/dev/null 2>&1; RC=$?
assert_exit_code 22 "$RC" "connect refused → exit 22"

# Case: timeout (curl exit 28) → exit 22
export MOCK_CURL_FAIL=28
bash "$ROOT/scripts/verify-url.sh" "https://example.com" >/dev/null 2>&1; RC=$?
assert_exit_code 22 "$RC" "timeout → exit 22"
unset MOCK_CURL_FAIL

# Case: invalid URL format → exit 23
bash "$ROOT/scripts/verify-url.sh" "not-a-url" >/dev/null 2>&1; RC=$?
assert_exit_code 23 "$RC" "invalid URL → exit 23"

bash "$ROOT/scripts/verify-url.sh" "ftp://example.com" >/dev/null 2>&1; RC=$?
assert_exit_code 23 "$RC" "ftp:// → exit 23"

test_summary
