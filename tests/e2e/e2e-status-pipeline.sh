#!/usr/bin/env bash
# E2E: status.sh ticks through a sequenced protocol, verifying:
#   - stdout stays empty (JSON-piping contract)
#   - stderr contains every expected emission in order
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"

_log "=== e2e-status-pipeline ==="

WORK=$(mktemp -d)
export HOME="$WORK/home"
mkdir -p "$HOME/.cache/reporecon"
STDOUT_BUF="$WORK/stdout.txt"
STDERR_BUF="$WORK/stderr.txt"
trap 'rm -rf "$WORK"' EXIT

{
  bash "$ROOT/scripts/status.sh" start preflight
  sleep 0.05
  bash "$ROOT/scripts/status.sh" done  preflight
  bash "$ROOT/scripts/status.sh" start discover
  for i in 1 2 3 4 5 6 7; do
    bash "$ROOT/scripts/status.sh" tick discover "$i/7"
  done
  bash "$ROOT/scripts/status.sh" done  discover
  bash "$ROOT/scripts/status.sh" error judge "test error"
} > "$STDOUT_BUF" 2> "$STDERR_BUF"

STDOUT_BYTES=$(wc -c < "$STDOUT_BUF" | tr -d ' ')
assert_eq "0" "$STDOUT_BYTES" "status.sh writes nothing to stdout"

STDERR_CONTENT=$(cat "$STDERR_BUF")
assert_contains 'start preflight'  "$STDERR_CONTENT" "stderr: start preflight"
assert_contains 'done preflight'   "$STDERR_CONTENT" "stderr: done preflight"
assert_contains 'start discover'   "$STDERR_CONTENT" "stderr: start discover"
assert_contains 'discover 1/7'     "$STDERR_CONTENT" "stderr: first tick"
assert_contains 'discover 7/7'     "$STDERR_CONTENT" "stderr: last tick"
assert_contains 'done discover'    "$STDERR_CONTENT" "stderr: done discover"
assert_contains 'ERROR judge: test error' "$STDERR_CONTENT" "stderr: error emission"

# Elapsed-ms must appear on done preflight (start was recorded).
assert_match 'done preflight \(elapsed [0-9]+ms\)' "$STDERR_CONTENT" "preflight done emits elapsed ms"

test_summary
