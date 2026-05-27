#!/usr/bin/env bash
# Common assertions. Source from each test file.

TESTS_RUN=0
TESTS_FAILED=0
FAILED_CASES=()

_log() { printf '%s\n' "$*" >&2; }

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-assert_eq}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then
    _log "  PASS $msg"
  else
    _log "  FAIL $msg"
    _log "    expected: $expected"
    _log "    actual:   $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CASES+=("$msg")
  fi
}

assert_exit_code() {
  local expected="$1" actual="$2" msg="${3:-assert_exit_code}"
  assert_eq "$expected" "$actual" "$msg (exit code)"
}

assert_contains() {
  local needle="$1" haystack="$2" msg="${3:-assert_contains}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    _log "  PASS $msg"
  else
    _log "  FAIL $msg"
    _log "    needle: $needle"
    _log "    in:     $(printf '%s' "$haystack" | head -c 200)..."
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CASES+=("$msg")
  fi
}

assert_not_contains() {
  local needle="$1" haystack="$2" msg="${3:-assert_not_contains}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! printf '%s' "$haystack" | grep -qF -- "$needle"; then
    _log "  PASS $msg"
  else
    _log "  FAIL $msg"
    _log "    unexpected needle: $needle"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CASES+=("$msg")
  fi
}

assert_match() {
  local pattern="$1" actual="$2" msg="${3:-assert_match}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s' "$actual" | grep -qE -- "$pattern"; then
    _log "  PASS $msg"
  else
    _log "  FAIL $msg"
    _log "    pattern: $pattern"
    _log "    actual:  $(printf '%s' "$actual" | head -c 200)..."
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CASES+=("$msg")
  fi
}

assert_file_exists() {
  local path="$1"
  local msg="${2:-assert_file_exists $path}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -f "$path" ]; then
    _log "  PASS $msg"
  else
    _log "  FAIL $msg (missing: $path)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_CASES+=("$msg")
  fi
}

assert_file_mode() {
  local expected="$1" path="$2" msg="${3:-assert_file_mode}"
  local actual
  actual=$(stat -c %a "$path" 2>/dev/null || stat -f %A "$path" 2>/dev/null)
  assert_eq "$expected" "$actual" "$msg"
}

test_summary() {
  _log ""
  _log "Ran $TESTS_RUN assertions, $TESTS_FAILED failed."
  if [ $TESTS_FAILED -gt 0 ]; then
    _log "Failed cases:"
    for c in "${FAILED_CASES[@]}"; do _log "  - $c"; done
    return 1
  fi
  return 0
}
