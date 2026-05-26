---
phase: 02-tier-2-deep-inspection
plan: 04
subsystem: judge-rubric + report-template
tags: [tier2, rubric, report, evidence, vapor, your-angle, JDG-04, RPT-03]
requirements: [JDG-04, RPT-03, T2-08, T2-09]
dependency_graph:
  requires: []
  provides:
    - "Tier 2 5-level verdict derivation table (mechanical)"
    - "JDG-04 full evidence rule (PARTIAL+ requires file path cite)"
    - "Your Angle synthesis section + placeholders"
    - "Tier 2 per-candidate report block with file_paths evidence"
    - "Vapor transparency dual-label display rule"
  affects:
    - "skills/reporecon/SKILL.md (will render Tier 2 prompts + report blocks)"
    - "scripts/vapor-check.sh (mechanical input to VAPOR verdict)"
tech_stack:
  added: []
  patterns:
    - "Mechanical verdict derivation (LLM emits scores, SKILL.md derives label)"
    - "Untrusted_content wrapping per inspected file"
    - "Negative-space synthesis (LLM after full candidate set)"
key_files:
  created: []
  modified:
    - skills/reporecon/references/judge-rubric.md
    - skills/reporecon/references/report-template.md
decisions:
  - "VAPOR override is unconditional — sits at top of threshold table regardless of axis sums"
  - "Tier 2 per-candidate block is additive (not a replacement); SKILL.md picks block by tier"
  - "Empty missing_features renders explicit fallback string rather than blank — preserves RPT-03 always-present rule"
  - "{{CAND_FILE_PATHS}} = 'none' is allowed only when verdict is SUPERFICIAL_MATCH or VAPOR"
metrics:
  tasks_completed: 2
  files_modified: 2
  duration: ~5min
  completed_date: 2026-05-26
---

# Phase 2 Plan 04: Extend judge-rubric + report-template for Tier 2 — Summary

Extended both Phase 1 reference files in place with Tier 2 sections — 5-level verdict derivation, full JDG-04 evidence rule, Your Angle negative-space section, per-candidate file-path evidence block — while leaving Tier 1 content byte-preserved.

## What Shipped

### `skills/reporecon/references/judge-rubric.md`

Appended six new H2 sections after the Phase 1 "Output Discipline" section:

1. **Tier 2 5-Level Verdict Derivation** — five labels (EXACT_MATCH / SIGNIFICANT_OVERLAP / PARTIAL_OVERLAP / SUPERFICIAL_MATCH / VAPOR) with mechanical threshold table combining `axis_sum`, `core_pair`, `evidence_count`, and `is_vapor`. VAPOR sits at top of table (unconditional override).
2. **Tier 2 Evidence Rule (JDG-04 Full)** — PARTIAL_OVERLAP or stronger requires ≥1 cited `path/to/file.ext:LINE`. Without cite → capped at SUPERFICIAL_MATCH (or VAPOR).
3. **Tier 2 Vapor Transparency Rule** — VAPOR with axis-suggested PARTIAL+ must display both labels: `VAPOR (axes suggested {LABEL})`.
4. **Tier 2 File Selection Algorithm** — manifest + entry point + top 8 source files by size, cap 10/repo.
5. **Tier 2 Judge Prompt Template** — full prompt with `<untrusted_content>` blocks per file, `file_paths` cite instruction, `suspected_injection` flag handling. Output schema adds `file_paths` and `flag` fields.
6. **Tier 2 Output Discipline** — derivation rules: LLM never emits verdict; VAPOR mechanical from `vapor-check.sh`; injection flag → SUPERFICIAL_MATCH.

Tier 1 sections (Scope: Tier 1 Only, Mechanical Verdict Derivation, Judge Prompt Template, Devil's-Advocate Re-Judge, Output Discipline) preserved word-for-word. Tier 1 cap line containing `capped at` + `WORTH_INSPECTING` retained.

### `skills/reporecon/references/report-template.md`

1. **Tier 2 Footer block replaced** — now two sub-headings:
   - `### Tier 1 → Tier 2 Opt-In Footer` — "Reply `tier 2` to start" (Tier 2 IS available)
   - `### Tier 2 Completed Footer` — uses `{{TIER2_CANDIDATES_INSPECTED}}` / `{{TIER2_CLONES_SKIPPED}}`
   - Literal "coming in Phase 2" string removed.

2. **Tier 2 Markdown Template (Extension)** — inserts `## Your Angle` (with `{{ANGLE_SUMMARY}}`, `{{ANGLE_BULLETS}}`) and `## Tier 2 Inspection Stats` between Candidates and What's Next sections.

3. **Tier 2 Per-Candidate Block** — extends Tier 1 block with `{{CAND_PROVENANCE}}` (tier1/tier2-gh/tier2-web), `{{CAND_VAPOR_TRANSPARENCY_SUFFIX}}`, `{{CAND_FILE_PATHS}}`. Tier 2 verdict set expanded to all 5 labels.

4. **Your Angle Section** — documents synthesis: LLM call inputs, output schema (`summary` ≤25 words + `missing_features` 3-7 bullets), placeholder mapping, fallback string for empty missing_features.

5. **Tier 2 Discipline Additions** — enforces: Tier 2 may use Phase 2 labels (Tier 1 may not); PARTIAL+ requires file path cite or `none` → SUPERFICIAL_MATCH/VAPOR; Your Angle always present (RPT-03); badge taxonomy unchanged from Tier 1.

Tier 1 sections (Slug Derivation Rule, Markdown Template, Per-Candidate Block Template, Verdict Badge Rules, Output Discipline) preserved.

## Verification

Acceptance criteria executed via grep:

| Check | Expected | Actual |
|-------|----------|--------|
| judge-rubric.md new H2 sections (6) | 1 each | 1 each ✓ |
| judge-rubric.md Phase 1 sections (4) preserved | 1 each | 1 each ✓ |
| judge-rubric.md code fences balanced | even | 6 ✓ |
| report-template.md new H2 sections (4) | 1 each | 1 each ✓ |
| report-template.md new H3 subheadings (2) | 1 each | 1 each ✓ |
| report-template.md Phase 1 sections (4) preserved | 1 each | 1 each ✓ |
| `coming in Phase 2` removed | 0 | 0 ✓ |
| Code fences balanced | even | 10 ✓ |
| All required placeholders present | ≥1 each | ✓ |
| tier2-gh, tier2-web, all 5 verdict labels present | ≥1 each | ✓ |

## Deviations from Plan

None — plan executed exactly as written.

## Commits

- `feec2c9` — feat(02-04): extend judge-rubric.md with Tier 2 5-level verdict + JDG-04 evidence rule
- `4883d35` — feat(02-04): extend report-template.md with Your Angle + Tier 2 candidate block

## Self-Check: PASSED

- skills/reporecon/references/judge-rubric.md — FOUND
- skills/reporecon/references/report-template.md — FOUND
- Commit feec2c9 — FOUND
- Commit 4883d35 — FOUND
- All acceptance grep checks — PASSED
- Tier 1 cap text (`WORTH_INSPECTING` + `capped at`) — STILL PRESENT in judge-rubric.md
