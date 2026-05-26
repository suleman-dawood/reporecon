#!/usr/bin/env bash
# test-vapor-check.sh — exercises all D2-09 trigger paths for vapor-check.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../scripts" && pwd)"
VAPOR="$SCRIPTS_DIR/vapor-check.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

# Helper: write N feature-keyword headings to README.md in DIR.
make_readme() {
  local dir="$1" n="$2"
  local kws=("Feature" "Capability" "Support" "Provides" "Enable" "Integration" "API" "CLI" "Web" "Server" "Client" "Plugin" "Extension" "Tool")
  : > "$dir/README.md"
  echo "# Project" >> "$dir/README.md"
  for ((i=0; i<n; i++)); do
    local kw="${kws[$((i % ${#kws[@]}))]}"
    echo "## $kw number $i" >> "$dir/README.md"
    echo "Body line for $kw $i." >> "$dir/README.md"
  done
}

# Helper: create N empty source files with EXT in DIR.
make_sources() {
  local dir="$1" n="$2" ext="$3"
  for ((i=0; i<n; i++)); do
    : > "$dir/src_$i.$ext"
  done
}

# Helper: write metadata.json with archived + pushed_at.
make_metadata() {
  local dir="$1" archived="$2" pushed="$3"
  printf '{"archived":%s,"pushed_at":"%s"}\n' "$archived" "$pushed" > "$dir/metadata.json"
}

new_clone() {
  local d
  d=$(mktemp -d -p "$TMPDIR")
  echo "$d"
}

# Test 1: Missing arg → exit 1, usage to stderr
echo "--- Test 1: missing arg ---"
set +e
err=$(bash "$VAPOR" 2>&1 >/dev/null)
rc=$?
set -e
if [ "$rc" -eq 1 ] && echo "$err" | grep -qi usage; then
  pass "Test 1"
else
  fail "Test 1" "rc=$rc err=$err"
fi

# Test 2: Non-existent dir → exit 1
echo "--- Test 2: non-existent dir ---"
set +e
bash "$VAPOR" "$TMPDIR/does-not-exist" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 1 ] && pass "Test 2" || fail "Test 2" "rc=$rc"

# Test 3: 5 claims + 2 .py files, no metadata → exit 0 (vapor: source_files ≤ 5)
echo "--- Test 3: low source files ---"
d=$(new_clone)
make_readme "$d" 5
make_sources "$d" 2 py
set +e
out=$(bash "$VAPOR" "$d")
rc=$?
set -e
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '"vapor":true'; then
  pass "Test 3"
else
  fail "Test 3" "rc=$rc out=$out"
fi

# Test 4: 5 claims + 50 .py files + archived:true → exit 0 (vapor: archived path)
echo "--- Test 4: archived path ---"
d=$(new_clone)
make_readme "$d" 5
make_sources "$d" 50 py
make_metadata "$d" true "2026-04-01T00:00:00Z"
set +e
out=$(bash "$VAPOR" "$d" "$d/metadata.json")
rc=$?
set -e
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '"archived":true' && echo "$out" | grep -q '"vapor":true'; then
  pass "Test 4"
else
  fail "Test 4" "rc=$rc out=$out"
fi

# Test 5: 5 claims + 50 .py files + pushed_at:"2023-01-01" → exit 0 (vapor: stale path)
echo "--- Test 5: stale path ---"
d=$(new_clone)
make_readme "$d" 5
make_sources "$d" 50 py
make_metadata "$d" false "2023-01-01T00:00:00Z"
set +e
out=$(bash "$VAPOR" "$d" "$d/metadata.json")
rc=$?
set -e
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '"stale":true' && echo "$out" | grep -q '"vapor":true'; then
  pass "Test 5"
else
  fail "Test 5" "rc=$rc out=$out"
fi

# Test 6: 5 claims + 50 .py files + archived:false + recent pushed_at → exit 1 (NOT vapor)
echo "--- Test 6: recent active not-vapor ---"
d=$(new_clone)
make_readme "$d" 5
make_sources "$d" 50 py
make_metadata "$d" false "2026-04-01T00:00:00Z"
set +e
out=$(bash "$VAPOR" "$d" "$d/metadata.json")
rc=$?
set -e
if [ "$rc" -eq 1 ] && echo "$out" | grep -q '"vapor":false'; then
  pass "Test 6"
else
  fail "Test 6" "rc=$rc out=$out"
fi

# Test 7: 1 claim + 2 .py files → exit 1 (NOT vapor — too few claims)
echo "--- Test 7: too few claims ---"
d=$(new_clone)
make_readme "$d" 1
make_sources "$d" 2 py
set +e
out=$(bash "$VAPOR" "$d")
rc=$?
set -e
if [ "$rc" -eq 1 ] && echo "$out" | grep -q '"vapor":false'; then
  pass "Test 7"
else
  fail "Test 7" "rc=$rc out=$out"
fi

# Test 8: stdout for any successful run parses as JSON with required keys
echo "--- Test 8: JSON schema ---"
d=$(new_clone)
make_readme "$d" 5
make_sources "$d" 2 py
set +e
out=$(bash "$VAPOR" "$d")
set -e
if echo "$out" | jq -e '.vapor != null and .claims != null and .source_files != null and .stale != null and .archived != null' >/dev/null; then
  pass "Test 8"
else
  fail "Test 8" "out=$out"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
