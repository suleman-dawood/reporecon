---
phase: 02-tier-2-deep-inspection
plan: 03
subsystem: skills/reporecon/references
tags: [tier2, protocol, untrusted-content, sanitization, dedupe, websearch]
requires:
  - skills/reporecon/SKILL.md (Tier 1, will be extended in 02-06)
  - scripts/verify-repo.sh (404 gate)
  - scripts/gh-search.sh (query call)
  - scripts/safe-clone.sh (cloning — added separately in this phase)
provides:
  - skills/reporecon/references/tier2-protocol.md
affects:
  - SKILL.md Tier 2 path (wired in 02-06)
tech-stack:
  added: []
  patterns:
    - "<untrusted_content source='...'>...</untrusted_content> wrapper"
    - "sed-based zero-width + HTML-comment sanitization"
    - "provenance tag per candidate (tier1 / tier2-gh / tier2-web)"
    - "xargs -P 3 parallel clone cap"
key-files:
  created:
    - skills/reporecon/references/tier2-protocol.md
  modified: []
decisions:
  - "Opt-in phrases broadened to: yes, y, tier 2, tier2, deep, deep dive, dig deeper, inspect, go (anything else terminates)"
  - "Tier 2 search budget conservatively set to ≤10 gh api calls in expansion step (leaves headroom under 30/min bucket)"
  - "Sleep 400ms between Tier 2 search calls (vs Tier 1's 300ms) to leave headroom for WebSearch verification"
  - "Selection cap = 8 candidates; parallel clone cap = 3"
  - "suspected_injection flag does NOT auto-downgrade overall verdict (consistent with HEUR-03 badge rule), but suppresses that candidate's axis_scores"
metrics:
  duration: "~10 min"
  completed: "2026-05-26"
  tasks: 1
  files_changed: 1
  lines_added: 171
---

# Phase 2 Plan 03: tier2-protocol.md Reference Summary

One-liner: Created `skills/reporecon/references/tier2-protocol.md` (171 lines) encoding all Tier 2 defenses — expanded discovery, 404-verify-all gate, dedupe-by-full_name with provenance, untrusted-content wrapper with truncation/sanitization, suspected_injection adversarial protocol, and run-scoped cleanup — ready for SKILL.md to load in 02-06.

## Objective Met

Created the Tier 2 reference file that SKILL.md will load on-demand when the user opts into deep inspection. Tier 2 EXTENDS the Tier 1 protocol; this file does not edit any Phase 1 artifact.

## Files Created

- `skills/reporecon/references/tier2-protocol.md` (171 lines)

## Sections Included (all 11 required headings)

1. `# Tier 2 Deep-Inspection Protocol` (H1 + purpose paragraph)
2. `## Trigger Conditions` — opt-in phrase list + 🟡/🔴 prerequisite
3. `## Boot-Time Cleanup Sweep` — literal `find /tmp/reporecon ... -mmin +120` command
4. `## Discovery Expansion` — 10 query archetypes (DOMAIN-NARROW, TOPIC-TAG, DESCRIPTION-MATCH, README-MATCH, LICENSE-FILTER, SIZE-BOUND, FORK-EXCLUDED, RECENT-ACTIVITY, STAR-BOUND, ORG-AUTHOR)
5. `## WebSearch Protocol` — 5 queries, snippets-are-untrusted rule, per-URL verify-repo.sh gate
6. `## Dedupe Rule` — full_name (case-insensitive), provenance tagging
7. `## Selection for Cloning` — 8-candidate cap, xargs -P 3 parallel clone
8. `## Safe Clone Invocation` — safe-clone.sh exit-code routing (11/12/13/other)
9. `## Untrusted Content Protocol` — wrapper, 3000-char/200-line/10-file truncation, sed sanitization (HTML comments + U+200B/C/D + U+FEFF), suspected_injection handling
10. `## File Selection for Judge` — manifest + entry point + up to 8 top-level source files
11. `## Cleanup Discipline` — SKILL.md run-scoped trap is authoritative

## Acceptance Criteria Verification

All 22 grep criteria pass:

- File exists ✓
- 171 lines (≥120) ✓
- All 11 H1/H2 headings present (count = 1 each) ✓
- `<untrusted_content source="github.com` ✓ (1 occurrence)
- `verify-repo.sh` ✓ (4 occurrences)
- `mmin +120` ✓ (2 occurrences)
- `3000` ✓ (1 occurrence — README truncation)
- `200 lines` ✓ (1 occurrence — per-source-file cap)
- `10 source files` ✓ (1 occurrence — per-repo cap)
- `suspected_injection` ✓ (2 occurrences)
- `full_name` ✓ (2 occurrences)
- `provenance` ✓ (2 occurrences)
- `safe-clone.sh` ✓ (4 occurrences)
- `xargs -P 3` ✓ (1 occurrence)
- `U+200B` / `200B` ✓ (1 occurrence + adjacent C/D/FEFF)
- `<!--` ✓ (2 occurrences — HTML comment sanitization)
- 10 distinct archetype labels ✓ (-NARROW, -TAG, -MATCH×2, -FILTER, -BOUND×2, -EXCLUDED, -ACTIVITY, -AUTHOR)
- Code fences even (14) ✓

## Requirements Closed

- **T2-02** — 10 expanded queries + WebSearch documented ✓
- **T2-03** — 404-verify all cited URLs documented with verify-repo.sh reference ✓
- **T2-07** — untrusted content delimited, truncated, sanitized with concrete sed pipeline ✓

## Decisions Referenced

D2-01 (opt-in trigger), D2-02 (🟢 no-prompt), D2-03 (10 expanded queries), D2-04 (404 gate every URL), D2-05 (dedupe by full_name), D2-06 (safe-clone exit codes), D2-07 (boot-time sweep), D2-11 (wrapper), D2-12 (truncation), D2-13 (sanitization), D2-14 (adversarial flag), D2-17 (file selection).

## Deviations from Plan

None — plan executed exactly as written.

## Authentication Gates

None encountered.

## Commits

- `5e893a6` feat(02-03): add tier2-protocol.md reference

## Known Stubs

None.

## Self-Check: PASSED

- `skills/reporecon/references/tier2-protocol.md` — FOUND
- Commit `5e893a6` — FOUND
- All 22 grep acceptance criteria — PASS
- Code fence parity (14, even) — PASS
