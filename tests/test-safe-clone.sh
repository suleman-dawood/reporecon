#!/usr/bin/env bash
# Unit tests for scripts/safe-clone.sh — exercises every guard path per D2-06.
#
# Strategy: prepend a temp dir to PATH containing wrapper scripts for `gh`
# and `git` that emit canned output/exit codes per test case. Each test
# invokes safe-clone.sh and asserts on exit code and stderr/stdout.
#
# Exit code contract being tested:
#   0  success
#   1  bad args / malformed owner-repo / clone error
#   11 oversize (>50000 KB)
#   12 timeout (git clone exceeded budget)
#   13 LFS-only repo (no source files after clone)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SAFE_CLONE="$REPO_ROOT/scripts/safe-clone.sh"

TMPDIR_ROOT="$(mktemp -d -t safe-clone-tests-XXXXXX)"
trap 'rm -rf "$TMPDIR_ROOT"; find /tmp/reporecon -maxdepth 1 -name "reporecon-XXXX*" -mmin -5 -exec rm -rf {} + 2>/dev/null || true' EXIT

PASS=0
FAIL=0
FAILED_TESTS=()

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1 — $2" >&2; FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); }

# Build a per-test PATH overlay with stubs for gh and git.
# Usage: make_stubs <test-name> <gh-body> <git-body>
make_stubs() {
  local name="$1"
  local gh_body="$2"
  local git_body="$3"
  local d="$TMPDIR_ROOT/$name"
  mkdir -p "$d"
  cat >"$d/gh" <<EOF
#!/usr/bin/env bash
$gh_body
EOF
  cat >"$d/git" <<EOF
#!/usr/bin/env bash
$git_body
EOF
  chmod +x "$d/gh" "$d/git"
  echo "$d"
}

run_safe_clone() {
  local stub_dir="$1"; shift
  PATH="$stub_dir:$PATH" bash "$SAFE_CLONE" "$@"
}

# ---------------------------------------------------------------------------
# Test 1: missing args → exit 1, stderr contains "usage"
# ---------------------------------------------------------------------------
t1() {
  local stub; stub="$(make_stubs t1 'exit 0' 'exit 0')"
  local rc=0 err
  err="$(PATH="$stub:$PATH" bash "$SAFE_CLONE" 2>&1 >/dev/null)" || rc=$?
  if [ "$rc" -eq 1 ] && echo "$err" | grep -qi 'usage'; then
    pass "Test 1: missing args exits 1 with usage"
  else
    fail "Test 1" "expected exit 1 + usage, got rc=$rc err='$err'"
  fi
}

# ---------------------------------------------------------------------------
# Test 2: malformed owner/repo → exit 1
# ---------------------------------------------------------------------------
t2() {
  local stub; stub="$(make_stubs t2 'exit 0' 'exit 0')"
  local rc=0
  PATH="$stub:$PATH" bash "$SAFE_CLONE" "not-a-valid-slug" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 1 ]; then
    pass "Test 2: malformed owner/repo exits 1"
  else
    fail "Test 2" "expected exit 1, got rc=$rc"
  fi
}

# ---------------------------------------------------------------------------
# Test 3: oversize repo → exit 11
# ---------------------------------------------------------------------------
t3() {
  local stub; stub="$(make_stubs t3 'echo 99999' 'exit 0')"
  local rc=0
  PATH="$stub:$PATH" bash "$SAFE_CLONE" "octocat/Hello-World" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 11 ]; then
    pass "Test 3: oversize exits 11"
  else
    fail "Test 3" "expected exit 11, got rc=$rc"
  fi
}

# ---------------------------------------------------------------------------
# Test 4: timeout path — git stub sleeps past budget → exit 12
# Uses timeout 2s in env override to keep test fast; safe-clone uses real
# timeout binary which honors TIMEOUT_SECS env override (test-only knob).
# ---------------------------------------------------------------------------
t4() {
  local stub; stub="$(make_stubs t4 'echo 100' 'sleep 30')"
  local rc=0
  SAFE_CLONE_TIMEOUT=2 PATH="$stub:$PATH" bash "$SAFE_CLONE" "octocat/Hello-World" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 12 ]; then
    pass "Test 4: timeout exits 12"
  else
    fail "Test 4" "expected exit 12, got rc=$rc"
  fi
}

# ---------------------------------------------------------------------------
# Test 5: trap cleanup — kill mid-clone, verify no leftover dir
# ---------------------------------------------------------------------------
t5() {
  local stub; stub="$(make_stubs t5 'echo 100' 'sleep 30')"
  local before after
  before="$(find /tmp/reporecon -maxdepth 1 -type d -name 'reporecon-*' 2>/dev/null | wc -l || echo 0)"
  PATH="$stub:$PATH" bash "$SAFE_CLONE" "octocat/Hello-World" >/dev/null 2>&1 &
  local pid=$!
  sleep 0.5
  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  sleep 0.3
  after="$(find /tmp/reporecon -maxdepth 1 -type d -name 'reporecon-*' 2>/dev/null | wc -l || echo 0)"
  if [ "$after" -le "$before" ]; then
    pass "Test 5: trap cleanup removes partial clone dir (before=$before after=$after)"
  else
    fail "Test 5" "leftover dirs after kill (before=$before after=$after)"
  fi
}

# ---------------------------------------------------------------------------
# Test 6: success path — git stub creates dest + a .py file → exit 0, prints DEST
# ---------------------------------------------------------------------------
t6() {
  local stub; stub="$(make_stubs t6 'echo 100' '
# git clone --depth 1 ... -- <url> <dest>
# Find <dest> = last arg
DEST="${!#}"
mkdir -p "$DEST"
echo "print(\"hi\")" > "$DEST/main.py"
exit 0
')"
  local rc=0 out
  out="$(PATH="$stub:$PATH" bash "$SAFE_CLONE" "octocat/Hello-World" 2>/dev/null)" || rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$out" ] && [[ "$out" == /tmp/reporecon/* ]] && [ -d "$out" ]; then
    pass "Test 6: success prints DEST and exits 0 (dest=$out)"
    rm -rf "$out"
  else
    fail "Test 6" "expected rc=0 + /tmp/reporecon/* dest, got rc=$rc out='$out'"
  fi
}

# ---------------------------------------------------------------------------
# Test 7: GIT_LFS_SKIP_SMUDGE export verified by git stub
# ---------------------------------------------------------------------------
t7() {
  local stub; stub="$(make_stubs t7 'echo 100' '
if [ "${GIT_LFS_SKIP_SMUDGE:-}" != "1" ]; then exit 99; fi
DEST="${!#}"
mkdir -p "$DEST"
echo "x" > "$DEST/x.py"
exit 0
')"
  local rc=0
  PATH="$stub:$PATH" bash "$SAFE_CLONE" "octocat/Hello-World" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "Test 7: GIT_LFS_SKIP_SMUDGE=1 is exported to git env"
  else
    fail "Test 7" "expected rc=0 (env propagated), got rc=$rc"
  fi
  # cleanup any dest from success path
  find /tmp/reporecon -maxdepth 1 -type d -name 'reporecon-*' -mmin -1 -exec rm -rf {} + 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------
t1
t2
t3
t4
t5
t6
t7

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  - %s\n' "${FAILED_TESTS[@]}" >&2
  exit 1
fi
exit 0
