#!/usr/bin/env bash
# Unit tests for scripts/status.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/assert.sh"

_log "=== test-status ==="

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX"
SCRIPT="$ROOT/scripts/status.sh"

# Case: start writes to stderr only; stdout is empty
STDOUT_FILE=$(mktemp)
STDERR_FILE=$(mktemp)
bash "$SCRIPT" start sharpen >"$STDOUT_FILE" 2>"$STDERR_FILE"
STDOUT_BYTES=$(wc -c < "$STDOUT_FILE" | tr -d ' ')
STDERR_CONTENT=$(cat "$STDERR_FILE")
assert_eq "0" "$STDOUT_BYTES" "start: stdout is empty"
assert_contains "start sharpen" "$STDERR_CONTENT" "start: stderr contains 'start sharpen'"
assert_contains "[reporecon]" "$STDERR_CONTENT" "start: stderr has [reporecon] tag"

# Case: tick writes to stderr only
: > "$STDOUT_FILE"; : > "$STDERR_FILE"
bash "$SCRIPT" tick discover 3/7 >"$STDOUT_FILE" 2>"$STDERR_FILE"
STDOUT_BYTES=$(wc -c < "$STDOUT_FILE" | tr -d ' ')
STDERR_CONTENT=$(cat "$STDERR_FILE")
assert_eq "0" "$STDOUT_BYTES" "tick: stdout is empty"
assert_contains "discover 3/7" "$STDERR_CONTENT" "tick: stderr contains 'discover 3/7'"

# Case: start + done emits elapsed ms
: > "$STDOUT_FILE"; : > "$STDERR_FILE"
bash "$SCRIPT" start judge >/dev/null 2>>"$STDERR_FILE"
sleep 0.05
bash "$SCRIPT" done judge >"$STDOUT_FILE" 2>>"$STDERR_FILE"
STDOUT_BYTES=$(wc -c < "$STDOUT_FILE" | tr -d ' ')
STDERR_CONTENT=$(cat "$STDERR_FILE")
assert_eq "0" "$STDOUT_BYTES" "done: stdout is empty"
assert_match 'done judge \(elapsed [0-9]+ms\)' "$STDERR_CONTENT" "done: emits elapsed Xms"

# Case: error writes to stderr only
: > "$STDOUT_FILE"; : > "$STDERR_FILE"
bash "$SCRIPT" error sharpen "something broke" >"$STDOUT_FILE" 2>"$STDERR_FILE"
STDOUT_BYTES=$(wc -c < "$STDOUT_FILE" | tr -d ' ')
STDERR_CONTENT=$(cat "$STDERR_FILE")
assert_eq "0" "$STDOUT_BYTES" "error: stdout is empty"
assert_contains "ERROR sharpen: something broke" "$STDERR_CONTENT" "error: formatted properly"

# Case: full sequence produces 0 bytes of stdout
: > "$STDOUT_FILE"
{
  bash "$SCRIPT" start phase
  bash "$SCRIPT" tick phase 1/3
  bash "$SCRIPT" tick phase 2/3
  bash "$SCRIPT" done phase
  bash "$SCRIPT" error phase "post-mortem"
} >"$STDOUT_FILE" 2>/dev/null
STDOUT_BYTES=$(wc -c < "$STDOUT_FILE" | tr -d ' ')
assert_eq "0" "$STDOUT_BYTES" "full sequence: combined stdout is 0 bytes"

# Case: no args → exit 2
bash "$SCRIPT" 2>/dev/null; RC=$?
assert_exit_code 2 "$RC" "no args → exit 2"

# Case: unknown event → exit 2
bash "$SCRIPT" bogus step 2>/dev/null; RC=$?
assert_exit_code 2 "$RC" "unknown event → exit 2"

# Case: start without step → exit 2
bash "$SCRIPT" start 2>/dev/null; RC=$?
assert_exit_code 2 "$RC" "start without step → exit 2"

# Case: tick without progress → exit 2
bash "$SCRIPT" tick step 2>/dev/null; RC=$?
assert_exit_code 2 "$RC" "tick without progress → exit 2"

rm -f "$STDOUT_FILE" "$STDERR_FILE"
test_summary
