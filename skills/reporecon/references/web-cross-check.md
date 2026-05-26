# Web Cross-Check Protocol (Tier 1 baseline)

**Purpose.** Catch competitors that don't appear in `gh api search/repositories` — closed-source SaaS, YC startups, GitHub Apps, GitHub Marketplace Actions, well-known products buried in awesome-list curations.

This protocol runs ONCE in Tier 1 immediately after the gh-search discovery step. It is NOT optional. Skipping it reintroduces the v0.1.0 blind spot.

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
  "source_query": "<the WebSearch query that surfaced it>"
}
```

Candidates whose URL is a `github.com/<owner>/<repo>` link MUST be additionally verified via `scripts/verify-repo.sh` and merged into the gh-candidate pool (provenance: "tier1-web" rather than tier1-gh).

## Required searches (5 queries, single batch)

Generate exactly 5 WebSearch queries in ONE LLM call (temperature 0). Each must use at least one preserved term verbatim. Map archetypes:

1. **Canonical-product** — name-based: `"<idea-domain> AI tool"` OR `"best <idea-domain> agent 2026"`. Bias toward product names.
2. **YC + funded startups** — `"<sharpened sentence> YC startup"` OR `"<sharpened sentence> seed funded 2025 2026"`.
3. **Awesome-list traversal** — `awesome <domain>` OR `awesome <preserved-term>` (e.g. `awesome-llm-agents`, `awesome-gmail-automation`). Models should mine the README of the top hit.
4. **GitHub Marketplace + GitHub Apps** — `site:github.com/marketplace "<domain>"` OR `"GitHub App" <sharpened sentence>`.
5. **HN / Product Hunt** — `site:news.ycombinator.com "<sharpened sentence>"` OR `site:producthunt.com "<domain>"`.

If any query returns nothing useful, the model MAY substitute a tighter variant ONCE. Do not exceed 5 WebSearch calls total per Tier 1 run.

## Filtering rules

For each WebSearch result:
- KEEP if the result's snippet contains AT LEAST one preserved term OR a verbatim variant of the differentiator keywords.
- DISCARD if the result is a generic blog post listing tools, unless it cites a specific product by name with URL.
- DISCARD if the URL is the user's own RepoRecon repo or this skill's documentation.
- DEDUPE by canonical product name (case-insensitive).

## Verification

For each candidate URL:
- If it's a `github.com/<owner>/<repo>` URL → run `scripts/verify-repo.sh` on it. 404 = drop. Otherwise merge into the gh-candidate pool with `provenance=tier1-web`.
- If it's a non-GitHub URL (SaaS landing page, YC profile, etc.) → it counts as a `web_candidate` with `provenance=tier1-web-saas`. Do NOT cite this URL in the report header without `verified_at` from a successful WebSearch result; treat as "found-not-verified-equivalence".

## Why this is mandatory in Tier 1, not Tier 2

The closed-source case is the **dominant** failure mode for the v0.1.0 protocol. Holding it back behind Tier 2 opt-in meant 🟢 verdicts on already-saturated lanes (Idea 2 in user testing: Ellipsis, CodeRabbit Autofix, Sweep, Greptile all missed). Tier 2 stays for clone-inspection depth; web cross-check is breadth.

## Output Discipline

- Web-candidate URLs that are NOT github.com appear in a separate "Closed-Source / SaaS Competitors" report block (see `report-template.md`).
- Web-candidate URLs that ARE github.com are merged into the regular candidate pool with provenance tag.
- The Tier 1 overall verdict considers BOTH gh-candidates and web-candidates. A strong closed-source competitor with ≥3 axis matches against the sharpened sentence is a 🔴 even with zero gh candidates.
