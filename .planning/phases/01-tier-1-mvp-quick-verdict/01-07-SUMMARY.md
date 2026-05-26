---
phase: 01-tier-1-mvp-quick-verdict
plan: 07
subsystem: testing
tags: [tst-02, t1-09, jdg-05, jdg-06, ship-gate, goldens, calibration]
requires: [01-01, 01-02, 01-03, 01-04, 01-05, 01-06]
provides: [tier-1-ship-gate-runner, deferred-validation-doc]
affects: [tests/run-goldens.sh, .planning/phases/01-tier-1-mvp-quick-verdict/01-07-GOLDEN-RESULTS.md]
tech-stack:
  added: []
  patterns: [auto-detect-cli-mode, csv-per-fixture-results, fail-fast-on-stale-deps]
key-files:
  created:
    - .planning/phases/01-tier-1-mvp-quick-verdict/01-07-GOLDEN-RESULTS.md
  modified:
    - tests/run-goldens.sh
decisions:
  - "Runner exits 2 (caller-fixable) on stale gh/missing jq rather than running with broken deps — false-green CI is worse than no CI."
  - "Empirical 9-cell run deferred to user-side host: gh OAuth + gh>=2.55 + jq>=1.7 cannot be bootstrapped from inside a worktree without authority outside this plan."
  - "Auto-detect claude headless invocation via --help parsing (supports --headless --skill OR -p '/reporecon')."
  - "Per-fixture CSV under tests/.goldens-results/ — stable artifact for Phase 2 drift detection."
metrics:
  duration_minutes: ~12
  tasks_completed: 2
  files_changed: 2
  commits: 2
  completed_date: 2026-05-26
---

# Phase 1 Plan 07: Ship-Gate Validation Summary

**One-liner:** Wired `tests/run-goldens.sh` to enforce TST-02 (3-run band stability) and T1-09 (90s budget) across the 3 golden fixtures; the empirical 9-cell run is deferred to a user-side host that satisfies the `gh >= 2.55` + `jq` + `gh auth` prerequisites the worktree environment cannot provide.

## What shipped

1. **`tests/run-goldens.sh`** — fully wired (218 lines, replacing the 56-line Plan 05 TODO scaffold):
   - Auto-detects `claude` non-interactive invocation mode (`--headless --skill reporecon` OR `-p '/reporecon <idea>'`) by parsing `claude --help`.
   - For each fixture × 3 runs: invokes the skill, locates latest report under `./reporecon-reports/`, parses verdict-band emoji from the H1 line, parses every `axis_sum: <N>` line for a total, records wall-clock seconds.
   - Three assertions per fixture: stability (all 3 bands identical), correctness (band == `expected_verdict_band`), budget (every run ≤ 90s).
   - Exit 0 iff all 9 cells pass all 3 checks. Exits 2 (caller-fixable) on missing/stale deps to prevent false-green runs.
   - Per-fixture CSV outputs under `tests/.goldens-results/<fixture>.csv`.
   - Header comment block documents this is the TST-02 ship gate, 90s budget is T1-09, and the calibration order if any fixture fails.

2. **`.planning/phases/01-tier-1-mvp-quick-verdict/01-07-GOLDEN-RESULTS.md`** — empirical results doc:
   - 9-cell table left as template (TBD per cell) for user-side population.
   - Documents *why* the executor agent could not run it (jq missing, gh 2.4.0 < 2.55 in the worktree host).
   - Lists user-side prerequisites + exact install/verify commands per OS.
   - Preserves the calibration tuning priority order (re-judge phrasing → trigger threshold → query archetype → threshold table → wall-clock knobs).
   - Resolutions table: Open Q1/Q4 and Assumptions A6/A7 marked "deferred — user-side run resolves".
   - Phase 1 ship gate status: **PASS-pending-user-side-run**.

## 9-cell results table

Not yet populated. See `01-07-GOLDEN-RESULTS.md` for the table template, the
expected band per fixture (todo-cli=🔴, obscure-niche=🟢, llm-eval-dashboard=🟡),
and the exact one-line command the user runs to populate it
(`bash tests/run-goldens.sh`).

## Tunings applied

**None.** The references shipped in Wave 1 (`query-patterns.md`,
`judge-rubric.md`, `report-template.md`) and the SKILL.md from Wave 2 stand
unchanged. The tuning loop is deferred to user-side execution; the runner
header documents the priority order so a future continuation agent (or the
user) can apply it without re-deriving it.

## Resolutions for Open Questions / Assumptions

| ID                       | Status                                                            |
|--------------------------|-------------------------------------------------------------------|
| OQ-1 (re-judge phrasing) | **Deferred** — empirical 3-run obscure-niche stability will choose. |
| OQ-4 (band stability)    | **Deferred** — TST-02 gate is the runner's exact contract.        |
| A6 (devil's-advocate trigger threshold) | **Held** pending user-side empirical confirmation.   |
| A7 (90s wall-clock budget) | **Held** pending user-side empirical confirmation.              |

## Phase 1 ship-gate status

**PASS-pending-user-side-run.** The harness contract is locked: any
regression in band stability, band correctness, or 90s budget will surface as
a non-zero exit from `bash tests/run-goldens.sh` on a properly provisioned
host. The remaining empirical confirmation requires `gh auth login` + current
`gh`/`jq` versions that are user-environment concerns, not plan-execution
concerns.

## Handoff notes for Phase 2

- The `llm-eval-dashboard` fixture (🟡 ambiguous) is the canonical "user
  wants Tier 2" trigger; preserve it as a Phase 2 regression fixture too.
- The runner's CSV outputs (`tests/.goldens-results/*.csv`) are the right
  artifact for Phase 2 to drift-detect Tier 2's verdict band against Tier 1.
- If Phase 2 introduces a `--tier2` invocation, the runner's
  `invoke_skill()` function is the right extension point (add a fourth
  detection mode rather than a parallel runner).
- The fail-fast preflight (exit 2 on stale deps) keeps CI honest — Phase 2
  should preserve it when adding clone + WebSearch budget checks.

## Deviations from Plan

### Auto-fixed Issues
None. The plan's Task 2 anticipated this exact contingency in its
acceptance-criteria language ("commit each tuning as a separate commit") and
the user's auto-mode prompt pre-approved the deferred-validation path when
the worktree lacks prerequisites.

### Scope-faithful adjustment
- **Task 2:** Plan asked for the empirical 9-cell run. Executed the documented
  fallback (per the user's pre-approval block in the prompt): wrote
  `01-07-GOLDEN-RESULTS.md` documenting prerequisites + user-side run
  procedure instead of fabricating golden numbers. **No tunings applied** —
  applying tunings without empirical data would couple Tier 1 to the goldens
  rather than to the real world.

### Auth gates
None. `gh auth status` reports the worktree is authed (`suleman-dawood`),
but `gh 2.4.0` and missing `jq` are deps-not-auth; user must install/upgrade.

## Commits

| Hash    | Type | Description                                                                          |
|---------|------|--------------------------------------------------------------------------------------|
| edbc3df | feat | wire run-goldens.sh — 3-run band-stability + 90s budget assertions                   |
| 0f0733c | docs | document ship-gate deferred to user-machine validation                               |

## Self-Check: PASSED

- `tests/run-goldens.sh` exists, executable, `bash -n` passes — verified.
- All Task 1 `<automated>` checks pass: contains `stability`, contains `expected_verdict_band`, contains `90`, no `TODO Plan 07` marker remains.
- `.planning/phases/01-tier-1-mvp-quick-verdict/01-07-GOLDEN-RESULTS.md` exists with "PASS" status and 9-cell template.
- Commits `edbc3df` and `0f0733c` exist in `git log`.
- The plan's Task 2 `<automated>` block (`bash tests/run-goldens.sh` must exit 0) cannot pass on the worktree host — this is documented as deferred per the user's pre-approval, not as a hidden failure.
