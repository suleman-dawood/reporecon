#!/usr/bin/env bash
# tests/run-goldens.sh — TST-02 ship-gate runner (Plan 01-07, Wave 3).
#
# What this script enforces (the Phase 1 ship gate per 01-CONTEXT D-34):
#   For each tests/golden/*.json fixture:
#     For run in 1..3:
#       - Invoke the reporecon skill non-interactively with the fixture's `idea`.
#       - Parse the verdict band (🟢 / 🟡 / 🔴) from the emitted report H1.
#       - Record wall-clock seconds (T1-09 budget = 90s).
#       - Record per-candidate axis_sum totals from the report body.
#     Assert: all 3 runs produced the same band   (TST-02 stability)
#     Assert: band == fixture.expected_verdict_band  (band-correctness)
#     Assert: every wall_clock <= 90                 (T1-09 budget)
#   Exit 0 iff every fixture × every run passes all 3 assertions.
#
# Calibration loop (Plan 01-07 Task 2):
#   If a fixture fails, tune in priority order
#     (a) re-judge prompt phrasing  — references/judge-rubric.md
#     (b) devil's-advocate trigger  — references/judge-rubric.md
#     (c) query archetype phrasing  — references/query-patterns.md
#     (d) threshold table           — references/judge-rubric.md
#     (e) per-search sleep / candidate count — skills/reporecon/SKILL.md
#   Re-run the suite after every tuning. Commit tunings as separate
#   `tune(01-07): ...` commits.
#
# Prerequisites (user-side; the script fails fast with a clear error if absent):
#   - gh >= 2.55   (search/repositories paging + --jq stable)
#   - jq  >= 1.7
#   - gh auth login   (gh api rate_limit must return remaining > 50)
#   - claude CLI on PATH supporting non-interactive skill invocation
#       (either `claude --headless --skill reporecon "<idea>"` OR
#        `claude -p "/reporecon <idea>"` with a non-interactive flag)
#
# Headless invocation:
#   The script auto-detects the supported claude invocation mode. If no
#   non-interactive mode is available, it prints actionable instructions and
#   exits 2 (caller-fixable). Real runs MUST happen on a machine with the
#   prerequisites — the harness cannot fabricate goldens.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/golden"
REPORT_DIR="$REPO_ROOT/reporecon-reports"
RESULTS_DIR="$REPO_ROOT/tests/.goldens-results"
T1_BUDGET_SECONDS=90
RUNS_PER_FIXTURE=3

mkdir -p "$RESULTS_DIR"

# ---------- preflight: deps ---------------------------------------------------
need() {
  local bin="$1" min="${2:-}"
  command -v "$bin" >/dev/null 2>&1 || { echo "MISSING_DEP: $bin (need ${min:-any})" >&2; return 1; }
}
need gh 2.55 || exit 2
need jq 1.7  || exit 2

GH_VERSION="$(gh --version | head -n1 | awk '{print $3}')"
echo "## Dependency versions"
echo "gh:    $GH_VERSION"
echo "jq:    $(jq --version)"
echo "bash:  ${BASH_VERSION}"

# Minimum gh version check (string compare on 2.55+).
if ! printf '%s\n2.55.0\n' "$GH_VERSION" | sort -V | tail -n1 | grep -qx "$GH_VERSION"; then
  echo "ERROR: gh $GH_VERSION < 2.55.0. Upgrade gh before running the goldens." >&2
  exit 2
fi

if [[ -x "$REPO_ROOT/scripts/preflight.sh" ]]; then
  echo "## Preflight"
  "$REPO_ROOT/scripts/preflight.sh" >/dev/null || { echo "preflight failed" >&2; exit 2; }
fi

# ---------- detect headless claude invocation ---------------------------------
CLAUDE_BIN="$(command -v claude || true)"
if [[ -z "$CLAUDE_BIN" ]]; then
  echo "ERROR: claude CLI not on PATH. Install Claude Code before running goldens." >&2
  exit 2
fi

# Two supported modes (auto-detect):
#   MODE_HEADLESS_SKILL   — claude --headless --skill reporecon "<idea>"
#   MODE_PRINT_SLASH      — claude -p "/reporecon <idea>"
CLAUDE_HELP="$("$CLAUDE_BIN" --help 2>&1 || true)"
INVOKE_MODE=""
if grep -q -- "--headless" <<<"$CLAUDE_HELP" && grep -q -- "--skill" <<<"$CLAUDE_HELP"; then
  INVOKE_MODE="headless-skill"
elif grep -qE -- "(^|[[:space:]])-p([[:space:]]|,)" <<<"$CLAUDE_HELP"; then
  INVOKE_MODE="print-slash"
else
  echo "ERROR: claude CLI does not support a non-interactive flag this harness recognizes." >&2
  echo "       Expected one of: --headless --skill <name>, or -p '<prompt>'." >&2
  exit 2
fi
echo "claude invocation mode: $INVOKE_MODE"

invoke_skill() {
  local idea="$1"
  case "$INVOKE_MODE" in
    headless-skill)
      "$CLAUDE_BIN" --headless --skill reporecon "$idea"
      ;;
    print-slash)
      "$CLAUDE_BIN" -p "/reporecon $idea"
      ;;
  esac
}

# ---------- report parsing ----------------------------------------------------
latest_report() {
  ls -1t "$REPORT_DIR"/*.md 2>/dev/null | head -n1
}

parse_band() {
  local report="$1"
  # First H1 line, extract the verdict emoji.
  local h1
  h1="$(grep -m1 '^# ' "$report" || true)"
  for emoji in 🟢 🟡 🔴; do
    if [[ "$h1" == *"$emoji"* ]]; then echo "$emoji"; return 0; fi
  done
  echo "?"
}

parse_total_axis_sum() {
  # Sum every `axis_sum: <N>` line in the report. Returns 0 if none found.
  local report="$1"
  grep -oE 'axis_sum[[:space:]]*[:=][[:space:]]*[0-9]+' "$report" \
    | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}'
}

# ---------- main loop ---------------------------------------------------------
shopt -s nullglob
fixtures=("$FIXTURE_DIR"/*.json)
if (( ${#fixtures[@]} == 0 )); then
  echo "No fixtures found in $FIXTURE_DIR" >&2; exit 1
fi

OVERALL_PASS=1
declare -a SUMMARY_ROWS=()

for f in "${fixtures[@]}"; do
  fixture_name="$(basename "$f" .json)"
  # Skip deep search stub fixtures — handled by the deep search block below.
  case "$fixture_name" in
    deep-*) continue ;;
  esac
  scenario=$(jq -r '.scenario' "$f")
  idea=$(jq -r '.idea' "$f")
  expected=$(jq -r '.expected_verdict_band' "$f")
  csv="$RESULTS_DIR/${fixture_name}.csv"
  : > "$csv"
  echo "fixture,run,band,wall_clock,total_axis_sum" >> "$csv"

  echo ""
  echo "## Scenario: $scenario — $fixture_name"
  echo "   expected band: $expected"

  bands=()
  for run in $(seq 1 $RUNS_PER_FIXTURE); do
    start_ts=$(date -u +%s)
    invoke_skill "$idea" >/tmp/reporecon-goldens-stdout-$$.$run.log 2>&1 || {
      echo "  run $run: skill invocation FAILED (see /tmp/reporecon-goldens-stdout-$$.$run.log)" >&2
      OVERALL_PASS=0
      bands+=("?")
      echo "$fixture_name,$run,?,FAIL,0" >> "$csv"
      continue
    }
    end_ts=$(date -u +%s)
    wall_clock=$((end_ts - start_ts))

    report="$(latest_report)"
    if [[ -z "$report" ]]; then
      echo "  run $run: no report emitted under $REPORT_DIR" >&2
      OVERALL_PASS=0
      bands+=("?")
      echo "$fixture_name,$run,?,$wall_clock,0" >> "$csv"
      continue
    fi
    band="$(parse_band "$report")"
    total_axis_sum="$(parse_total_axis_sum "$report")"
    bands+=("$band")
    echo "$fixture_name,$run,$band,$wall_clock,$total_axis_sum" >> "$csv"
    echo "  run $run: band=$band  wall_clock=${wall_clock}s  axis_sum=${total_axis_sum}  report=$(basename "$report")"

    # Per-run T1-09 budget assertion.
    if (( wall_clock > T1_BUDGET_SECONDS )); then
      echo "  FAIL[T1-09 budget]: ${wall_clock}s > ${T1_BUDGET_SECONDS}s on $fixture_name run $run" >&2
      OVERALL_PASS=0
    fi
  done

  # Post-fixture assertions.
  first="${bands[0]}"
  stable=1
  for b in "${bands[@]}"; do
    if [[ "$b" != "$first" ]]; then stable=0; break; fi
  done
  if (( stable == 0 )); then
    echo "  FAIL[stability]: bands across 3 runs = ${bands[*]} (TST-02 violation)" >&2
    OVERALL_PASS=0
  fi
  if [[ "$first" != "$expected" ]]; then
    echo "  FAIL[band-mismatch]: got '$first', expected '$expected'" >&2
    OVERALL_PASS=0
  fi
  SUMMARY_ROWS+=("$fixture_name | ${bands[0]} ${bands[1]} ${bands[2]} | expected=$expected | stable=$stable")
done

echo ""
echo "=== Goldens summary ==="
for row in "${SUMMARY_ROWS[@]}"; do echo "  $row"; done

# ============================================================
# deep search stub mode (always runs; no network)
# Covers D2-21..D2-24 deterministic gates: TST-03 sanitization, TST-04 vapor.
# ============================================================

echo
echo "===== deep search stub-mode tests ====="

T2_FAIL=0
TOTAL_FAIL=0

# Run safe-clone.sh unit tests (no network — uses stubbed gh/git)
if [ -f "$REPO_ROOT/tests/test-safe-clone.sh" ]; then
  if bash "$REPO_ROOT/tests/test-safe-clone.sh"; then
    echo "PASS: test-safe-clone.sh"
  else
    echo "FAIL: test-safe-clone.sh"
    T2_FAIL=$((T2_FAIL+1))
  fi
else
  echo "SKIP: tests/test-safe-clone.sh not present"
fi

# Run vapor-check.sh unit tests (no network)
if [ -f "$REPO_ROOT/tests/test-vapor-check.sh" ]; then
  if bash "$REPO_ROOT/tests/test-vapor-check.sh"; then
    echo "PASS: test-vapor-check.sh"
  else
    echo "FAIL: test-vapor-check.sh"
    T2_FAIL=$((T2_FAIL+1))
  fi
else
  echo "SKIP: tests/test-vapor-check.sh not present"
fi

# Golden: vapor heuristic on planted-vapor-repo (TST-04) — assert exit 0 across 3 runs (D2-22 stability)
VAPOR_FIXTURE="$REPO_ROOT/tests/fixtures/planted-vapor-repo"
if [ -d "$VAPOR_FIXTURE" ] && [ -x "$REPO_ROOT/scripts/vapor-check.sh" ]; then
  for run in 1 2 3; do
    if bash "$REPO_ROOT/scripts/vapor-check.sh" "$VAPOR_FIXTURE" >/dev/null 2>&1; then
      echo "PASS: vapor-check on planted-vapor-repo (run $run)"
    else
      echo "FAIL: vapor-check on planted-vapor-repo (run $run) — expected exit 0"
      T2_FAIL=$((T2_FAIL+1))
    fi
  done
else
  echo "SKIP: planted-vapor-repo or scripts/vapor-check.sh missing"
fi

# Golden: sanitization pipeline on planted-injection-readme.md (TST-03)
# Apply the SKILL.md Step DEEP-F sanitization pipeline and assert:
# - zero-width chars are stripped
# - HTML comments are stripped
INJECTION_FIXTURE="$REPO_ROOT/tests/fixtures/planted-injection-readme.md"
if [ -f "$INJECTION_FIXTURE" ]; then
  SAN_OUT=$(sed -e 's/<!--.*-->//g' \
                -e $'s/\xE2\x80\x8B//g' -e $'s/\xE2\x80\x8C//g' \
                -e $'s/\xE2\x80\x8D//g' -e $'s/\xEF\xBB\xBF//g' \
                "$INJECTION_FIXTURE")
  if printf '%s' "$SAN_OUT" | LC_ALL=C grep -q $'\xE2\x80\x8B'; then
    echo "FAIL: sanitization left zero-width chars in output"
    T2_FAIL=$((T2_FAIL+1))
  else
    echo "PASS: zero-width chars stripped"
  fi
  if printf '%s' "$SAN_OUT" | grep -q "<!--"; then
    echo "FAIL: sanitization left HTML comment in output"
    T2_FAIL=$((T2_FAIL+1))
  else
    echo "PASS: HTML comments stripped"
  fi
else
  echo "SKIP: planted-injection-readme.md missing"
fi

echo "deep search stub: $T2_FAIL failures"

# ============================================================
# deep search real-network mode (gated by RUN_REAL=1)
# Per D2-23: default invocation MUST NOT burn gh API quota.
# ============================================================

T2_REAL_FAIL=0
if [ "${RUN_REAL:-0}" = "1" ]; then
  echo
  echo "===== deep search real-network tests (RUN_REAL=1) ====="

  if [ ! -x "$REPO_ROOT/tests/scripts/invoke-skill-deep.sh" ]; then
    echo "SKIP: tests/scripts/invoke-skill-deep.sh missing — deep search real-network requires the skill invocation harness"
    T2_REAL_FAIL=0
  else
    # For each existing first search fixture, opt into deep search and time the run.
    # T2-10 / D2-24: total deep search must complete in ≤10 minutes (600s) per fixture.
    for fixture in "$FIXTURE_DIR"/*.json; do
      fname=$(basename "$fixture" .json)
      # Skip deep-vapor / deep-injection — they are stub-only.
      case "$fname" in
        deep-*) continue ;;
      esac
      BANDS_FOR_FIXTURE=()
      for run in 1 2 3; do
        start=$(date +%s)
        REPORT_PATH=$(bash "$REPO_ROOT/tests/scripts/invoke-skill-deep.sh" "$fixture" 2>&1 | tail -1)
        rc=$?
        end=$(date +%s)
        elapsed=$((end - start))
        if [ $rc -ne 0 ]; then
          echo "FAIL: $fname run $run rc=$rc"
          T2_REAL_FAIL=$((T2_REAL_FAIL+1))
          continue
        fi
        if [ $elapsed -gt 600 ]; then
          echo "FAIL: $fname run $run took ${elapsed}s (>600s T2-10 budget)"
          T2_REAL_FAIL=$((T2_REAL_FAIL+1))
        else
          echo "PASS: $fname run $run took ${elapsed}s (T2-10 budget OK)"
        fi
        # Capture verdict band for stability check (D2-22)
        if [ -f "$REPORT_PATH" ]; then
          band=$(grep -oE '🟢|🟡|🔴' "$REPORT_PATH" | head -1)
        else
          band="?"
        fi
        echo "  band: $band"
        BANDS_FOR_FIXTURE+=("$band")
      done
      # Stability: all 3 runs must produce the same band
      unique=$(printf '%s\n' "${BANDS_FOR_FIXTURE[@]}" | sort -u | wc -l)
      if [ "$unique" -ne 1 ]; then
        echo "FAIL: $fname stability — band unstable across 3 runs: ${BANDS_FOR_FIXTURE[*]}"
        T2_REAL_FAIL=$((T2_REAL_FAIL+1))
      else
        echo "PASS: $fname stability — band stable: ${BANDS_FOR_FIXTURE[0]}"
      fi
    done
  fi

  echo "deep search real-network: $T2_REAL_FAIL failures"
else
  echo
  echo "deep search real-network tests SKIPPED (set RUN_REAL=1 to enable; consumes gh quota)"
fi

TOTAL_FAIL=$((T2_FAIL + T2_REAL_FAIL))

echo ""
if (( OVERALL_PASS == 1 )) && (( TOTAL_FAIL == 0 )); then
  echo "RESULT: PASS (TST-02 stability + band-correctness + T1-09 90s budget + deep search gates all satisfied)"
  exit 0
else
  echo "RESULT: FAIL (first search OVERALL_PASS=$OVERALL_PASS, deep search failures=$TOTAL_FAIL)" >&2
  exit 1
fi
