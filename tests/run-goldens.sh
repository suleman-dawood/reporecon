#!/usr/bin/env bash
# tests/run-goldens.sh — SCAFFOLD (Plan 01-05, Wave 1).
#
# This is a non-interactive smoke runner over tests/golden/*.json fixtures.
# Plan 07 (Wave 3) wires the actual skill invocation + band-stability assertion
# (TST-02 ship gate: same verdict band across 3 consecutive runs).
#
# Today: prints fixture summaries and dependency versions; exits 0 unless
# fixtures can't be read.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/golden"

echo "=== run-goldens.sh (scaffold) ==="
echo "## Dependency versions"
command -v gh >/dev/null && gh --version | head -n1 || echo "gh: MISSING"
command -v jq >/dev/null && jq --version || echo "jq: MISSING"
echo "bash: ${BASH_VERSION}"

# Preflight (Plan 02 dependency). Tolerate absence in scaffold mode.
if [[ -x "$REPO_ROOT/scripts/preflight.sh" ]]; then
  echo "## Preflight"
  "$REPO_ROOT/scripts/preflight.sh" || {
    echo "preflight failed — abort"; exit 1;
  }
else
  echo "## Preflight: scripts/preflight.sh not present yet (Plan 02) — skipping in scaffold mode"
fi

shopt -s nullglob
fixtures=("$FIXTURE_DIR"/*.json)
if (( ${#fixtures[@]} == 0 )); then
  echo "No fixtures found in $FIXTURE_DIR" >&2
  exit 1
fi

for f in "${fixtures[@]}"; do
  scenario=$(jq -r '.scenario' "$f")
  idea=$(jq -r '.idea' "$f")
  expected=$(jq -r '.expected_verdict_band' "$f")
  echo ""
  echo "## Scenario: $scenario — $(basename "$f")"
  echo "Idea: $idea"
  echo "Expected band: $expected"
  # ----------------------------------------------------------------------
  # [TODO Plan 07] invoke skill non-interactively with idea, capture verdict,
  # compare to expected_verdict_band × 3 runs (TST-02 stability gate).
  # ----------------------------------------------------------------------
  echo "[TODO Plan 07] wire skill invocation here"
done

echo ""
echo "=== scaffold complete — Plan 07 wires real verdict assertions ==="
exit 0
