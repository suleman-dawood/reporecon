# Feature Research

**Domain:** Idea-validation / repo-discovery / competitor-recon tooling for developers
**Researched:** 2026-05-26
**Confidence:** HIGH (domain is well-bounded by PROJECT.md; competitor space surveyed in brainstorming)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels broken or untrustworthy in this niche.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Natural-language idea input | Users will not pre-formulate boolean queries; the whole point is "describe vaguely, get results" | LOW | Single string into a skill trigger; LLM does normalization. |
| Multi-query expansion from one idea | Single-keyword search is what GitHub already offers and fails at; users assume an LLM tool will diversify | LOW | 5 queries Tier 1, 10-15 Tier 2 (per PROJECT.md). |
| GitHub repo metadata (stars, forks, last push, archived flag, language) | Standard recon signal; without it users can't gauge seriousness of a match | LOW | `gh api repos/OWNER/REPO`; cache per run. |
| 404 / existence verification | LLMs hallucinate repo URLs constantly; an idea-validation tool that cites dead repos is worthless | LOW | Hard requirement — flag any unverified candidate as UNVERIFIED. |
| Ranked candidate list (not raw dump) | Users want a verdict, not 50 links to read themselves | MEDIUM | LLM ranks by relevance + activity; top-5 surfaced. |
| Markdown report output | Devs expect copy-pasteable, versionable artifacts (vs. ephemeral chat) | LOW | `./reporecon-reports/YYYY-MM-DD-<slug>.md`. |
| Timestamped data points | Users will revisit reports weeks later; without timestamps the report decays silently | LOW | ISO-8601 on every metadata fetch and on the report header. |
| Staleness signals (archived, last commit > N months) | Dead repos shouldn't count as "this already exists" | LOW | Mechanical thresholds per PROJECT.md (archived, >12mo, single-contributor + >6mo). |
| Per-candidate evidence (not vibes) | Users won't trust a verdict without seeing why; LLM "looks similar" is rejected | MEDIUM | File-paths, line counts, README excerpts cited inline. |
| Quick verdict mode (< ~90s) | If it takes 10 minutes to answer "does this exist?", users won't run it before every idea | MEDIUM | Tier 1 path; metadata-only LLM rating. |
| Safe local cloning (no junk left over) | Devs hate tools that pollute home dir or fill disk | LOW | `/tmp/reporecon/<run-id>/`, depth-1, size guard, cleanup. |
| Authenticated `gh` usage | Unauthed rate limits (60/hr) make a usable tool impossible; users already have `gh auth login` | LOW | Document as prereq; fail fast with a clear message. |

### Differentiators (Competitive Advantage)

Closest existing tools: SimilarGit / RepoPal / ghindex (repo→similar-repos, NOT idea→repos), GitHub native search (keyword-only, no LLM judgment), generic ChatGPT/Claude "find me competitors" (hallucination-prone, no verification). RepoRecon's wedge is **idea-driven discovery + verification + clone inspection + structured equivalence judgment**.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Two-tier output (fast verdict + opt-in deep dive)** | Solves the "fast answer vs. thorough answer" tradeoff that forces other tools to pick one. 80% of queries resolve in Tier 1. | MEDIUM | Tier 1 ~90s metadata-only; Tier 2 ~10min with clones. Core architectural decision. |
| **5-axis structured rubric (core function / audience / scope / approach / activity)** | Replaces "vibes-based" LLM judgment with axis scores → derived verdict. Cuts non-determinism between runs. | MEDIUM | Verdict (EXACT / SIGNIFICANT / PARTIAL / SUPERFICIAL / VAPOR) computed from axis scores, not asked directly. |
| **Evidence-cited verdicts with file paths or URLs** | Distinguishes "looks similar" from "actually does the same thing"; required for ≥ PARTIAL_OVERLAP rating | MEDIUM | Judge prompt rejects verdicts lacking file-path/URL evidence. |
| **Mechanical vapor heuristic** | Catches "aspirational" repos with big READMEs and no code — a pattern LLM-only tools miss | LOW | ≥3 README claims AND ≤5 source files (OR archived OR >18mo stale). Mechanical, repeatable. |
| **Mechanical staleness flags** | Removes LLM judgment from "is this repo dead" — answer is the same every run | LOW | archived, pushed_at >12mo, single-contributor + >6mo. |
| **Negative-space report ("your angle")** | Most tools tell you what exists; this tells you what *doesn't*. Inverts the value prop from "should I quit?" to "where's the gap?" | MEDIUM | Diffs user's idea features against union of inspected candidate features. |
| **Idea sharpening pre-step** | Forces "what / for whom / how" + 3-5 differentiators before search → measurably better queries and a clearer report frame | LOW | LLM restates input in fixed schema; user implicitly confirms by continuing. |
| **Clone inspection of actual source (not just README)** | READMEs lie. Code doesn't. SimilarGit/RepoPal/ghindex never read code — they work on metadata + topics. | MEDIUM | Depth-1 clone, count source files, read selected files, judge code-vs-claims. |
| **WebSearch + GitHub API dual discovery (Tier 2)** | GitHub search alone misses commercial tools, GitLab repos, blog posts, archived projects. Per origin story this is where most misses happen. | MEDIUM | Tier 2 only; Tier 1 stays GitHub-only for speed. |
| **Confirmation-bias-resistant judge prompt** | The user *wants* their idea to be unique. A judge that capitulates to that bias is worthless. | LOW | Prompt explicitly instructs the model to resist pressure toward novelty verdicts. |
| **Claude Code plugin packaging (marketplace distribution)** | Zero-friction install via marketplace; bundles skill + references + helper scripts as one unit | MEDIUM | `plugin.json` + `marketplace.json` + `package.json` + README. |
| **Helper bash scripts wrapping `gh api` and `git clone`** | Stable interfaces shield the skill prompt from CLI flag churn; testable separately | LOW | Safe-clone wrapper (depth-1, 50MB guard, timeout, cleanup) is highest-value. |
| **Golden test cases (saturated / empty / ambiguous domain)** | Regression safety for a tool whose outputs are LLM-judged; also doubles as marketing examples | MEDIUM | 3 cases per PROJECT.md. Reusable as `examples/` in marketplace listing. |

### Anti-Features (Commonly Requested, Often Problematic)

Features users will ask for. Each is deliberately excluded from v1 with a reason.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Pre-indexed embeddings of GitHub repos | "Wouldn't semantic search be faster / better?" | Infra burden (corpus pipeline, vector DB, refresh cadence), staleness, cost — kills the "zero external services" property | Runtime query expansion + 404 verification covers the 80% case at zero infra cost. |
| MCP server distribution | "Plugins are limited; MCP is the new hotness" | Splits effort across two distribution targets; marketplace is the chosen wedge; MCP adds a long-running process and host-compat matrix | Ship plugin first; revisit MCP only if users explicitly ask. |
| GitLab / Codeberg / Sourcehut / Bitbucket sources | "GitHub-only feels incomplete" | Each new source = new auth, new API, new rate limits, new judgment edge cases. ~80% of OSS projects are on GitHub. | GitHub-only v1; mention Tier 2 WebSearch will surface non-GitHub mentions anyway. |
| npm / PyPI / crates.io package search | "Some competitors only ship as packages" | Different ecosystem semantics (a package ≠ a project); doubles the LLM judgment surface area | Package mentions surface via Tier 2 WebSearch; explicit package search deferred. |
| Result caching by idea-hash | "Re-running the same idea is slow" | Premature optimization; cache invalidation is nontrivial (repos move/archive); pollutes initial UX with cache-management surface | Add in v1.1 if telemetry shows re-runs are common. |
| Async / background mode | "Don't block my chat for 10 minutes" | Tier 1/Tier 2 split already solves this; async adds a job-state surface and result-delivery channel | Two-tier output. User runs Tier 1 in flow, opts into Tier 2 when they actually need it. |
| Local-only / privacy mode (no WebSearch) | "I don't want my idea sent to a search engine" | Real concern but not validated yet; building privacy plumbing pre-validation = wasted effort | Defer until users actually ask. Document data flow honestly in README. |
| Auto-monitoring / weekly re-runs | "Tell me when a competitor ships" | Turns a point-in-time skill into a service with state, cron, and notification channels | Out of v1. RepoRecon is a recon tool, not a watchdog. |
| Standalone CLI (`npx reporecon`) or `gh` extension | "Not everyone uses Claude Code" | Doubles surface; the *value* is LLM judgment which requires a host model anyway | Plugin-only v1. CLI wrapper only if Claude-Code-less demand materializes. |
| Commercial / SaaS competitor detection | "Sometimes the real competitor isn't on GitHub" | Can't be verified the way GitHub repos can (no `gh api` equivalent); judgment becomes "trust the LLM" | Tier 2 WebSearch surfaces them in the report as unverifiable mentions, with that limitation flagged. |
| Dependency-graph comparison | "If two repos share deps they're probably similar" | Low signal (everyone uses Flask), high effort (parse multiple ecosystems), false positives | Source-code inspection answers the same question more directly. |
| Free-form LLM verdicts | "Just ask the LLM if they're the same" | Non-deterministic; flips between runs; users lose trust the first time it flips on them | 5-axis rubric → derived verdict. Mechanical heuristics for vapor/staleness. |
| Single combined "do everything" mode | "Why split into two tiers? Just always run the full thing." | Kills the <90s property that makes the tool usable in-flow; conflates two different user intents | Two tiers stay separate. Tier 2 is opt-in. |

## Feature Dependencies

```
[Idea sharpening]
    └──feeds──> [Query generation]
                    └──feeds──> [Tier 1: gh api search × 5]
                                    └──feeds──> [Metadata-only LLM rating]
                                                    └──feeds──> [5-axis rubric] ──derives──> [Verdict]
                                                                    └──feeds──> [Markdown report]

[Tier 1 verdict] ──opt-in gate──> [Tier 2: WebSearch + expanded queries]
                                       └──feeds──> [Safe clone wrapper]
                                                       └──feeds──> [Source inspection]
                                                                       └──feeds──> [Evidence-cited equivalence judgment]
                                                                                       └──feeds──> [Negative-space report]

[Mechanical vapor heuristic] ──enhances──> [5-axis rubric]
[Mechanical staleness flags] ──enhances──> [5-axis rubric]
[Confirmation-bias-resistant prompt] ──enhances──> [Equivalence judgment]

[Plugin packaging] ──requires──> [SKILL.md + helper scripts stable]
[Marketplace submission] ──requires──> [Plugin packaging + golden tests + README demo]

[Embeddings index] ──conflicts──> [Zero-infra constraint]
[MCP server] ──conflicts──> [Plugin-only v1 distribution]
[Async mode] ──conflicts──> [Two-tier design]
```

### Dependency Notes

- **Idea sharpening → Query generation:** Sharpened "what/for whom/how" + differentiator keywords are what make 5 queries *diverse* instead of 5 rewordings of the same string.
- **Query generation → Tier 1 search:** Tier 1's <90s budget assumes ~5 queries × 1 `gh api` call each; query quality is the bottleneck on result quality, not query count.
- **5-axis rubric → Verdict:** Verdict label is *derived* from axis scores, not asked directly of the LLM. This is what gives the tool repeatability.
- **Mechanical heuristics enhance rubric:** Vapor and staleness are computed mechanically, then *injected* as axis-activity signals so the LLM never gets to "feel" them.
- **Tier 2 requires Tier 1:** Tier 2 is gated on the user accepting an opt-in prompt after seeing the Tier 1 verdict. Building Tier 2 without Tier 1 has no user path.
- **Safe clone wrapper precedes source inspection:** Inspecting code requires clones to exist, be size-bounded, and be cleaned up; the wrapper is a hard prerequisite for Phase 2.
- **Marketplace submission is terminal:** Needs packaging + tests + README demo + dogfooded example reports. It's the last step, not parallelizable with earlier phases.
- **Embeddings / MCP / async / extra sources conflict with stated v1 constraints** — they aren't deferred features, they're rejected ones.

## MVP Definition

### Launch With (v1)

Minimum viable product — the smallest thing that delivers a trustworthy evidence-cited verdict.

- [ ] **Idea sharpening step** — without it, downstream query quality collapses
- [ ] **5 diverse `gh api` search queries from one idea** — the core "fuzzy idea → candidates" jump
- [ ] **404 verification on every cited repo** — non-negotiable; the origin story is hallucinated repos
- [ ] **Metadata fetch (stars, last push, archived, language, topics)** — basic recon signal
- [ ] **Mechanical staleness flags** — repeatable, no LLM cost
- [ ] **Mechanical vapor heuristic** — distinguishes "aspirational" from "real"
- [ ] **5-axis rubric → derived verdict (EXACT / SIGNIFICANT / PARTIAL / SUPERFICIAL / VAPOR)** — replaces vibe-judgment
- [ ] **Tier 1 markdown report (<90s)** — proves the in-flow use case
- [ ] **Tier 2: WebSearch + expanded queries + shallow clone + source inspection** — proves the deep use case
- [ ] **Evidence-cited equivalence judgment (file paths or URLs required)** — the trust mechanism
- [ ] **Negative-space "your angle" section** — flips the value prop from "quit" to "ship sharper"
- [ ] **Safe clone wrapper (depth-1, 50MB guard, timeout, /tmp cleanup)** — safety prereq for Tier 2
- [ ] **Confirmation-bias-resistant judge prompt** — protects the trust property
- [ ] **Report written to `./reporecon-reports/YYYY-MM-DD-<slug>.md`** — versionable artifact
- [ ] **Plugin packaging (`plugin.json`, `marketplace.json`, `package.json`, README)** — distribution channel
- [ ] **3 golden test cases (saturated / empty / ambiguous)** — regression safety + marketing
- [ ] **Marketplace submission** — only way users actually find it

### Add After Validation (v1.x)

Trigger-driven additions.

- [ ] **Result caching by idea-hash** — trigger: telemetry/feedback shows re-runs are common
- [ ] **Local-only privacy mode** — trigger: ≥3 unsolicited user requests
- [ ] **Per-user rubric weight overrides** — trigger: users report axis priorities differ by domain
- [ ] **Richer source-code heuristics (test density, doc density)** — trigger: false positives on vapor verdict
- [ ] **CLI / `gh` extension wrapper** — trigger: demand from non-Claude-Code users

### Future Consideration (v2+)

Deferred until product-market fit is proven.

- [ ] **Multi-source (GitLab / Codeberg)** — only after GitHub-only PMF is solid
- [ ] **Package registry search (npm / PyPI / crates)** — only after demand is measured
- [ ] **Embeddings-based pre-indexed search** — only if Tier 1 latency or quality plateaus
- [ ] **MCP server build** — only if Claude Code plugin ceiling is hit
- [ ] **Auto-monitoring / weekly re-runs** — turns the tool into a service; defer until validated
- [ ] **Commercial/SaaS competitor detection** — needs a different verification model entirely

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Idea sharpening step | HIGH | LOW | P1 |
| Tier 1 quick verdict (<90s) | HIGH | MEDIUM | P1 |
| 404 verification | HIGH | LOW | P1 |
| 5-axis rubric → derived verdict | HIGH | MEDIUM | P1 |
| Mechanical staleness flags | MEDIUM | LOW | P1 |
| Mechanical vapor heuristic | HIGH | LOW | P1 |
| Evidence-cited verdicts | HIGH | MEDIUM | P1 |
| Safe clone wrapper | HIGH | LOW | P1 |
| Tier 2 deep inspection | HIGH | HIGH | P1 |
| Negative-space report | HIGH | MEDIUM | P1 |
| Markdown report output | MEDIUM | LOW | P1 |
| Confirmation-bias-resistant judge prompt | HIGH | LOW | P1 |
| Plugin packaging | HIGH | MEDIUM | P1 |
| 3 golden tests | MEDIUM | MEDIUM | P1 |
| Marketplace submission | HIGH | LOW | P1 |
| Result caching | MEDIUM | MEDIUM | P2 |
| Privacy / local-only mode | MEDIUM | HIGH | P2 |
| CLI / `gh` extension | LOW | MEDIUM | P3 |
| Embeddings index | MEDIUM | HIGH | P3 |
| MCP server | LOW | HIGH | P3 |
| Multi-source (GitLab etc.) | MEDIUM | HIGH | P3 |
| Package registry search | MEDIUM | HIGH | P3 |
| Auto-monitoring | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for v1 launch
- P2: Add post-launch when triggers met
- P3: Defer until PMF / explicit demand

## Competitor Feature Analysis

| Feature | SimilarGit / RepoPal / ghindex | GitHub native search | Generic LLM "find competitors" | RepoRecon |
|---------|-------------------------------|----------------------|--------------------------------|-----------|
| Input type | Existing repo URL | Keyword string | NL description | **NL description (sharpened)** |
| Query expansion | None (single repo embedding) | None | Ad-hoc | **5-15 structured diverse queries** |
| 404 verification | N/A (uses indexed data) | N/A | **None — hallucinates** | **Every cited repo via `gh api`** |
| Metadata freshness | Stale (depends on index) | Live | Stale (training data) | **Live (per-run fetch)** |
| Source-code inspection | None | None | None | **Depth-1 clone + Read** |
| Vapor detection | None | None | None | **Mechanical heuristic** |
| Staleness detection | Partial (sometimes star/date) | None | None | **Mechanical thresholds** |
| Equivalence judgment | Embedding similarity score | Keyword match | Free-form LLM | **5-axis rubric → derived verdict** |
| Evidence in output | Score only | Repo list | Prose | **File paths + URLs cited** |
| Negative-space ("your angle") | None | None | Sometimes (unstructured) | **Dedicated report section** |
| Two-tier (fast + deep) | Single mode | Single mode | Single mode | **Tier 1 ~90s, Tier 2 ~10min** |
| Confirmation-bias guard | N/A | N/A | None | **Explicit in judge prompt** |
| Distribution | Web app / API | Built into GitHub | None (one-off chats) | **Claude Code marketplace plugin** |
| Privacy of idea | Idea not sent (repo-input) | Public search | Sent to LLM provider | Sent to host LLM + WebSearch (Tier 2) |

**Wedge summary:** the *combination* idea-input + verified candidates + clone inspection + structured rubric + evidence + negative-space + two-tier UX has no direct competitor. Each individual feature exists somewhere; none of the competitors compose them.

## Sources

- `/home/suleman/Documents/Projects/AI_Projects/RepoRecon/PROJECT.md` (idea document, brainstorming origin story, deliverables, scope decisions)
- `/home/suleman/Documents/Projects/AI_Projects/RepoRecon/.planning/PROJECT.md` (validated requirements, out-of-scope rationale, key decisions table)
- Competitor space surveyed in brainstorming session 2026-05-26 (SimilarGit, RepoPal, ghindex, GitHub native search) — referenced in PROJECT.md Context section
- Domain conventions for Claude Code skill/plugin packaging (SKILL.md + plugin.json + marketplace.json), per Claude Code marketplace requirements

---
*Feature research for: idea-validation / repo-discovery / competitor-recon tooling*
*Researched: 2026-05-26*
