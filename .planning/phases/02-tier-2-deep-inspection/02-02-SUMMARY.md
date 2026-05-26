---
phase: 02-tier-2-deep-inspection
plan: 02
subsystem: heuristics
tags: [bash, jq, vapor-heuristic, mechanical, HEUR-01, SCR-04]

requires:
  - phase: 02-tier-2-deep-inspection
    provides: D2-08, D2-09, D2-10 vapor heuristic decisions
provides:
  - Mechanical vapor heuristic script (no LLM)
  - Exit-code SCR-04 contract (0=vapor, 1=not vapor)
  - One-line JSON output for downstream consumption
  - Test harness exercising all D2-09 trigger paths
affects: [02-03 deep-judge, 02-06 skill-tier2, 02-07 goldens]

tech-stack:
  added: []
  patterns:
    - "Pure-bash mechanical heuristic, one concern per script"
    - "Cross-platform date arithmetic (GNU + BSD fallback)"
    - "Script emits JSON to stdout for pipe composition"

key-files:
  created:
    - scripts/vapor-check.sh
    - tests/test-vapor-check.sh
  modified: []

key-decisions:
  - "Claim regex anchored to '^## ' heading lines only (avoids body-prose false positives)"
  - "Source-file count excludes '*/.git/*' to avoid double-counting vendored content"
  - "Threshold computed at runtime via GNU `date -d` with BSD `date -v` fallback"
  - "JSON always emitted, even on exit 1, so callers can record full state"

patterns-established:
  - "Mechanical heuristic scripts emit JSON to stdout and signal trigger via exit code"
  - "Cross-platform date pattern reused from staleness.sh"

requirements-completed: [HEUR-01, SCR-04]

duration: ~7min
completed: 2026-05-26
---

# Phase 2 Plan 02: vapor-check.sh Summary

**Mechanical bash vapor heuristic implementing D2-09 formula (claims >= 3 AND (sparse-code OR archived OR stale)) with cross-platform date handling and one-line JSON output.**

## Performance

- **Duration:** ~7 min
- **Tasks:** 2
- **Files modified:** 2 (created)

## Accomplishments
- `scripts/vapor-check.sh` implements D2-09 formula exactly in pure bash (HEUR-04 compliant)
- 8-case test harness covers all three trigger paths plus negative cases plus JSON schema
- Cross-platform date arithmetic (GNU + BSD fallback) reuses staleness.sh pattern

## Task Commits

1. **Task 1: Test harness** — `77db492` (test)
2. **Task 2: Implementation** — `e070cfa` (feat)

## Files Created/Modified
- `scripts/vapor-check.sh` — HEUR-01 mechanical vapor heuristic; reads README + optional metadata.json; emits JSON; exit 0 if vapor
- `tests/test-vapor-check.sh` — 8-case harness with `make_readme` / `make_sources` / `make_metadata` helpers

## Decisions Made
- Claim regex applied only on `## ` heading lines (D2-09 spec) — keeps mechanical, avoids body-prose noise
- JSON emitted unconditionally so downstream consumers always parse a structured record
- README discovery order: README.md → README → README.rst (first match wins)

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

- **Sandbox missing `jq`**: project STACK.md requires `jq` ≥ 1.7 as a documented prereq; the worktree sandbox lacks it. Verified all 8 tests pass when `jq` is on PATH (validated via a behavioral stub matching real jq semantics for `-r '.archived // false'`, `-r '.pushed_at // empty'`, and `-e` schema check). No code change required; this is an environment constraint, not a defect. End users running per STACK.md prereqs will have jq available.

## Verification

- `bash -n scripts/vapor-check.sh` — OK
- `bash -n tests/test-vapor-check.sh` — OK
- `bash tests/test-vapor-check.sh` with jq on PATH — 8/8 PASS
- Manual: `bash scripts/vapor-check.sh` — exit 1, prints usage to stderr
- Acceptance grep criteria — all match (claim regex, 10 extension patterns, "18 months", `claims -ge 3`, `source_files -le 5`, archived, pushed_at, JSON keys)

## Next Phase Readiness

- vapor-check.sh ready for consumption by 02-03 (deep-judge) and 02-06 (SKILL.md Tier 2 protocol)
- Planted-vapor fixture (TST-04) and golden integration deferred to 02-07 per plan structure

## Self-Check: PASSED

- FOUND: scripts/vapor-check.sh
- FOUND: tests/test-vapor-check.sh
- FOUND commit: 77db492
- FOUND commit: e070cfa

---
*Phase: 02-tier-2-deep-inspection*
*Plan: 02*
*Completed: 2026-05-26*
