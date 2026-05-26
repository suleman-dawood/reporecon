# Tier 1 Report Template

This reference is loaded on-demand by `skills/reporecon/SKILL.md` during the
**emit report** step (Step 7) of the Tier 1 protocol.

**Output path:** `./reporecon-reports/YYYY-MM-DD-<slug>.md`

The skill creates `./reporecon-reports/` if it does not exist (`mkdir -p`). All
report files land there; nothing else in the working directory is touched.

## Slug Derivation Rule

The `<slug>` portion of the filename derives mechanically from the
`sharpened_sentence` (see `query-patterns.md`). The LLM does the substitution;
no templating engine is involved.

**Transform (in order):**

1. Lowercase the entire `sharpened_sentence`.
2. Strip every character not matching `[a-z0-9 ]` (whitespace preserved at this
   step).
3. Collapse runs of whitespace to a single `-`.
4. Truncate to **≤40 chars**.
5. Trim any trailing `-`.

**Allowed regex (output must match):** `^[a-z0-9][a-z0-9-]{0,39}$`

If the derived slug is empty (e.g., sharpened sentence was all symbols), fall
back to `untitled`.

**Collision suffix:** if `YYYY-MM-DD-<slug>.md` already exists in
`./reporecon-reports/`, try `YYYY-MM-DD-<slug>-2.md`, then `-3.md`, and so on —
the smallest integer `N ≥ 2` that does not collide. **Never overwrite an
existing report.**

This regex strict-allowlist prevents path traversal (`../`, `/`) and shell
metacharacters from leaking out of the user-supplied idea into a filesystem
write.

## Markdown Template

The skill reads this template, substitutes `{{DOUBLE_BRACE}}` placeholders with
runtime values, and writes the result to the output path.

```markdown
# {{VERDICT_BADGE}} RepoRecon Report

## Sharpened Idea

{{SHARPENED_STATEMENT}}

Preserved terms: {{PRESERVED_TERMS}}

## Run Metadata

- Timestamp: {{RUN_TIMESTAMP}}
- gh rate budget (core) before run: {{RATE_BUDGET_CORE_BEFORE}}
- gh rate budget (search) before run: {{RATE_BUDGET_SEARCH_BEFORE}}
- gh rate budget (core) after run: {{RATE_BUDGET_CORE_AFTER}}
- gh rate budget (search) after run: {{RATE_BUDGET_SEARCH_AFTER}}

## Candidates

{{CANDIDATE_BLOCKS}}

## What's Next?

{{TIER2_FOOTER}}
```

**Required placeholders (verbatim):**

`{{VERDICT_BADGE}}`, `{{SHARPENED_STATEMENT}}`, `{{PRESERVED_TERMS}}`,
`{{RUN_TIMESTAMP}}`, `{{RATE_BUDGET_CORE_BEFORE}}`,
`{{RATE_BUDGET_SEARCH_BEFORE}}`, `{{RATE_BUDGET_CORE_AFTER}}`,
`{{RATE_BUDGET_SEARCH_AFTER}}`, `{{CANDIDATE_BLOCKS}}`, `{{TIER2_FOOTER}}`.

## Per-Candidate Block Template

For each verified candidate, substitute this block and concatenate into
`{{CANDIDATE_BLOCKS}}` (separated by a blank line). Per D-25.

```markdown
### {{CAND_FULL_NAME}}

[{{CAND_URL}}]({{CAND_URL}}) — verified at {{CAND_VERIFIED_AT}}

**Verdict:** {{CAND_VERDICT}}

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | {{CAND_AXIS_CORE_FUNCTION}}   |
| target_audience | {{CAND_AXIS_TARGET_AUDIENCE}} |
| scope           | {{CAND_AXIS_SCOPE}}           |
| approach        | {{CAND_AXIS_APPROACH}}        |
| activity        | {{CAND_AXIS_ACTIVITY}}        |

Staleness: {{CAND_STALENESS_BADGES}}

> {{CAND_RATIONALE}}
```

**Required per-candidate placeholders (verbatim):**

`{{CAND_FULL_NAME}}`, `{{CAND_URL}}`, `{{CAND_VERIFIED_AT}}`,
`{{CAND_VERDICT}}`, `{{CAND_AXIS_CORE_FUNCTION}}`,
`{{CAND_AXIS_TARGET_AUDIENCE}}`, `{{CAND_AXIS_SCOPE}}`, `{{CAND_AXIS_APPROACH}}`,
`{{CAND_AXIS_ACTIVITY}}`, `{{CAND_RATIONALE}}`, `{{CAND_STALENESS_BADGES}}`.

**Rules for substituted values:**

- `{{CAND_VERDICT}}` must be exactly one of: `LIKELY_MATCH`, `WORTH_INSPECTING`,
  `UNRELATED`.
- `{{CAND_VERIFIED_AT}}` is an ISO-8601 UTC timestamp captured at the moment
  `gh api /repos/{owner}/{name}` returned 200 OK. RPT-04 requirement: **no URL
  appears in any report without this timestamp.**
- `{{CAND_STALENESS_BADGES}}` is a space-separated list of badge tags from
  `scripts/staleness.sh` (e.g., `archived stale-12mo`) or the literal string
  `none`.
- `{{CAND_RATIONALE}}` is a single sentence from the judge JSON output. No
  multi-line rationales in Tier 1.

## Verdict Badge Rules

`{{VERDICT_BADGE}}` is derived mechanically from the per-candidate verdicts
(per D-19):

| Condition                                            | Badge | Label              |
| ---------------------------------------------------- | ----- | ------------------ |
| At least one candidate is `LIKELY_MATCH`             | 🔴    | "This exists"      |
| Any `WORTH_INSPECTING` (and no `LIKELY_MATCH`)       | 🟡    | "Some overlap"     |
| All candidates are `UNRELATED`                       | 🟢    | "No close match"   |

The substituted value is the emoji followed by the label in quotes, e.g.
`🔴 "This exists"`.

## Tier 2 Footer

`{{TIER2_FOOTER}}` is substituted with the following literal block. Tier 2 is
documented but **disabled in Phase 1** (per D-26, T1-08):

> **Want deep inspection?** Tier 2 will clone the top WORTH_INSPECTING
> candidates and judge equivalence with file-path evidence. *Tier 2 is not yet
> available — coming in Phase 2. Re-run with `--tier2` once Phase 2 ships.*

## Output Discipline

Hard rules enforced by the SKILL.md protocol when writing the report:

- **Never** include `gh auth` output, environment variables, or token values in
  the report. Tokens are secrets; reports are shareable artifacts.
- **Never** list a URL without a `verified at {ISO timestamp}` annotation. This
  is the hallucinated-citation guard (PITFALLS.md, Pitfall 11). If a candidate
  failed verification (404), it does not appear in the report at all.
- **Exactly one emoji per report**: the verdict badge in the H1. No decorative
  emoji anywhere else. Reports are scanned, not decorated.
- Sanitize any text originating from upstream repo metadata before substitution
  — strip HTML comments, zero-width chars, and unicode tag-block sequences. The
  description field from `gh api` is the most common injection vector for Tier 1
  (Tier 2 has the bigger surface).
