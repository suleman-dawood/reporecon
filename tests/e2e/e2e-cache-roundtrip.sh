#!/usr/bin/env bash
# E2E: cache lifecycle — key derivation, put, get, invalidate, TTL expiry, prune.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"

_log "=== e2e-cache-roundtrip ==="

WORK=$(mktemp -d)
export HOME="$WORK/home"
mkdir -p "$HOME/.cache/reporecon"
trap 'rm -rf "$WORK"' EXIT

# --- 1. derive a key from a normalized sentence ---
KEY=$(bash "$ROOT/scripts/cache.sh" key "Some Sharpened Idea")
KEY2=$(bash "$ROOT/scripts/cache.sh" key "some   sharpened    idea")
assert_eq "$KEY" "$KEY2" "key is whitespace+case insensitive"
assert_match '^[0-9a-f]{40}$' "$KEY" "key is sha1 hex"

# --- 2. put a verdict JSON under that key ---
PAYLOAD='{"verdict":"green","candidates":[]}'
echo "$PAYLOAD" | bash "$ROOT/scripts/cache.sh" put "$KEY"
assert_file_exists "$HOME/.cache/reporecon/${KEY}.json"

# --- 3. get within TTL hits ---
sleep 1
GOT=$(bash "$ROOT/scripts/cache.sh" get "$KEY"); RC=$?
assert_exit_code 0 "$RC" "fresh get hits within TTL"
assert_contains '"verdict":"green"' "$GOT" "roundtrip preserves payload"

# --- 4. invalidate -> get misses ---
bash "$ROOT/scripts/cache.sh" invalidate "$KEY"
bash "$ROOT/scripts/cache.sh" get "$KEY" >/dev/null 2>&1; RC=$?
assert_exit_code 10 "$RC" "post-invalidate get returns 10 (miss)"

# --- 5. TTL expiry: put, then backdate mtime, get -> miss ---
echo "$PAYLOAD" | bash "$ROOT/scripts/cache.sh" put "$KEY"
# Set mtime to 2 hours ago (>3600s TTL). GNU touch -d works; BSD touch -t fallback.
touch -d '2 hours ago' "$HOME/.cache/reporecon/${KEY}.json" 2>/dev/null \
  || touch -t "$(date -v -2H +%Y%m%d%H%M.%S)" "$HOME/.cache/reporecon/${KEY}.json"

bash "$ROOT/scripts/cache.sh" get "$KEY" >/dev/null 2>&1; RC=$?
assert_exit_code 10 "$RC" "TTL-expired get returns 10 (miss)"

# --- 6. prune removes the stale file (>24h) ---
# Backdate further (>24h prune threshold).
touch -d '25 hours ago' "$HOME/.cache/reporecon/${KEY}.json" 2>/dev/null \
  || touch -t "$(date -v -25H +%Y%m%d%H%M.%S)" "$HOME/.cache/reporecon/${KEY}.json"
bash "$ROOT/scripts/cache.sh" prune
[ ! -f "$HOME/.cache/reporecon/${KEY}.json" ] && _log "  PASS prune removed stale entry" \
  || { _log "  FAIL prune did not remove stale entry"; TESTS_FAILED=$((TESTS_FAILED+1)); }
TESTS_RUN=$((TESTS_RUN+1))

test_summary
