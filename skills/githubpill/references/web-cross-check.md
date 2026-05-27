# Web Cross-Check Protocol (first-search baseline)

**Purpose.** Catch competitors that don't appear in `gh api search/repositories` — closed-source SaaS, YC startups, GitHub Apps, GitHub Marketplace Actions, well-known products buried in awesome-list curations.

This protocol runs ONCE in first search immediately after the gh-search discovery step. It is NOT optional. Skipping it reintroduces the v0.1.0 blind spot.

## Inputs
- Sharpened sentence
- Preserved terms
- Differentiator keywords
- The 7 archetype queries (already run via gh-search)

## Outputs
A JSON array of `web_candidate` objects:

```
{
  "name": "Ellipsis",
  "url": "https://ellipsis.dev",
  "category": "closed-source-saas | yc-company | github-app | github-marketplace | awesome-list-entry | hn-launch | product-hunt | other",
  "evidence_snippet": "<≤200 chars from the WebSearch result that supports the claim>",
  "source_query": "<the WebSearch query that surfaced it>",
  "http_code": "<3-digit HTTP status from verify-url.sh, REQUIRED for first-web-saas candidates>",
  "final_url": "<URL after redirect chain — surface in report if it differs from the original url>"
}
```

Candidates whose URL is a `github.com/<owner>/<repo>` link MUST be additionally verified via `scripts/verify-repo.sh` and merged into the gh-candidate pool (provenance: "first-web" rather than first-gh).

## Required searches (5 queries, single batch)

Generate exactly 5 WebSearch queries in ONE LLM call (temperature 0). Each must use at least one preserved term verbatim. Map archetypes:

1. **Canonical-product** — name-based: `"<idea-domain> AI tool"` OR `"best <idea-domain> agent 2026"`. Bias toward product names.
2. **YC + funded startups** — `"<sharpened sentence> YC startup"` OR `"<sharpened sentence> seed funded 2025 2026"`.
3. **Awesome-list traversal** — `awesome <domain>` OR `awesome <preserved-term>` (e.g. `awesome-llm-agents`, `awesome-gmail-automation`). Models should mine the README of the top hit.
4. **GitHub Marketplace + GitHub Apps** — `site:github.com/marketplace "<domain>"` OR `"GitHub App" <sharpened sentence>`.
5. **HN / Product Hunt** — `site:news.ycombinator.com "<sharpened sentence>"` OR `site:producthunt.com "<domain>"`.

If any query returns nothing useful, the model MAY substitute a tighter variant ONCE. Do not exceed 5 WebSearch calls total per first search run.

### HARD RULE — Forbidden qualifiers in SaaS-archetype queries

Archetypes 1, 2, and 5 (Canonical-product, YC+funded, HN/Product Hunt) target the **closed-source SaaS market**. Their queries MUST NOT contain any of the following tokens (case-insensitive), even if those tokens appear in the user's sharpened sentence or preserved terms:

- `open source`, `open-source`, `opensource`, `oss`
- `github`, `site:github.com` (except archetype 4, which is *specifically* a GitHub Marketplace query)
- `free`, `self-hosted`, `selfhosted`

**Why:** Baking `"open source"` or `"github"` into a SaaS-competitor query is the exact mistake that caused the 2026-05-27 Corust miss (Rust-specialized AI editor SaaS, indexed on every Rust-AI listicle, invisible to a `"... open source github"`-qualified query). The user's idea may *be* "open source X", but the question the SaaS archetypes answer is "what does the market look like, OSS or not?" — those archetypes must look at the unfiltered market.

Construction rule: when building archetypes 1/2/5, **strip** the forbidden tokens from the sharpened sentence and preserved terms before substitution. If the resulting query becomes incoherent (e.g. the entire sharpened sentence was "open source"), fall back to the differentiator keywords for the domain noun.

Archetypes 3 (Awesome-list) and 4 (GitHub Marketplace) are GitHub-scoped by design and are exempt — they MAY use `github` / `site:github.com` since that's their entire point.

### Pre-emission self-check

Before emitting the verdict, the protocol MUST confirm:

1. At least 3 of the 5 archetype queries were SaaS-archetype queries (1, 2, 5) AND none of them contains a forbidden qualifier.
2. The candidate pool contains at least one `first-web-saas` candidate, OR the SaaS-archetype queries returned zero matching products (not zero results — zero *products*).

If either check fails, the protocol MUST re-issue the SaaS-archetype queries with the forbidden tokens stripped, BEFORE writing the report. A 🟢 verdict emitted without this check is a protocol violation, not a clean result.

## Filtering rules

For each WebSearch result:
- KEEP if the result's snippet contains AT LEAST one preserved term OR a verbatim variant of the differentiator keywords.
- DISCARD if the result is a generic blog post listing tools, unless it cites a specific product by name with URL.
- DISCARD if the URL is the user's own GithubPill repo or this skill's documentation.
- DEDUPE by canonical product name (case-insensitive).

## Verification

For each candidate URL:
- If it's a `github.com/<owner>/<repo>` URL → run `scripts/verify-repo.sh` on it. 404 = drop. Otherwise merge into the gh-candidate pool with `provenance=first-web`.
- If it's a non-GitHub URL (SaaS landing page, YC profile, etc.) → it counts as a `web_candidate` with `provenance=first-web-saas`. Do NOT cite this URL in the report header without `verified_at` from a successful WebSearch result; treat as "found-not-verified-equivalence".

### Non-GitHub URL verification (v0.3.0)

For each `web_candidate.url` that is NOT `github.com/...`:

1. Run `bash $PLUGIN_ROOT/scripts/verify-url.sh "<url>"`.
2. On exit 0: tag `provenance=first-web-saas`, attach the returned JSON
   (`http_code`, `final_url`, `checked_at`). Keep in the SaaS pool.
3. On exit 20/21/22/23: DROP the candidate entirely. Log the drop reason in
   the report's "Closed-Source / SaaS Discovery" section under a
   "Candidates dropped (unreachable)" subsection so the user knows what was filtered.
4. On exit 1: treat as 22 (drop). Do not retry.

This catches hallucinated SaaS competitors from WebSearch SEO spam. Without
this gate, a model-fabricated landing-page URL could leak into the report
unverified.

## Why this is mandatory in first search, not deep search

The closed-source case is the **dominant** failure mode for the v0.1.0 protocol. Holding it back behind deep search opt-in meant 🟢 verdicts on already-saturated lanes (Idea 2 in user testing: Ellipsis, CodeRabbit Autofix, Sweep, Greptile all missed). deep search stays for clone-inspection depth; web cross-check is breadth.

## Output Discipline

- Web-candidate URLs that are NOT github.com appear in a separate "Closed-Source / SaaS Competitors" report block (see `report-template.md`).
- Web-candidate URLs that ARE github.com are merged into the regular candidate pool with provenance tag.
- The first search overall verdict considers BOTH gh-candidates and web-candidates. A strong closed-source competitor with ≥3 axis matches against the sharpened sentence is a 🔴 even with zero gh candidates.
