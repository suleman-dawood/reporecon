# Phase 1: Tier 1 MVP (Quick Verdict) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 01-CONTEXT.md — this log preserves the auto-mode selection trail.

**Date:** 2026-05-26
**Phase:** 01-tier-1-mvp-quick-verdict
**Mode:** auto (single-pass, recommended-default selection)

---

## Auto-Mode Selection Log

All gray areas auto-selected (auto mode). For each area, the recommended default was applied based on the brainstormed design already locked at the project level (see PROJECT.md "Key Decisions" and `.planning/research/SUMMARY.md`). No interactive AskUserQuestion calls were issued.

### Plugin Packaging
- Auto-selected: single-plugin self-marketplace layout (per STACK.md)
- Auto-selected: schemastore JSON schemas for IDE validation
- Auto-selected: `skills/reporecon/SKILL.md` canonical path

### Skill Authoring
- Auto-selected: SKILL.md ≤ 150 lines with `references/` progressive disclosure (per ARCHITECTURE.md)
- Auto-selected: triggers include `/reporecon` slash + natural phrases

### Discovery & Verification
- Auto-selected: `gh api search/repositories` only in Tier 1 (no WebSearch — avoids 10/hr code-search cap per PITFALLS.md)
- Auto-selected: 5 diverse queries (per project key decision)
- Auto-selected: hard 404-verification gate (per PITFALLS.md mitigation for the "origin bug")
- Auto-selected: preflight `gh auth status` + `rate_limit` (per PITFALLS.md)

### Idea Sharpening
- Auto-selected: one-sentence what/for-whom/how + 3-5 differentiator keywords
- Auto-selected: proper-noun preservation guard

### Judgment Rubric
- Auto-selected: 5-axis integer rubric, mechanical verdict derivation, temp=0, one-candidate-per-call (per PITFALLS.md mitigations for flip-flop and confirmation bias)
- Auto-selected: anti-novelty framing in judge prompt
- Auto-selected: devil's-advocate re-judge limited to GREEN-near-threshold cases (budget tradeoff for confirmation-bias guard)
- Auto-selected: Tier 1 verdict capped at `WORTH_INSPECTING` (no clone evidence yet — JDG-04 invariant)

### Mechanical Heuristics
- Auto-selected: staleness only in Phase 1; vapor heuristic deferred to Phase 2 (needs clones)
- Auto-selected: badges surfaced but do not auto-downgrade verdict

### Reporting
- Auto-selected: `./reporecon-reports/YYYY-MM-DD-<slug>.md` location
- Auto-selected: single-screen Tier 1 report format

### Helper Scripts
- Auto-selected: 4 scripts in Phase 1 (preflight, gh-search, verify-repo, staleness)
- Auto-selected: POSIX bash 4+, `set -euo pipefail`, jq for parsing

### Determinism & Testing
- Auto-selected: 3 golden fixtures (saturated / novel / ambiguous)
- Auto-selected: stability gate = verdict band match × 3 consecutive runs

## Deferred Ideas Captured
- WebSearch dual-discovery → Phase 2
- Source-file evidence citations → Phase 2
- Vapor heuristic → Phase 2 (needs clones)
- Negative-space section → Phase 2
- Marketplace submission, README polish, examples → Phase 3
- Streaming output, idea-hash cache → v2
- GitLab/Codeberg/registries → v2
- CLI / gh extension distribution → v2

## Notes
- Single-pass auto mode. No re-passes over CONTEXT.md.
- Discuss-mode pass cap honored.
