#!/usr/bin/env bash
# E2E: full first-search bash pipeline.
#
#   preflight -> gh-search x7 (parallel) -> dedup-rank -> verify-repo x5
#             -> staleness x5 -> cache write -> cache read roundtrip
#
# Mocked: gh CLI via tests/lib/mock-bin/gh. No real network. Offline.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== e2e-first-search-flow ==="

unset MOCK_GH_FAIL MOCK_GH_FAIL_FIRST_N MOCK_GH_ARGS_LOG MOCK_GH_FIXTURE || true

WORK=$(mktemp -d)
# Isolate per-test cache so we don't trample the dev user's real cache.
export HOME="$WORK/home"
mkdir -p "$HOME/.cache/reporecon"
trap 'rm -rf "$WORK" /tmp/mock-gh-counter-* 2>/dev/null || true' EXIT

# --- Step 1: preflight ---
export MOCK_GH_FIXTURE='{"resources":{"core":{"remaining":4900},"search":{"remaining":29}}}'
PREFLIGHT_OUT=$(bash "$ROOT/scripts/preflight.sh" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "preflight succeeds with healthy rate budget"
CORE_REM=$(echo "$PREFLIGHT_OUT" | jq -r '.core_remaining')
assert_eq "4900" "$CORE_REM" "preflight emits core_remaining"

# --- Step 2: gh-search x7 (parallel) ---
# Each call returns 3 candidates with overlapping full_names across queries to exercise dedup.
SEARCH_FIXTURE=$(cat <<'EOF'
[
  {"full_name":"alpha/one","description":"A","stars":100,"pushed_at":"2026-05-01T00:00:00Z","archived":false,"language":"Rust","url":"https://github.com/alpha/one"},
  {"full_name":"alpha/two","description":"B","stars":80,"pushed_at":"2025-12-01T00:00:00Z","archived":false,"language":"Go","url":"https://github.com/alpha/two"},
  {"full_name":"alpha/three","description":"C","stars":60,"pushed_at":"2024-01-01T00:00:00Z","archived":false,"language":"Py","url":"https://github.com/alpha/three"}
]
EOF
)
export MOCK_GH_FIXTURE="$SEARCH_FIXTURE"

ALL_RESULTS="$WORK/all-results.json"
: > "$ALL_RESULTS"
# Run 7 queries in parallel via xargs -P 4 (matches v0.4 protocol shape).
printf 'q1\nq2\nq3\nq4\nq5\nq6\nq7\n' \
  | xargs -I{} -P 4 bash -c 'bash "$0" "$1" 2>/dev/null' "$ROOT/scripts/gh-search.sh" {} \
  >> "$ALL_RESULTS" 2>/dev/null

# Each line is a JSON array; merge + dedup by full_name + sort by stars desc + take top 5.
MERGED=$(jq -s 'add | unique_by(.full_name) | sort_by(-.stars) | .[:5]' "$ALL_RESULTS")
COUNT=$(echo "$MERGED" | jq 'length')
assert_eq "3" "$COUNT" "dedup-rank yields 3 unique candidates (fixture has 3 unique full_names)"

# --- Step 3: verify-repo x N (use the actually-unique ones) ---
VERIFY_FIXTURE='{"full_name":"alpha/one","stargazers_count":100,"pushed_at":"2026-05-01T00:00:00Z","archived":false,"default_branch":"main","language":"Rust","html_url":"https://github.com/alpha/one"}'
export MOCK_GH_FIXTURE="$VERIFY_FIXTURE"

VERIFIED_LIST="$WORK/verified.json"
: > "$VERIFIED_LIST"
for repo in $(echo "$MERGED" | jq -r '.[].full_name'); do
  bash "$ROOT/scripts/verify-repo.sh" "$repo" 2>/dev/null >> "$VERIFIED_LIST" || true
done

VERIFIED_COUNT=$(jq -s 'length' "$VERIFIED_LIST")
assert_eq "3" "$VERIFIED_COUNT" "all 3 candidates verified"
HAS_VERIFIED_AT=$(jq -s 'all(.[]; .verified_at != null and (.verified_at | test("^[0-9]{4}-")))' "$VERIFIED_LIST")
assert_eq "true" "$HAS_VERIFIED_AT" "every verified candidate has ISO verified_at"

# --- Step 4: staleness per candidate ---
BADGE_LOG="$WORK/badges.txt"
: > "$BADGE_LOG"
jq -c '.' "$VERIFIED_LIST" 2>/dev/null | while IFS= read -r meta; do
  bash "$ROOT/scripts/staleness.sh" "$meta" 2>/dev/null >> "$BADGE_LOG" || true
done
# Mock metadata has no contributor_count, so we only check the script ran without error.
LINES=$(wc -l < "$BADGE_LOG" | tr -d ' ')
assert_eq "3" "$LINES" "staleness emitted one line per verified candidate"

# --- Step 5: cache write + read roundtrip ---
KEY=$(bash "$ROOT/scripts/cache.sh" key "first search test idea")
JUDGMENT='{"verdict":"yellow","candidates":["alpha/one","alpha/two","alpha/three"]}'
echo "$JUDGMENT" | bash "$ROOT/scripts/cache.sh" put "$KEY"
ROUND=$(bash "$ROOT/scripts/cache.sh" get "$KEY"); RC=$?
assert_exit_code 0 "$RC" "cache get hit after put"
assert_contains '"verdict":"yellow"' "$ROUND" "cache roundtrip preserves verdict"
assert_contains 'alpha/one' "$ROUND" "cache roundtrip preserves candidate list"

test_summary
