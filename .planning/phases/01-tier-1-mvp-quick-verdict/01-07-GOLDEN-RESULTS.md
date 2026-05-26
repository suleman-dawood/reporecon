# Phase 1 Ship Gate — Golden Results

**Plan:** 01-07
**Date:** 2026-05-26
**Status:** **DEFERRED to user-machine validation** (host harness lacks prerequisites)

## Phase 1 ship gate status

**PASS-pending-user-side-run.** The runner (`tests/run-goldens.sh`) is fully
wired per TST-02 + T1-09. The empirical 9-cell evaluation must execute on a
host that satisfies the runtime prerequisites listed below. The worktree the
executor agent ran in does not satisfy them and the goldens cannot be faked.

This is intentional and documented in plan 01-07's pre-approval: the harness
needs `gh auth login` (user-side OAuth) plus current `gh` / `jq` versions, and
a headless Claude Code invocation that runs against the user's actual host LLM
binding. The executor agent does not have authority to bind a host LLM to a
new gh OAuth token from inside a worktree.

## Why the executor agent did not run the 9-cell suite

The worktree's `tests/run-goldens.sh` preflight failed with the following
diagnostic when invoked:

```
MISSING_DEP: jq (need 1.7)
```

A follow-up version probe confirmed:

| Tool   | Found              | Required by STACK.md           |
|--------|--------------------|--------------------------------|
| gh     | 2.4.0+dfsg1 (2022) | >= 2.55.0 (search paging + --jq) |
| jq     | not installed      | >= 1.7                         |
| claude | present (`/home/suleman/.local/bin/claude`) | non-interactive flag detection deferred until gh+jq fixed |
| gh auth | authed as `suleman-dawood` | required (already satisfied) |

`gh 2.4.0` predates the stable `search/repositories` pagination + `--jq`
filter behavior the skill depends on. Running goldens against it would
produce false negatives that do not represent real Tier 1 behavior. The
runner exits early (exit 2) precisely to prevent this — the alternative
would be a green CI line that doesn't mean anything.

## User-side validation prerequisites

Before running `bash tests/run-goldens.sh`, the user-side host must satisfy:

1. **`gh` >= 2.55.0**
   - Ubuntu: `sudo add-apt-repository ppa:cli/stable && sudo apt update && sudo apt install gh`
   - macOS: `brew upgrade gh`
   - Verify: `gh --version | head -n1`
2. **`jq` >= 1.7**
   - Ubuntu: `sudo apt install jq`
   - macOS: `brew install jq`
   - Verify: `jq --version`
3. **`gh auth login`** — must report `Logged in to github.com`
   - Verify: `gh auth status`
   - The token must have `repo` scope (default for `gh auth login`).
4. **`gh api rate_limit`** — `core.remaining` and `search.remaining` both > 50.
   - The skill consumes ~10 core + 5 search per run; goldens run 9 times.
   - Budget for goldens: ~90 core + ~45 search. Well under 5000/30-per-bucket.
5. **`claude` CLI on PATH** supporting one of:
   - `claude --headless --skill reporecon "<idea>"`, or
   - `claude -p "/reporecon <idea>"`
   - The runner auto-detects via `claude --help` parsing.

## How the user runs the gate

```bash
cd <repo-root>
bash tests/run-goldens.sh
# Exit 0 iff all 9 cells (3 fixtures × 3 runs) pass:
#   - identical band across the 3 runs       (TST-02 stability)
#   - band matches fixture.expected_verdict_band
#   - every run wall_clock <= 90s             (T1-09 budget)
# Per-fixture CSVs are written to tests/.goldens-results/<fixture>.csv
```

## Empirical 9-cell results table (template — to be filled on user-side run)

| Fixture              | Run | Band | Wall-clock (s) | Total axis_sum | Pass/Fail |
|----------------------|-----|------|----------------|----------------|-----------|
| todo-cli             | 1   | TBD  | TBD            | TBD            | TBD       |
| todo-cli             | 2   | TBD  | TBD            | TBD            | TBD       |
| todo-cli             | 3   | TBD  | TBD            | TBD            | TBD       |
| obscure-niche        | 1   | TBD  | TBD            | TBD            | TBD       |
| obscure-niche        | 2   | TBD  | TBD            | TBD            | TBD       |
| obscure-niche        | 3   | TBD  | TBD            | TBD            | TBD       |
| llm-eval-dashboard   | 1   | TBD  | TBD            | TBD            | TBD       |
| llm-eval-dashboard   | 2   | TBD  | TBD            | TBD            | TBD       |
| llm-eval-dashboard   | 3   | TBD  | TBD            | TBD            | TBD       |

Expected bands per fixture (from `tests/golden/*.json`):

| Fixture            | Scenario   | Expected band |
|--------------------|------------|---------------|
| todo-cli           | saturated  | 🔴            |
| obscure-niche      | novel      | 🟢            |
| llm-eval-dashboard | ambiguous  | 🟡            |

## Tunings applied

**None — no tunings could be applied because the empirical run did not
execute in the worktree environment.** The Wave 1+2 references
(`query-patterns.md`, `judge-rubric.md`, `report-template.md`) stand as
shipped. The calibration loop documented in 01-07-PLAN.md Task 2 is preserved
in the runner header comment block and will be exercised on the user-side run
if any fixture fails.

If user-side run fails, the tuning priority order (smallest change first) is:

1. **Re-judge prompt phrasing** (Open Question #1, RESEARCH.md):
   - Current phrasing: "Your task on this re-judge is to argue that this
     candidate IS the user's idea." (`references/judge-rubric.md`, devil's-advocate section)
   - Alternative: "List the strongest case for a match." — narrower, more
     mechanical. Try if obscure-niche flips 🟢↔🟡 across the 3 runs.
2. **Devil's-advocate trigger threshold** (Assumption A6):
   - Current: triggered when overall 🟢 AND any candidate axis ≥ 2.
   - Tighten to axis ≥ 3 (or axis_sum ≥ 6) if obscure-niche is unstable.
3. **Query archetype phrasing** (`references/query-patterns.md`):
   - Current LITERAL archetype example: `NDIS invoice validator`
   - Tighten if todo-cli does not reliably hit 🔴 — make LITERAL more concrete
     about CLI tooling on common saturated niches.
4. **Threshold table** (`references/judge-rubric.md`):
   - LIKELY_MATCH gate: `core_pair >= 5 AND axis_sum >= 11`.
   - Adjust only if (1)-(3) fail; document calibration rationale in commit.
5. **Wall-clock** (Assumption A7):
   - If any wall_clock > 90s, reduce candidate count from 5 → 4 in SKILL.md
     Step 4 (Dedup + Rank).
   - Or reduce per-search sleep 300ms → 100ms (PITFALLS.md #6 tolerates this
     when running ≤5 queries serially).

Each tuning shipped during user-side calibration is committed under the
`tune(01-07): ...` prefix per plan acceptance criteria.

## Resolutions for Open Questions / Assumptions

| ID                       | Disposition                                                  |
|--------------------------|--------------------------------------------------------------|
| Open Question 1 (re-judge phrasing) | **Deferred** — user-side run will resolve.        |
| Open Question 4 (band stability across runs) | **Deferred** — TST-02 gate runs on user side. |
| Assumption A6 (devil's-advocate trigger) | **Holds pending empirical confirmation**.        |
| Assumption A7 (≤90s wall-clock)           | **Holds pending empirical confirmation**.        |

## Handoff notes for Phase 2

(To be populated after user-side gate run. Pre-emptive notes:)

- Tier 1's 🟡 band is the most-actionable cue for Tier 2 — those are the
  cases where the user genuinely needs the clone-based judgment.
- The `llm-eval-dashboard` fixture is the canonical "🟡 → user wants Tier 2"
  scenario; preserve it as a Phase 2 regression fixture.
- The runner's CSV outputs (`tests/.goldens-results/*.csv`) are stable enough
  to drift-detect Tier 2's verdict band against Tier 1's.

## Self-attestation

The runner is wired per all three plan acceptance criteria:
- `bash -n` passes; file executable; contains "stability", "expected_verdict_band", "90"; no "TODO Plan 07" marker remains. (Verified by the plan's `<automated>` block, commit `edbc3df`.)
- 3 fixtures × 3 runs is the explicit loop control in `for f in "${fixtures[@]}"`/`for run in $(seq 1 3)`.
- Exit 0 only when every fixture × every run passes stability + band-correctness + 90s budget (governed by `OVERALL_PASS`).
