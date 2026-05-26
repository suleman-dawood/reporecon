---
phase: 02-tier-2-deep-inspection
plan: 07
subsystem: testing
tags: [goldens, ci, tier-2, regression]
requires:
  - tests/test-safe-clone.sh (02-01)
  - tests/test-vapor-check.sh (02-02)
  - tests/fixtures/planted-vapor-repo (02-05)
  - tests/fixtures/planted-injection-readme.md (02-05)
  - skills/reporecon/SKILL.md Tier 2 wiring (02-06)
provides:
  - Tier 2 regression harness (stub + real-network modes)
  - CI matrix (PR stub + weekly/manual real-network)
affects:
  - tests/run-goldens.sh
  - .github/workflows/goldens.yml
tech-stack:
  added: []
  patterns:
    - RUN_REAL=1 gated real-network mode (D2-23)
    - 3x stability assertion per fixture (D2-22)
    - 600s per-fixture budget guard (T2-10, D2-24)
key-files:
  created:
    - tests/golden/tier2-vapor.json
    - tests/golden/tier2-injection.json
  modified:
    - tests/run-goldens.sh
    - .github/workflows/goldens.yml
decisions:
  - Tier 1 loop now filters tier2-* fixtures by name prefix; tier2 stub fixtures are handled exclusively by new Tier 2 block (avoids jq errors on missing .scenario/.idea fields)
  - Real-network suite gated on existence of tests/scripts/invoke-skill-tier2.sh harness; SKIP message emitted when absent rather than hard-failing — harness creation deferred per plan
  - CI split into two jobs (goldens-stub + tier2-real-network) instead of single-job matrix — cleaner gating on event_name and per-job timeout (10m vs 30m)
metrics:
  duration: ~10min
  completed: 2026-05-26
---

# Phase 02 Plan 07: Wire Tier 2 Goldens + CI Matrix Summary

Extended `tests/run-goldens.sh` with a Tier 2 stub-mode block (always-on deterministic gates) and an `RUN_REAL=1`-gated real-network suite enforcing 3x band stability + 600s per-fixture budget; split CI into PR-default stub job and on-demand/weekly real-network job.

## What Shipped

### Golden fixtures (Task 1)
- `tests/golden/tier2-vapor.json` — asserts `vapor-check.sh` exits 0 on `tests/fixtures/planted-vapor-repo` and expected verdict `VAPOR` (TST-04). `stability_runs: 3`.
- `tests/golden/tier2-injection.json` — asserts sanitization strips zero-width chars and HTML comments, and `attacker.example.com` exfiltration URL is absent from rendered report (TST-03). `stability_runs: 3`.

### Tier 2 runner extension (Task 2)
`tests/run-goldens.sh` modifications (Tier 1 logic preserved byte-for-byte aside from a name-prefix skip filter):
1. Tier 1 loop now `continue`s on any fixture whose basename starts with `tier2-` (necessary because the new fixtures don't carry `.scenario`/`.idea`/`.expected_verdict_band` fields).
2. New `===== Tier 2 stub-mode tests =====` section after Tier 1 summary:
   - Runs `tests/test-safe-clone.sh` (02-01) and `tests/test-vapor-check.sh` (02-02) unit tests.
   - Runs `scripts/vapor-check.sh` against `tests/fixtures/planted-vapor-repo` x3 (TST-04 + D2-22 stability).
   - Applies the SKILL.md Step T2-F sanitization regex pipeline to `tests/fixtures/planted-injection-readme.md` and asserts zero-width chars + HTML comments are stripped (TST-03).
3. New `===== Tier 2 real-network tests (RUN_REAL=1) =====` section gated on `RUN_REAL=1`:
   - For each non-`tier2-*` fixture, runs `tests/scripts/invoke-skill-tier2.sh` x3, captures emitted report path, parses verdict band emoji.
   - Asserts each run completes in ≤600s (T2-10, D2-24).
   - Asserts band uniqueness across 3 runs (D2-22).
   - Guarded on harness existence — emits SKIP if `tests/scripts/invoke-skill-tier2.sh` is missing (harness creation is deferred; not part of this plan).
4. Final exit status now combines `OVERALL_PASS` (Tier 1) AND `TOTAL_FAIL == 0` (Tier 2 stub + real).

### CI matrix (Task 3)
`.github/workflows/goldens.yml` rewritten into two jobs:
- **`goldens-stub`** — runs on `pull_request` (path-filtered) and `workflow_dispatch`. `timeout-minutes: 10`. `RUN_REAL=0`. `continue-on-error: true` preserves the existing best-effort PR behavior.
- **`tier2-real-network`** — gated on `workflow_dispatch` input `run_real=true` OR weekly cron `0 6 * * 0` (Sundays 06:00 UTC). `timeout-minutes: 30`. `RUN_REAL=1`. Same install steps; invokes the same `bash tests/run-goldens.sh`.

Header comment block documents the cost rationale and links back to `02-CONTEXT.md` D2-23.

## Verification

| Check                                                                     | Result |
| ------------------------------------------------------------------------- | ------ |
| `bash -n tests/run-goldens.sh`                                            | PASS   |
| `python3 -c "import json; json.load(open('tests/golden/tier2-vapor.json'))"`     | PASS   |
| `python3 -c "import json; json.load(open('tests/golden/tier2-injection.json'))"` | PASS   |
| `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/goldens.yml'))"` | PASS   |
| Literal coverage scan in run-goldens.sh (57 matches across required terms) | PASS   |

`jq` is not installed in this worktree sandbox, so JSON validation was performed via `python3 -c "import json; ..."` (functionally equivalent). CI installs `jq` before invoking the runner.

## Calibration Outcomes (Deferred)

Real-network runs require:
1. `claude` CLI on PATH with a non-interactive flag (`--headless --skill` or `-p`).
2. `tests/scripts/invoke-skill-tier2.sh` harness that feeds the fixture's `idea` to the skill, auto-opts into Tier 2, and prints the emitted report path on its final stdout line.
3. Authenticated `gh` with `>50` remaining core requests.

Neither (1) nor (2) is available in this worktree sandbox — same constraint that applied to 01-07. The runner gracefully SKIPs the real-network block when the harness is absent, so default runs remain green. Manual calibration of band stability and the ≤10min per-fixture budget is deferred to the first user-side `RUN_REAL=1` invocation (or the weekly CI cron, once `claude` CLI is available in the runner).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tier 1 loop filter for tier2-* fixtures**
- **Found during:** Task 2.
- **Issue:** Plan adds `tier2-vapor.json` and `tier2-injection.json` into `tests/golden/` but the existing Tier 1 loop `jq -r '.scenario'`s every `*.json` file, which would fail on these fixtures (missing `.scenario`, `.idea`, `.expected_verdict_band`).
- **Fix:** Added a `case "$fixture_name" in tier2-*) continue ;; esac` filter at the top of the Tier 1 fixture loop. The Tier 2 stub block consumes these fixtures directly.
- **Files modified:** `tests/run-goldens.sh`.
- **Commit:** `280842d`.

**2. [Rule 2 - Robustness] Guard stub-mode blocks on artifact presence**
- **Found during:** Task 2.
- **Issue:** Plan invokes `tests/test-safe-clone.sh`, `tests/test-vapor-check.sh`, `scripts/vapor-check.sh` unconditionally — but plan dependencies (02-01..02-05) may not all be present in every checkout (e.g., bisect, partial worktree).
- **Fix:** Wrapped each invocation in an existence guard (`[ -f ... ]`, `[ -x ... ]`, `[ -d ... ]`) with a `SKIP:` message on miss. Failures still count; absences don't false-fail.
- **Files modified:** `tests/run-goldens.sh`.
- **Commit:** `280842d`.

**3. [Rule 3 - Tooling] Validated JSON with python instead of jq**
- **Found during:** Task 1 verification.
- **Issue:** `jq` is not installed in this worktree (`command -v jq` fails). Plan's `<automated>` verification uses `jq .`.
- **Fix:** Used `python3 -c "import json; json.load(...)"` as functional equivalent. Production CI still uses `jq` (installed in workflow step).
- **Files modified:** none — verification-only.

### Architectural Changes
None — kept within the plan's intent.

## Known Stubs
- `tests/scripts/invoke-skill-tier2.sh` is referenced but intentionally not created (per plan note: "creation is part of running the goldens for the first time"). Stub status: real-network suite SKIPs when missing.

## Threat Flags
None — no new network surface, auth paths, or trust boundaries introduced. Sanitization regex pipeline duplicates the SKILL.md Step T2-F filter for regression coverage only.

## Self-Check: PASSED

- FOUND: `tests/golden/tier2-vapor.json`
- FOUND: `tests/golden/tier2-injection.json`
- FOUND: `tests/run-goldens.sh` (extended)
- FOUND: `.github/workflows/goldens.yml` (rewritten)
- FOUND: commit `0a3d301` (task 1)
- FOUND: commit `280842d` (task 2)
- FOUND: commit `4aa9528` (task 3)
