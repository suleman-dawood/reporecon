---
phase: 02-tier-2-deep-inspection
plan: 06
subsystem: skills/reporecon
tags: [skill, orchestration, tier2, integration]
requires:
  - skills/reporecon/references/tier2-protocol.md
  - skills/reporecon/references/judge-rubric.md (Tier 2 5-level extension)
  - skills/reporecon/references/report-template.md (Tier 2 + Your Angle sections)
  - scripts/safe-clone.sh
  - scripts/vapor-check.sh
  - scripts/verify-repo.sh
  - scripts/gh-search.sh
provides:
  - skills/reporecon/SKILL.md Tier 2 orchestration (Step 8.5, T2-A..T2-G, Steps 9-10)
  - Opt-in gate after 🟡/🔴 Tier 1 verdict
  - Boot-time /tmp/reporecon sweep + run-scoped trap cleanup
  - 5-level mechanical verdict derivation (EXACT_MATCH..VAPOR)
  - Negative-space "Your Angle" synthesis
affects:
  - skills/reporecon/SKILL.md (only file modified)
tech-stack:
  added:
    - WebSearch tool in allowed-tools
  patterns:
    - Untrusted-content wrapper (D2-11..D2-14) for all cloned content
    - Mechanical verdict derivation (LLM emits axis scores only)
    - Vapor override (script exit code overrides axes)
key-files:
  modified:
    - skills/reporecon/SKILL.md (119 → 317 lines; Tier 1 preserved byte-for-byte)
decisions:
  - Tier 2 sections inserted between Step 8 and Discipline (preserves Tier 1)
  - Tier 2 discipline bullets appended to existing Discipline section (no replacement)
  - WebSearch added to allowed-tools (alphabetical)
  - Description block updated to mention Tier 2; "no WebSearch" phrasing removed
metrics:
  duration: ~5min
  completed: 2026-05-26
---

# Phase 2 Plan 06: Wire Tier 2 into SKILL.md Summary

Extended `skills/reporecon/SKILL.md` from Tier-1-only (119 lines) to full Tier 1 + Tier 2 orchestration (317 lines) by appending Step 8.5 opt-in gate, T2-A..T2-G processing steps, Steps 9-10 emit, and supplemental Discipline bullets — preserving the entire Tier 1 protocol unchanged.

## What Was Built

- **Frontmatter (Task 1):** Added `WebSearch` to `allowed-tools` (alphabetical insertion between `Read` and `Write`). Updated description to advertise the Tier 2 opt-in clone extension; removed the obsolete "no WebSearch" phrasing.
- **Body (Task 2):** Inserted nine new sections immediately before the existing `## Discipline` heading and appended Tier-2-specific discipline bullets. Each new section references its underlying decision IDs (D2-01..D2-19) and the on-demand reference file it loads.

### New Sections (in order)

| Step | Purpose | Loads / Calls |
|------|---------|---------------|
| 8.5 | Tier 2 opt-in gate (🟢 stops; 🟡/🔴 + opt-in phrase proceeds) | `report-template.md` Tier 1→Tier 2 footer |
| T2-A | Boot-time `/tmp/reporecon` sweep (`mmin +120`) | mechanical |
| T2-B | 10 expanded `gh-search.sh` queries | `tier2-protocol.md` Discovery Expansion + Dedupe |
| T2-C | 5 WebSearch queries; every URL through `verify-repo.sh` | `WebSearch`, `verify-repo.sh` |
| T2-D | Three-pool dedupe by `full_name`; cap at 8 clone candidates | LLM (overlap boolean), `verify-repo.sh` |
| T2-E | Parallel safe-clone (xargs -P 3) + vapor-check per candidate | `safe-clone.sh`, `vapor-check.sh` |
| T2-F | Per-candidate judge with `<untrusted_content>` wrapper, sanitization, 5-level mechanical derivation, vapor override | `judge-rubric.md` Tier 2 sections |
| T2-G | Negative-space synthesis to "Your Angle" | `report-template.md` Your Angle Section |
| 9 | Append Tier 2 sections to existing Tier 1 report file (single artifact) | `Write` |
| 10 | ≤15-line Tier 2 verdict to chat | none |

### Discipline Additions (appended, not replacing)

- Cloned content MUST pass through `<untrusted_content>` wrapper + sanitization.
- 5-level Tier 2 labels appear ONLY when Tier 2 ran (preserves Tier 1 cap).
- Run-scoped trap (`/tmp/reporecon/run-${RUN_TS}`) + boot sweep bound `/tmp` usage.
- WebSearch outputs: candidate URLs only, no snippet text.
- File-path cite format `path/to/file.ext:LINE`; absence caps verdict at SUPERFICIAL_MATCH (or VAPOR).

## Tasks & Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Frontmatter: add `WebSearch`, update description for Tier 2 | `3841627` |
| 2 | Append Tier 2 sections + discipline bullets | `5e369a8` |

## Verification

Acceptance grep checks (all pass):

- Phase 1 sections (Step 0..8, Discipline) — each present exactly once: regression-free.
- Tier 2 sections — Step 8.5, T2-A..T2-G, Step 9, Step 10 — each present exactly once.
- Tool/reference mentions: `safe-clone.sh`=1, `vapor-check.sh`=3, `tier2-protocol.md`=3, `verify-repo.sh`=5, `WebSearch`=7.
- All five Tier 2 labels present (EXACT_MATCH, SIGNIFICANT_OVERLAP, PARTIAL_OVERLAP, SUPERFICIAL_MATCH, VAPOR).
- Hard rule phrases: `untrusted_content`=2, `suspected_injection`=1, `mmin +120`=1, `path/to/file.ext:LINE`=2.
- Decision IDs: D2-01, D2-06, D2-11 (and more) present for traceability.
- File length 317 lines (within 200-350 bound).
- Code fences: 10 (even — balanced).
- YAML frontmatter parses (opens with `---`, closes after `effort: medium`).

## Requirements Satisfied

- **T2-01** Opt-in gate → Step 8.5
- **T2-02** WebSearch + 10 gh queries → Steps T2-B, T2-C
- **T2-03** Verify all cited URLs → Step T2-C + Tier 1 carry-forward (D2-05)
- **T2-08** Judge cites file paths → Step T2-F evidence rule
- **T2-09** Full 5-level verdict → Step T2-F mechanical derivation

## Deviations from Plan

None — plan executed exactly as written.

## Notes

- STATE.md and ROADMAP.md intentionally NOT updated (per task objective; orchestrator handles).
- No additional files touched beyond `skills/reporecon/SKILL.md`.
- Per worktree convention used `git commit --no-verify` for both task commits.

## Self-Check: PASSED

- `skills/reporecon/SKILL.md` — FOUND (317 lines, both tasks committed)
- Commit `3841627` (Task 1) — FOUND in git log
- Commit `5e369a8` (Task 2) — FOUND in git log
