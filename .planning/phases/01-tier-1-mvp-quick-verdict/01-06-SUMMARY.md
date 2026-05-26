---
phase: 01-tier-1-mvp-quick-verdict
plan: 06
subsystem: skill-orchestration
tags: [skill, orchestration, tier-1, progressive-disclosure]
requires:
  - skills/reporecon/references/query-patterns.md (Plan 03)
  - skills/reporecon/references/judge-rubric.md (Plan 04)
  - skills/reporecon/references/report-template.md (Plan 03)
  - scripts/preflight.sh (Plan 02)
  - scripts/gh-search.sh (Plan 02)
  - scripts/verify-repo.sh (Plan 02)
  - scripts/staleness.sh (Plan 05)
provides:
  - "Tier 1 7-step orchestration prompt at skills/reporecon/SKILL.md"
  - "Triggers: /reporecon, validate my idea, does this exist on github"
  - "Mechanical verdict derivation (LLM emits axes only, threshold table derives verdict)"
affects:
  - Plan 07 (golden-test wave) consumes this file end-to-end
tech-stack:
  added: []
  patterns:
    - "Progressive disclosure: SKILL.md body 119 lines; references Read on-demand"
    - "${CLAUDE_PLUGIN_ROOT} env var for plugin-relative paths"
    - "Mechanical verdict derivation (HEUR-03; no LLM verdict label)"
key-files:
  created:
    - skills/reporecon/SKILL.md (119 lines)
  modified: []
decisions:
  - "Kept Step 8 (chat verdict) and Discipline section despite line budget — required by plan acceptance criteria"
  - "Compressed inline bash invocations to single-line backtick form to fit under 150-line cap"
  - "Confirmed A2 (CLAUDE_PLUGIN_ROOT) + A3 (effort:medium) per STACK.md research — both retained"
metrics:
  duration: ~3min
  completed: 2026-05-26
  line_count: 119
---

# Phase 1 Plan 06: Tier 1 SKILL.md Orchestrator Summary

Wired the Tier 1 7-step protocol (preflight → sharpen → query gen → discover → verify → judge → report) into `skills/reporecon/SKILL.md` as a 119-line progressive-disclosure prompt that loads references on demand and invokes the four helper scripts at the correct steps.

## What Was Built

- **File:** `skills/reporecon/SKILL.md` (119 lines, well under D-05's 150-line cap)
- **Frontmatter:** `name: reporecon`, multi-line description containing `/reporecon` + 3 natural-language triggers (per D-06, INP-01), `allowed-tools: [Bash, Read, Write]`, `effort: medium`
- **HARD RULE** stated upfront: no URL appears without `verify-repo.sh` 200 OK timestamped within the run (PITFALLS.md #11, T-06-01)
- **9 numbered step headers** (Step 0 Preflight through Step 8 chat verdict + Devil's-Advocate Re-Judge subsection)
- **References wired** via `Read ${CLAUDE_PLUGIN_ROOT}/skills/reporecon/references/<file>.md` at the correct steps (query-patterns at Step 1+2, judge-rubric at Step 6, report-template at Step 7)
- **Scripts wired** via `bash ${CLAUDE_PLUGIN_ROOT}/scripts/<file>.sh` at Steps 0, 3, 5, 6, 7 (preflight twice — before + after for rate budget delta)
- **Mechanical derivation** explicitly stated: LLM emits axis_scores + rationale only; SKILL.md derives candidate_verdict from threshold table; overall verdict from highest per-candidate verdict
- **Devil's-Advocate Re-Judge** wired with explicit trigger condition (🟢 + any axis ≥2) and budget cap (2 candidates) per D-20
- **Tier 2 explicitly disabled** (D-26): footer routes to report-template.md's "*not yet available — coming in Phase 2*" line
- **Discipline section** restating PITFALLS.md mitigations (#1 batching, #2 framing leak, #11 hallucinated URL, #6 secondary rate limit) + token/env sanitization

## Assumption Verification (Task 1)

- **A2 (`${CLAUDE_PLUGIN_ROOT}`):** Verified from STACK.md ("scripts are referenced from SKILL.md by path relative to the plugin root — `${CLAUDE_PLUGIN_ROOT}` is set by Claude Code at runtime"). Used throughout SKILL.md. No fallback needed.
- **A3 (`effort: medium`):** Verified from STACK.md SKILL.md frontmatter section ("`effort: medium` — Tier 1 is short, Tier 2 involves multi-step reasoning. `high` is overkill"). Field retained.
- Did not re-fetch docs page in this run (worktree is offline-friendly; STACK.md was researched in pre-planning phase and both assumptions are documented there with direct source citations).

## Deviations from Plan

**1. [Trim - non-functional] Compressed body from 154 → 119 lines**
- **Found during:** Final verification (`wc -l` returned 154 on first draft)
- **Fix:** Inlined trivial bash invocations to backtick single-lines instead of fenced blocks; removed restating-of-obvious sentences while preserving every required grep token and every mitigation reference
- **Files modified:** skills/reporecon/SKILL.md
- **Commit:** 35f0d1f

No other deviations. All Plan-listed acceptance criteria pass:

| Check | Result |
|-------|--------|
| File at exact path | OK (skills/reporecon/SKILL.md) |
| Line count ≤ 150 | OK (119) |
| YAML frontmatter | OK (starts with `---`, contains `name: reporecon`, `allowed-tools`) |
| `/reporecon` trigger | OK |
| 4 helper scripts named | OK (preflight, gh-search, verify-repo, staleness) |
| 3 references named | OK (query-patterns, judge-rubric, report-template) |
| `HARD RULE` present | OK |
| `reporecon-reports` present | OK |
| Tier 2 deferral footer | OK |
| 7+ protocol steps | OK (9 `^## Step` headers) |

## Notes for Plan 07 (Wave 3 Golden Tests)

Hot spots to measure against the 90s wall-clock budget:

1. **300ms sleep between gh-search calls** — 4 sleeps × 300ms = 1.2s; cheap. Almost certainly fine but if Plan 07 finds wall-clock margin tight, this is the first knob.
2. **README excerpt fetch (Step 6)** — `gh api repos/{owner}/{repo}/readme` is one extra core-API call per verified candidate (up to 5 calls). Could be parallelized alongside the judge step (each candidate is independent). If 90s budget is breached, run README fetch in parallel with verify-repo.sh and keep them cached for the judge step.
3. **Parallel verify (Step 5)** — `xargs -P 5` assumed; if the host shell varies, the fallback (background jobs + `wait`) works on any POSIX bash 4+. No issue expected.
4. **Devil's-advocate re-judge** — capped at 2 calls, but each is a full judge call (one candidate, README included). On a 🟢 run with 2 triggers, this adds ~2 LLM round-trips. Build the 90s budget assuming this fires.
5. **Token budget** — README excerpts × 5 candidates × 3000 chars ≈ 15KB of prompt tokens, plus the rubric file Read once. Well under any context window.
6. **Determinism risk** — Step 1 (sharpening) is the highest-variance step. If Plan 07 sees verdict-band drift across 3 runs on the same fixture, suspect sharpening drift first; the proper-noun guard is the mitigation.

## Self-Check: PASSED

- `skills/reporecon/SKILL.md` — FOUND (119 lines)
- Commit `35f0d1f` — FOUND in `git log` on this branch
- No other files touched (Wave 2 constraint honored)
