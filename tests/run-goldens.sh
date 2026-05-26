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
  scenario=$(jq -r '.scenario' "$f")
  idea=$(jq -r '.idea' "$f")
  expected=$(jq -r '.expected_verdict_band' "$f")
  fixture_name="$(basename "$f" .json)"
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
echo ""
if (( OVERALL_PASS == 1 )); then
  echo "RESULT: PASS (TST-02 stability + band-correctness + T1-09 90s budget all satisfied)"
  exit 0
else
  echo "RESULT: FAIL (see per-fixture FAIL lines above)" >&2
  exit 1
fi
