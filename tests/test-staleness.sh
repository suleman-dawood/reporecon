#!/usr/bin/env bash
# Unit tests for scripts/staleness.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"

_log "=== test-staleness ==="

# Build a pushed_at value N days in the past (UTC).
days_ago_iso() {
  local n="$1"
  date -u -d "@$(( $(date -u +%s) - n * 86400 ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -r "$(( $(date -u +%s) - n * 86400 ))" +%Y-%m-%dT%H:%M:%SZ
}

# Case: fresh non-archived → no badges
RECENT=$(days_ago_iso 10)
META=$(printf '{"archived":false,"pushed_at":"%s","contributor_count":5}' "$RECENT")
OUT=$(bash "$ROOT/scripts/staleness.sh" "$META" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "fresh repo exits 0"
assert_eq "" "$OUT" "fresh non-archived emits no badges"

# Case: archived=true → archived badge
META=$(printf '{"archived":true,"pushed_at":"%s","contributor_count":5}' "$RECENT")
OUT=$(bash "$ROOT/scripts/staleness.sh" "$META" 2>/dev/null)
assert_contains "archived" "$OUT" "archived flag emits archived badge"

# Case: pushed 13 months ago → stale-12mo
OLD=$(days_ago_iso 400)
META=$(printf '{"archived":false,"pushed_at":"%s","contributor_count":5}' "$OLD")
OUT=$(bash "$ROOT/scripts/staleness.sh" "$META" 2>/dev/null)
assert_contains "stale-12mo" "$OUT" "13mo old emits stale-12mo"

# Case: pushed 7 months ago + contributor_count=1 → solo-stale-6mo (not stale-12mo)
MID=$(days_ago_iso 210)
META=$(printf '{"archived":false,"pushed_at":"%s","contributor_count":1}' "$MID")
OUT=$(bash "$ROOT/scripts/staleness.sh" "$META" 2>/dev/null)
assert_contains "solo-stale-6mo" "$OUT" "7mo solo emits solo-stale-6mo"
assert_not_contains "stale-12mo" "$OUT" "7mo solo doesn't trigger 12mo"

# Case: pushed 7 months ago + contributor_count=2 → no solo badge
META=$(printf '{"archived":false,"pushed_at":"%s","contributor_count":2}' "$MID")
OUT=$(bash "$ROOT/scripts/staleness.sh" "$META" 2>/dev/null)
assert_not_contains "solo-stale-6mo" "$OUT" "7mo non-solo skips badge"

# Case: archived + 13mo → both archived + stale-12mo
META=$(printf '{"archived":true,"pushed_at":"%s","contributor_count":1}' "$OLD")
OUT=$(bash "$ROOT/scripts/staleness.sh" "$META" 2>/dev/null)
assert_contains "archived" "$OUT" "combined: archived"
assert_contains "stale-12mo" "$OUT" "combined: stale-12mo"

test_summary
