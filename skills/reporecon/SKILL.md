---
name: reporecon
description: |
  Validate whether a project idea already exists on GitHub before you build it.
  Triggers on /reporecon <idea>, "is there already a tool that does X",
  "validate my idea", "does this exist on github". Returns a 🟢/🟡/🔴 verdict
  in ~90 seconds using gh api metadata only (no clones, no WebSearch).
allowed-tools:
  - Bash
  - Read
  - Write
effort: medium
---

# RepoRecon Tier 1 Protocol (≤10 gh api calls, ≤90s)

Run on `/reporecon <idea>` or matching trigger. Return a 🟢/🟡/🔴 verdict +
Markdown report with mechanically derived per-axis scores, ≤90s, `gh api`
metadata only.

> **HARD RULE:** No URL appears in any output without a `verify-repo.sh` 200
> OK timestamped within this run. 404s drop the candidate entirely.

## Step 0: Preflight

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh`. If exit non-zero, print
its stderr verbatim and STOP. On success parse the JSON
`{core_remaining, search_remaining}` and keep it as `RATE_BEFORE` for the
report header.

## Step 1: Sharpen the Idea

Read `${CLAUDE_PLUGIN_ROOT}/skills/reporecon/references/query-patterns.md`
sections "Idea Sharpening" and "Proper-Noun Preservation Rule". ONE LLM call,
temperature **0**. Emit the exact Sharpening Output Schema JSON
(`sharpened_sentence`, `preserved_terms`, `differentiator_keywords`). If any
preserved term is dropped, re-prompt once with the term list re-injected.

## Step 2: Generate 5 Queries

Using the "Query Archetypes" section of `query-patterns.md`, generate exactly
**5 queries in ONE LLM call** — one per archetype (LITERAL, SYNONYM-SHIFTED,
OUTCOME-FRAMED, TECH-STACK-FRAMED, ADJACENT-DOMAIN). Each query MUST contain
at least one preserved term verbatim. Output: JSON array of 5 strings.

## Step 3: Discover

For each query: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/gh-search.sh "<query>"`.
Sleep 300ms between calls (PITFALLS.md #6 secondary-rate-limit guard). Collect
5 JSON arrays.

## Step 4: Dedup + Rank

Apply the "Dedup & Ranking" rule from `query-patterns.md`: collect every
`full_name`, compute rank-sum (missing-from-query penalty = 10), take the top
5 by lowest rank-sum; ties → stars desc, then `full_name` asc.

## Step 5: Verify

For each of the 5 ranked candidates, run in parallel (`xargs -P 5` or
background jobs + `wait`):
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-repo.sh "<owner/repo>"`.
Drop any candidate whose script exits non-zero (404 — HARD RULE). Collect
verified metadata JSON (including `verified_at` ISO timestamp).

## Step 6: Judge per candidate

Read `${CLAUDE_PLUGIN_ROOT}/skills/reporecon/references/judge-rubric.md`. For
EACH verified candidate, issue **one judge call** (no batching — PITFALLS.md
#1) at temperature 0. Pass only the sharpened sentence + preserved terms +
candidate metadata JSON + first 3000 chars of README (PITFALLS.md #2: strip
the user's original framing):
`gh api "repos/{owner}/{repo}/readme" --jq .content | base64 -d | head -c 3000`.

Collect `axis_scores` + `rationale`. **Derive `candidate_verdict` mechanically**
from the threshold table in `judge-rubric.md` — do NOT let the LLM emit the
verdict label. Allowed Tier 1 labels: `LIKELY_MATCH`, `WORTH_INSPECTING`,
`UNRELATED`. Never emit Phase 2 labels.

Also run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/staleness.sh "<verified-json>"`
per candidate. Per HEUR-03 badges never auto-downgrade the verdict.

Compute the **overall verdict** per the "Overall Run Verdict" section of
`judge-rubric.md`: any `LIKELY_MATCH` → 🔴; only `WORTH_INSPECTING` → 🟡; all
`UNRELATED` → 🟢.

### Devil's-Advocate Re-Judge

If overall is 🟢 AND any candidate has any axis ≥2, re-judge up to 2 such
candidates (highest `axis_sum` first) with the REVERSE FRAMING prompt from
`judge-rubric.md`. Apply the downgrade rule (🟢 → 🟡) if triggered.

## Step 7: Emit Report

Read `${CLAUDE_PLUGIN_ROOT}/skills/reporecon/references/report-template.md`.
Derive the slug per the "Slug Derivation Rule" (with collision suffix). Then
`mkdir -p ./reporecon-reports` and re-run preflight.sh to capture RATE_AFTER.

Substitute every `{{PLACEHOLDER}}`. Each candidate block MUST include
`verified at {CAND_VERIFIED_AT}`. Use the exact Tier 2 footer from
`report-template.md` — Tier 2 is disabled in Phase 1 per D-26 (*not yet
available — coming in Phase 2*). Write via the `Write` tool to
`./reporecon-reports/YYYY-MM-DD-<slug>.md`; never overwrite.

## Step 8: Verdict block to chat

≤10 lines: overall badge + label, sharpened sentence, top candidate
(full_name + verdict) if any, report path, "Tier 2 coming in Phase 2" footer.

## Discipline

- Temperature 0 every LLM call (JDG-07); else "Respond deterministically." in prompt.
- **HARD RULE:** no URL without verify-repo.sh 200 OK (PITFALLS.md #11).
- One candidate per judge call (PITFALLS.md #1).
- Strip user's framing from judge context (PITFALLS.md #2).
- Staleness badges DO NOT auto-downgrade verdict (HEUR-03).
- Never include `gh auth` output, env vars, or tokens in the report.
- Sanitize upstream metadata text (strip HTML comments, zero-width chars,
  unicode tag blocks) before substitution.
