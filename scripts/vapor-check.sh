#!/usr/bin/env bash
# vapor-check.sh — HEUR-01 mechanical vapor heuristic (D2-08, D2-09).
#
# Usage: vapor-check.sh <clone-dir> [metadata.json]
#
# Heuristic: a repo is "vapor" when README claims many features but code is sparse,
# the repo is archived, or last push is older than 18 months.
#
# Claim regex (case-insensitive on `## ` heading lines):
#   (feature|capabilit|support|provide|enable|integrat|api|cli|web|server|client|plugin|extension|tool)
#
# Source extensions counted: .py .ts .js .go .rs .rb .java .c .cpp .sh
#
# Trigger (D2-09):
#   claims >= 3 AND (source_files <= 5 OR archived=true OR pushed_at < now-18 months)
#
# Exit 0 if vapor; exit 1 otherwise.
# Always emits one-line JSON to stdout: {"claims":N,"source_files":M,"stale":bool,"archived":bool,"vapor":bool}.

set -euo pipefail

usage() { echo "usage: vapor-check.sh <clone-dir> [metadata.json]" >&2; exit 1; }

[ $# -ge 1 ] || usage
CLONE_DIR="$1"
META="${2:-}"
[ -d "$CLONE_DIR" ] || { echo "not a directory: $CLONE_DIR" >&2; exit 1; }

# Locate README — first match wins.
README=""
for f in README.md README README.rst; do
  if [ -f "$CLONE_DIR/$f" ]; then README="$CLONE_DIR/$f"; break; fi
done

claims=0
if [ -n "$README" ]; then
  claims=$(grep -ciE '^## .*(feature|capabilit|support|provide|enable|integrat|api|cli|web|server|client|plugin|extension|tool)' "$README" || true)
fi

source_files=$(find "$CLONE_DIR" -type f \( \
  -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.go' \
  -o -name '*.rs' -o -name '*.rb' -o -name '*.java' -o -name '*.c' \
  -o -name '*.cpp' -o -name '*.sh' \) -not -path '*/.git/*' | wc -l | tr -d ' ')

# 18-month threshold; GNU date first, BSD date fallback.
THRESHOLD_EPOCH=$(date -d 'now - 18 months' +%s 2>/dev/null || date -v -18m +%s)

archived="false"
stale="false"
if [ -n "$META" ] && [ -f "$META" ]; then
  archived=$(jq -r '.archived // false' "$META")
  pushed_at=$(jq -r '.pushed_at // empty' "$META")
  if [ -n "$pushed_at" ]; then
    pushed_epoch=$(date -d "$pushed_at" +%s 2>/dev/null \
      || date -j -f '%Y-%m-%dT%H:%M:%SZ' "$pushed_at" +%s 2>/dev/null \
      || echo 0)
    if [ "$pushed_epoch" -gt 0 ] && [ "$pushed_epoch" -lt "$THRESHOLD_EPOCH" ]; then
      stale="true"
    fi
  fi
fi

vapor="false"
if [ "$claims" -ge 3 ]; then
  if [ "$source_files" -le 5 ] || [ "$archived" = "true" ] || [ "$stale" = "true" ]; then
    vapor="true"
  fi
fi

printf '{"claims":%d,"source_files":%d,"stale":%s,"archived":%s,"vapor":%s}\n' \
  "$claims" "$source_files" "$stale" "$archived" "$vapor"

[ "$vapor" = "true" ] && exit 0 || exit 1
