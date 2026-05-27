#!/usr/bin/env bash
# Runs every test-*.sh under tests/. Exits non-zero if any fails.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FAILED=0
TOTAL=0
FAILED_FILES=()

for test in "$HERE"/test-*.sh; do
  TOTAL=$((TOTAL + 1))
  echo ""
  echo "==> $(basename "$test")"
  if ! bash "$test"; then
    FAILED=$((FAILED + 1))
    FAILED_FILES+=("$(basename "$test")")
  fi
done

echo ""
echo "Suite: ran $TOTAL test files, $FAILED failed."
if [ "$FAILED" -gt 0 ]; then
  echo "Failed files:"
  for f in "${FAILED_FILES[@]}"; do echo "  - $f"; done
  exit 1
fi
echo "ALL TESTS PASSED"
exit 0
