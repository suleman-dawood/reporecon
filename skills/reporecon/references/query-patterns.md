# Tier 1 Query Patterns + Idea Sharpening

This reference is loaded on-demand by `skills/reporecon/SKILL.md` during the
**sharpen** (Step 1) and **query generation** (Step 2) phases of the Tier 1
protocol. Progressive disclosure: keep this open only while those steps run.

## Idea Sharpening (Step 1 of SKILL.md protocol)

The raw user idea is fuzzy natural language. Before any `gh api` calls, the LLM
rewrites it into a canonical form so that downstream queries and the report
header are deterministic and reproducible.

**Sharpened form:**

```
<one-sentence what/for-whom/how> + <3-5 differentiator keywords>
```

**Mechanics:**

- Single LLM call, temperature **0** (or the lowest the host exposes).
- If the host does not expose a temperature parameter, include this literal
  line in the prompt: `Respond deterministically. Do not paraphrase proper nouns.`
- One pass only. Do not re-sharpen mid-run.
- The sharpened sentence is the canonical idea for the rest of the run.

### Proper-Noun Preservation Rule

Sharpening is the highest-risk step for distortion (see PITFALLS.md, Pitfall 10).
LLMs over-generalize: "NDIS invoice validator" silently becomes "billing
compliance tool," queries broaden, real matches disappear, the run lies to the
user. The proper-noun guard prevents this.

**Extract from the raw input, verbatim, all of:**

1. **Acronyms** matching `[A-Z]{2,}` — examples: `NDIS`, `FSANZ`, `HIPAA`,
   `OAuth`, `JWT`, `IAM`, `ACL`.
2. **Capitalized multi-word phrases** — examples: `Microsoft Graph`,
   `Google Cloud Build`, `Australian Tax Office`.
3. **Tech names with mixed-case or special chars** — examples: `Node.js`,
   `scikit-learn`, `Next.js`, `PyTorch`, `gRPC`, `pnpm`.

These form the **preserved terms** list. The rule:

> Every preserved term MUST appear verbatim in the sharpened sentence AND in at
> least one of the 5 generated queries.

**Example:**

```
Raw:        "NDIS invoice validator for Australian healthcare providers"
Preserved:  ["NDIS"]
Sharpened:  "A CLI for Australian healthcare providers that validates NDIS
            invoices against jurisdiction rules"
Keywords:   ["NDIS", "invoice-validation", "healthcare-compliance"]
```

**Anti-pattern (rejected):**

```
Sharpened (BAD):  "A tool that checks disability scheme billing"
                  -- "NDIS" silently replaced with "disability scheme"
                  -- "Australian" dropped
                  -- queries will now miss every NDIS-specific repo
```

If the sharpener output drops a preserved term, the SKILL.md protocol re-prompts
once with the explicit term list re-injected. If it drops it again, surface to
the user.

### Sharpening Output Schema

The sharpener returns a single JSON object:

```json
{
  "sharpened_sentence": "...",
  "preserved_terms": ["..."],
  "differentiator_keywords": ["...", "...", "..."]
}
```

Constraints:

- `sharpened_sentence`: one sentence, ≤220 chars.
- `preserved_terms`: array of strings (may be empty if input had no proper nouns).
- `differentiator_keywords`: array length **3 to 5**, kebab-case or single tokens.

## Query Archetypes (Step 2 of SKILL.md protocol)

Given the sharpened object, the LLM generates **exactly 5 queries in one LLM
call**, returned as a JSON array of 5 strings. Each query is:

- ≤120 chars
- Single line, no embedded newlines
- Must contain at least one preserved term (if any exist) verbatim
- Uses **exactly one** of the 5 archetypes below

The 5 archetypes are diversified so the result-set union covers literal,
near-synonym, outcome, technical, and adjacent-domain framings of the same idea.
This is per D-09 in `01-CONTEXT.md`.

### 1. LITERAL

Restate the sharpened sentence's nouns directly. No paraphrasing. This is the
"if the repo author named it on the tin, this finds them" query.

Example: `NDIS invoice validator`

### 2. SYNONYM-SHIFTED

Replace **one** main verb or noun with a synonym. Preserved terms remain
unchanged.

Example: `NDIS claim checker`  (validator → checker, invoice → claim)

### 3. OUTCOME-FRAMED

Frame the user-facing outcome instead of the implementation. Answers "what does
the user get?" rather than "what does the tool do?"

Example: `NDIS billing compliance audit tool`

### 4. TECH-STACK-FRAMED

Add a `language:` or framework qualifier. If the sharpened sentence does not
imply a stack, default to `language:python` (most common for CLI/data tooling on
GitHub).

Example: `NDIS invoice language:python`

### 5. ADJACENT-DOMAIN

Take one step outward to the broader category, but still include at least one
preserved term. This catches repos solving the same shape of problem in a
related domain.

Example: `healthcare invoice validation NDIS`

### Query Hygiene

Hard rules every generated query must satisfy:

- No `is:private` qualifiers (Tier 1 has no business inspecting private repos).
- No `/search/code` endpoint usage; this is **repo search only**.
- No embedded newlines.
- Queries are independent — do not chain or assume one feeds the next.
- No quoting tricks intended to bypass the proper-noun guard.

## Dedup & Ranking (Step 3)

After the 5 queries return, dedup and rank candidates for verification:

1. **Collect** every `full_name` across the 5 result sets.
2. **Rank-sum** = sum of 0-indexed position in each query's result list. A repo
   missing from a query receives a penalty of `per_page = 10` for that query.
3. **Select** the top 5 candidates by **lowest rank-sum**. Ties broken by
   stargazer count (descending), then by `full_name` (ascending lexicographic).
4. These 5 feed the verification step (`gh api /repos/{owner}/{name}`).

Rationale: rank-sum rewards repos that appear in multiple archetypes — a strong
signal of relevance — without requiring any single query to be perfect.

## Sharpened Statement → Report Header

The exact `sharpened_sentence` and `preserved_terms` list MUST appear in the
report header (per D-15 and D-24). Do not summarize, do not re-paraphrase, do
not strip. The user reads the header first; mismatch between their intent and
the sharpened form is the single most important signal of a bad run, and they
can only spot it if the sharpened form is shown unedited.
