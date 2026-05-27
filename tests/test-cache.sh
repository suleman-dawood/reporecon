#!/usr/bin/env bash
# Unit tests for scripts/cache.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"

_log "=== test-cache ==="

# Redirect HOME so cache is sandboxed
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX"
CACHE="$SANDBOX/.cache/reporecon"
SCRIPT="$ROOT/scripts/cache.sh"

# Case: key produces 40 hex chars
K1=$(bash "$SCRIPT" key "Hello World")
assert_match '^[0-9a-f]{40}$' "$K1" "key emits 40 hex sha1"

# Case: case + whitespace normalization
K2=$(bash "$SCRIPT" key "hello world")
K3=$(bash "$SCRIPT" key "  HELLO   WORLD  ")
assert_eq "$K1" "$K2" "key lowercase-normalized"
assert_eq "$K1" "$K3" "key whitespace-normalized"

# Case: put + get roundtrip
KEY=$(bash "$SCRIPT" key "test-roundtrip")
echo '{"verdict":"unique"}' | bash "$SCRIPT" put "$KEY"
OUT=$(bash "$SCRIPT" get "$KEY"); RC=$?
assert_exit_code 0 "$RC" "get after put → exit 0"
assert_contains '"verdict":"unique"' "$OUT" "get returns put content"

# Case: file permissions = 600
FILE="$CACHE/${KEY}.json"
assert_file_exists "$FILE"
MODE=$(stat -c %a "$FILE" 2>/dev/null || stat -f %A "$FILE")
assert_eq "600" "$MODE" "cache file mode is 600"

# Case: get missing key → exit 10
MISSING=$(bash "$SCRIPT" key "never-cached-xyz")
bash "$SCRIPT" get "$MISSING" >/dev/null 2>&1; RC=$?
assert_exit_code 10 "$RC" "missing key → exit 10"

# Case: stale (mtime older than TTL) → exit 10
STALE_KEY=$(bash "$SCRIPT" key "stale-test")
echo '{}' | bash "$SCRIPT" put "$STALE_KEY"
STALE_FILE="$CACHE/${STALE_KEY}.json"
# Set mtime to 2 hours ago (TTL is 1h)
touch -d "2 hours ago" "$STALE_FILE" 2>/dev/null || touch -t "$(date -v-2H +%Y%m%d%H%M 2>/dev/null || date -d '2 hours ago' +%Y%m%d%H%M)" "$STALE_FILE"
bash "$SCRIPT" get "$STALE_KEY" >/dev/null 2>&1; RC=$?
assert_exit_code 10 "$RC" "stale entry → exit 10"

# Case: invalidate is idempotent
INV_KEY=$(bash "$SCRIPT" key "inv-test")
echo '{}' | bash "$SCRIPT" put "$INV_KEY"
bash "$SCRIPT" invalidate "$INV_KEY"; RC=$?
assert_exit_code 0 "$RC" "invalidate → 0"
bash "$SCRIPT" invalidate "$INV_KEY"; RC=$?
assert_exit_code 0 "$RC" "invalidate twice → still 0 (idempotent)"
bash "$SCRIPT" get "$INV_KEY" >/dev/null 2>&1; RC=$?
assert_exit_code 10 "$RC" "get after invalidate → 10"

# Case: prune removes files older than 24h; keeps fresh
FRESH_KEY=$(bash "$SCRIPT" key "fresh-prune")
OLD_KEY=$(bash "$SCRIPT" key "old-prune")
echo '{}' | bash "$SCRIPT" put "$FRESH_KEY"
echo '{}' | bash "$SCRIPT" put "$OLD_KEY"
OLD_FILE="$CACHE/${OLD_KEY}.json"
touch -d "25 hours ago" "$OLD_FILE" 2>/dev/null || touch -t "$(date -v-25H +%Y%m%d%H%M 2>/dev/null || date -d '25 hours ago' +%Y%m%d%H%M)" "$OLD_FILE"
bash "$SCRIPT" prune; RC=$?
assert_exit_code 0 "$RC" "prune → 0"
[ -f "$CACHE/${FRESH_KEY}.json" ] && PRESENT=yes || PRESENT=no
assert_eq "yes" "$PRESENT" "prune keeps fresh files"
[ -f "$OLD_FILE" ] && OLD_PRESENT=yes || OLD_PRESENT=no
assert_eq "no" "$OLD_PRESENT" "prune deletes >24h files"

# Case: prune on missing dir → exit 0
rm -rf "$CACHE"
bash "$SCRIPT" prune; RC=$?
assert_exit_code 0 "$RC" "prune on empty/missing → 0"

# Case: unknown verb → exit 2
bash "$SCRIPT" bogus 2>/dev/null; RC=$?
assert_exit_code 2 "$RC" "unknown verb → exit 2"

# Case: no verb → exit 2
bash "$SCRIPT" 2>/dev/null; RC=$?
assert_exit_code 2 "$RC" "no verb → exit 2"

test_summary
