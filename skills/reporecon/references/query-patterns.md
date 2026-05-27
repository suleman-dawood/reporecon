# First-Search Query Patterns + Idea Sharpening

This reference is loaded on-demand by `skills/reporecon/SKILL.md` during the
**sharpen** (Step 1) and **query generation** (Step 2) phases of the first search
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

### Proper-Noun and Jargon Preservation Rule (v0.3.0)

Sharpening is the highest-risk step for distortion (see PITFALLS.md, Pitfall 10).
LLMs over-generalize: "NDIS invoice validator" silently becomes "billing
compliance tool," queries broaden, real matches disappear, the run lies to the
user. The preservation guard prevents this.

The sharpening step MUST preserve, verbatim, ANY term in the user's input that
matches ANY of these patterns. Preserved terms appear in the
`preserved_terms` array and MUST appear verbatim in at least one of the 7
generated queries (except TOPIC-TAG which is tags-only).

#### Preservation patterns

1. **ALL-CAPS acronyms** — `\b[A-Z]{2,}\b` (NDIS, HIPAA, FSANZ, LLM, RAG, MCP,
   API, SDK, UI, CLI).
2. **CamelCase / PascalCase product names** — any word containing both an
   uppercase letter and a lowercase letter where the first letter is uppercase
   or follows a non-word character. Matches `VelocityIQ`, `ShipFast`,
   `BetterAuth`, `RepoRecon`. Heuristic regex:
   `\b[A-Z][a-z]+(?:[A-Z][a-z0-9]+)+\b` plus single-segment PascalCase that
   appears in product-name position (the model decides via context — if the
   user says "I'm building Shortwave", `Shortwave` is preserved even though
   the regex only catches multi-segment forms).
3. **CamelCase with embedded lowercase prefix** — `dApp`, `iOS`, `eBPF`,
   `nVIDIA`. Heuristic: word starts with 1–2 lowercase letters followed by
   uppercase letter.
4. **Hyphenated technical terms** — any token containing a hyphen between
   alphanumeric characters: `code-gen`, `retrieval-augmented`,
   `chain-of-thought`, `side-by-side`, `drop-in`, `vapor-check`, `post-cutoff`.
5. **Version-suffixed identifiers** — `\b[A-Za-z]+-?\d+(?:\.\d+)*(?:[a-z])?\b`:
   `GPT-4o`, `Claude-3.5`, `Llama-3`, `Web3`, `Python3`, `Postgres15`, `IPv6`.
6. **Quoted phrases** — anything the user wraps in single or double quotes,
   preserved as a single multi-word term. "side-by-side TUI" stays as one
   preserved term, not three.
7. **Capitalised multi-word phrases** — `\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})\b`:
   "Smart Connections", "Issue Triage", "Pull Request". Treated as a single
   compound preserved term (joined by space when emitted). Also covers
   classic proper nouns like `Microsoft Graph`, `Google Cloud Build`,
   `Australian Tax Office`.
8. **Domain-specific jargon list** — the model SHOULD also preserve any of
   these terms verbatim when they appear in the user's input, even if they
   don't match the patterns above: `RAG`, `MCP`, `agentic`, `multi-agent`,
   `chain-of-thought`, `CoT`, `embedding`, `tool-use`, `function-calling`,
   `headless`, `daemon`, `sidecar`, `webhook`, `plugin`, `marketplace`,
   `self-hostable`, `air-gapped`, `zero-shot`, `few-shot`, `fine-tune`,
   `LoRA`, `PEFT`, `vector-db`, `pgvector`, `embeddings`, `transformer`,
   `attention`, `cron`, `idempotent`, `eventual-consistency`,
   `CODEOWNERS`, `monorepo`, `polyglot`, `sandbox`.
9. **Tech names with mixed-case or special chars** — `Node.js`, `scikit-learn`,
   `Next.js`, `PyTorch`, `gRPC`, `pnpm` (covered by patterns 2/3/4 above but
   listed for clarity).

#### What gets emitted

`preserved_terms` is a JSON array of strings. Order matches first appearance
in the user's idea. Deduplicate case-insensitively. If two preserved terms
overlap (e.g. "Smart Connections" includes "Smart"), prefer the LONGER
compound. Cap at 8 preserved terms — if more matches exist, choose the most
distinctive (lowest expected document frequency).

#### Verification

After generating `preserved_terms`, the model MUST re-scan the sharpened
sentence and confirm every preserved term appears verbatim. If any term was
paraphrased away by the sharpening LLM, re-prompt ONCE with the term list
re-injected and a stricter "do not paraphrase the following terms" preamble.
If a term is still dropped on the retry, surface to the user.

**Example:**

```
Raw:        "NDIS invoice validator for Australian healthcare providers"
Preserved:  ["NDIS", "Australian"]
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

Given the sharpened object, the LLM generates **exactly 7 queries in one LLM
call**, returned as a JSON array of 7 strings. Each query is:

- ≤120 chars
- Single line, no embedded newlines
- Must contain at least one preserved term (if any exist) verbatim — except for
  the TOPIC-TAG archetype, which is tags-only by construction
- Uses **exactly one** of the 7 archetypes below

The 7 archetypes are diversified so the result-set union covers literal,
near-synonym, outcome, technical, adjacent-domain, canonical-product-name, and
topic-tag framings of the same idea. This is per D-09 in `01-CONTEXT.md`.

first search budgets up to **15 gh search calls** (7 queries × 1 search each, plus
buffer for retries / pagination).

### LITERAL

Restate the sharpened sentence's nouns directly. No paraphrasing. This is the
"if the repo author named it on the tin, this finds them" query.

Example: `NDIS invoice validator`

### SYNONYM-SHIFTED

Replace **one** main verb or noun with a synonym. Preserved terms remain
unchanged.

Example: `NDIS claim checker`  (validator → checker, invoice → claim)

### OUTCOME-FRAMED

Frame the user-facing outcome instead of the implementation. Answers "what does
the user get?" rather than "what does the tool do?"

Example: `NDIS billing compliance audit tool`

### TECH-STACK-FRAMED

Add a `language:` or framework qualifier. If the sharpened sentence does not
imply a stack, default to `language:python` (most common for CLI/data tooling on
GitHub).

Example: `NDIS invoice language:python`

### ADJACENT-DOMAIN

Take one step outward to the broader category, but still include at least one
preserved term. This catches repos solving the same shape of problem in a
related domain.

Example: `healthcare invoice validation NDIS`

### CANONICAL-NAMES

Ask the model to enumerate 3–5 known product / project names in the target
space (closed-source + open-source), then emit the query as a space-delimited
list of those names. Example: for an idea "AI email triage for Gmail", emit
`inbox-zero Shortwave Superhuman Ghostwriter PanzaMail`. The query bypasses
GitHub's keyword-relevance ranking because the model is naming concrete repos
directly.

Rationale: GitHub's search/repositories ranks on token overlap; small phrasing
shifts can drop a popular repo from the top-10. Naming products directly is the
highest-recall query for known incumbents.

If the model genuinely doesn't know any names in the space, emit the LITERAL
archetype again with different phrasing.

Example: `inbox-zero Shortwave Superhuman Ghostwriter PanzaMail`

### TOPIC-TAG

Emit `topic:<tag1> topic:<tag2>` (1–3 tags, no other words). Tags are GitHub
topic identifiers, lowercase, hyphenated. Examples:
`topic:gmail-automation topic:llm-agent`,
`topic:ai-code-review topic:github-app`.

Rationale: GitHub topics are curated by maintainers and aggregate well-tagged
repos under shared labels. A topic query bypasses keyword matching entirely.

If the model can't guess plausible topic tags, fall back to the OUTCOME-FRAMED
archetype.

Example: `topic:gmail-automation topic:llm-agent`

### Query Hygiene

Hard rules every generated query must satisfy:

- No `is:private` qualifiers (first search has no business inspecting private repos).
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
