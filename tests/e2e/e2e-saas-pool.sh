#!/usr/bin/env bash
# E2E: SaaS web_candidate verification pipeline.
#
# SKILL.md step 3.5: for each first-web-saas candidate, run verify-url.sh
# and drop ones whose URLs don't resolve. This e2e replays that mini-pipeline
# with mocked curl.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== e2e-saas-pool ==="

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- 1. single URL: 200 OK -> exit 0, JSON shape ---
export MOCK_CURL_CODE=200
export MOCK_CURL_URL=https://good.example.com
OUT=$(bash "$ROOT/scripts/verify-url.sh" "https://good.example.com" 2>/dev/null); RC=$?
assert_exit_code 0 "$RC" "verify-url 200 -> 0"
assert_contains '"http_code":200' "$OUT" "verify-url emits http_code 200"
assert_contains '"url"' "$OUT" "verify-url emits url field"

# --- 2. 404 -> exit 20 ---
export MOCK_CURL_CODE=404
bash "$ROOT/scripts/verify-url.sh" "https://gone.example.com" >/dev/null 2>&1; RC=$?
assert_exit_code 20 "$RC" "verify-url 404 -> 20"

# --- 3. SaaS pool filter: pretend the LLM returned 4 web candidates ---
# Two GH (should not run verify-url; we just keep them), two SaaS (must verify).
CANDIDATES=$(cat <<'EOF'
[
  {"name":"GitHub repo A","provenance":"first-web-github","url":"https://github.com/a/b"},
  {"name":"SaaS one","provenance":"first-web-saas","url":"https://saas-good.example.com"},
  {"name":"SaaS dead","provenance":"first-web-saas","url":"https://saas-dead.example.com"},
  {"name":"GitHub repo B","provenance":"first-web-github","url":"https://github.com/c/d"}
]
EOF
)

# Walk SaaS candidates, verify each. Build the surviving list.
SAAS_LIST=$(echo "$CANDIDATES" | jq -c '.[] | select(.provenance=="first-web-saas")')

SURVIVING_FILE="$WORK/surviving.json"
: > "$SURVIVING_FILE"

while IFS= read -r cand; do
  URL=$(echo "$cand" | jq -r '.url')
  case "$URL" in
    *saas-good*) export MOCK_CURL_CODE=200 ;;
    *saas-dead*) export MOCK_CURL_CODE=404 ;;
    *)           export MOCK_CURL_CODE=200 ;;
  esac
  if bash "$ROOT/scripts/verify-url.sh" "$URL" >/dev/null 2>&1; then
    echo "$cand" >> "$SURVIVING_FILE"
  fi
done <<< "$SAAS_LIST"

SURV_COUNT=$(wc -l < "$SURVIVING_FILE" | tr -d ' ')
assert_eq "1" "$SURV_COUNT" "1 of 2 SaaS candidates survived URL verification"

SURV_CONTENT=$(cat "$SURVIVING_FILE")
assert_contains 'saas-good' "$SURV_CONTENT" "the 200-OK SaaS candidate kept"
assert_not_contains 'saas-dead' "$SURV_CONTENT" "the 404 SaaS candidate dropped"

test_summary
