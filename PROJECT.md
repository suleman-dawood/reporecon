# RepoRecon — Reconnaissance Before You Build

> Claude Code skill that validates whether your project idea already exists on GitHub before you build it. Dual search (web + GitHub API), shallow clone inspection, LLM-judged equivalence.

---

## Problem

Developers waste weeks building projects that already exist. The research process is broken:

1. **GitHub search is bad at discovery** — only searches names/descriptions/topics, misses most results
2. **LLMs hallucinate repos** — confidently cite repositories that return 404
3. **READMEs lie** — repos claim features they don't implement
4. **Web search finds things GitHub search misses** — blog posts, commercial tools, GitLab repos, Reddit threads
5. **Nobody verifies** — people cite a repo without checking if it actually exists or does what it claims
6. **Repos get retired** — a project from 3 months ago may be archived or absorbed

### Origin Story

Born from a real 3-hour research session where:
- 7 "unique" project ideas were proposed by an LLM
- Verification revealed 5 already existed
- The verification itself was challenged — and 3 of those corrections were wrong (fabricated repos, wrong star counts)
- Two different methods (WebFetch vs `gh api`) returned different star counts for the same repo
- A cited competitor repo had existed in March 2026 but was retired by April 2026

The tool that would have caught all of this is the tool we're building.

---

## Format

**Claude Code skill (primary).** Not a standalone CLI.

Claude Code already provides everything needed:
- `gh` CLI for GitHub API verification
- WebSearch for broad discovery
- Bash for `git clone --depth 1` + code inspection
- Read tool for file analysis
- LLM reasoning for equivalence judgment

RepoRecon adds: a structured protocol, enforced verification steps, and a consistent report format. The skill ensures you never skip the steps humans skip when researching manually.

---

## Core Workflow

```
User: /reporecon "open-source NDIS invoice validator for Australian healthcare"
                                    |
                 1. GENERATE — 10-15 diverse search queries
                                    |
                 2. DISCOVER — WebSearch for broad discovery
                    (blogs, Reddit, HN, commercial tools, GitLab)
                                    |
                 3. VERIFY — gh api for every repo cited
                    (confirm 200, get stars/activity/last commit)
                                    |
                 4. INSPECT — git clone --depth 1 top candidates
                    (check actual code, not just README claims)
                                    |
                 5. JUDGE — LLM evaluates equivalence per candidate
                    (EXACT / SIGNIFICANT / PARTIAL / SUPERFICIAL / NONE)
                                    |
                 6. REPORT — what exists, what's missing, your angle
```

---

## Scope

### In Scope (MVP)

**Step 1 — Query Generation**
- Take natural language project description
- Generate 10-15 diverse search queries covering:
  - Direct terms ("NDIS invoice validator")
  - Synonyms ("NDIS billing checker", "NDIS claim compliance")
  - Technology-specific ("python NDIS validator fastapi")
  - Domain-adjacent ("australian healthcare billing open source")
  - Negation queries to find competitors ("NDIS software comparison")

**Step 2 — Broad Discovery (WebSearch)**
- Search web for each query — catches things GitHub search misses:
  - Blog posts / Show HN / Reddit threads
  - Commercial tools (AussieSmart, Flowely, etc.)
  - GitLab / SourceForge / Codeberg repos
  - Academic papers with linked code
  - Archived/renamed repos Google still indexes
- Extract all candidate repo URLs + tool URLs

**Step 3 — GitHub API Verification**
- Every repo URL gets `gh api repos/OWNER/REPO`
- Fetch: stars, forks, last commit, language, archived status, description, topics
- If 404 → flag as UNVERIFIED (may be retired, renamed, or hallucinated)
- Timestamp every check

**Step 4 — Shallow Clone Inspection**
- Top 5-8 candidates: `git clone --depth 1` into temp directory
- Check actual code, not just README:
  - File count and structure (is this a real project or a skeleton?)
  - Source code presence (does `/src` or `/lib` have actual logic?)
  - Test presence (does the repo test its claimed features?)
  - Last meaningful code change (not just README edits)
  - Single-file repos vs full implementations
- Clean up clones after inspection

**Step 5 — Equivalence Judgment**
- LLM evaluates each candidate against proposed project:
  - **EXACT_MATCH** — does the same thing, same audience, active
  - **SIGNIFICANT_OVERLAP** — 60%+ feature overlap, would compete directly
  - **PARTIAL_OVERLAP** — shares some features but different scope/audience
  - **SUPERFICIAL_MATCH** — same domain, different problem
  - **VAPOR** — claims to do it but code is empty/abandoned
- Must cite evidence: specific files, features present/absent

**Step 6 — Report Generation**
- Verdict: UNIQUE / PARTIALLY_EXISTS / ALREADY_EXISTS
- Per-candidate breakdown with overlap score + evidence
- "Your unique angle" — what specifically hasn't been built
- Suggested pivot if idea is taken
- All data timestamped

### Out of Scope (v1)

- Continuous monitoring / cron re-checks
- Dependency graph comparison (low signal, high effort)
- npm / PyPI / crates.io package search
- Patent / academic paper search
- Market / business validation
- Historical tracking database

---

## Features

| Feature | What It Does | Why It Matters |
|---------|-------------|---------------|
| **Dual Search** | WebSearch for discovery + `gh api` for verification | GitHub search alone misses 60%+ of competitors |
| **Clone Inspection** | Shallow clone + read actual source code | READMEs lie. Code doesn't. |
| **404 Detection** | Verify every cited repo actually exists | LLMs hallucinate repos constantly |
| **Staleness Flags** | Flag archived, abandoned (>12mo), single-commit repos | Dead repos aren't real competition |
| **Evidence-Based Judgment** | Cite specific files/features, not just "looks similar" | Prevents false positives and false negatives |
| **Timestamped Reports** | Every data point has a check timestamp | Reports degrade — timestamps show freshness |
| **Vapor Detection** | Flag repos with big READMEs but no actual code | Common on GitHub — aspirational repos |

---

## Deliverables

### Phase 1 — Core Skill (Week 1)

- [ ] SKILL.md with trigger phrases and protocol
- [ ] Query generation prompt (NL → 10-15 search queries)
- [ ] Discovery phase (WebSearch with result extraction)
- [ ] Verification phase (`gh api` for each candidate)
- [ ] Clone inspection phase (`git clone --depth 1` + analysis)
- [ ] Equivalence judgment prompt (tuned for accuracy)
- [ ] Report template (markdown)
- [ ] 3 test cases from real sessions (NDIS, FSANZ, bot classifier)

### Phase 2 — Polish + Distribution (Week 2)

- [ ] plugin.json + package.json for npm distribution
- [ ] Vapor detection logic (README size vs code size ratio)
- [ ] Staleness scoring (last commit, issues, releases)
- [ ] Error handling (rate limits, private repos, clone failures)
- [ ] README with demo showing full workflow
- [ ] Example reports from real validations
- [ ] Blog post draft: "How I validated 7 project ideas and found only 1 was unique"

---

## Stakeholders

### Who Uses This

| Segment | Use Case |
|---------|----------|
| **Indie devs** | "Does my weekend project idea already exist?" |
| **Junior devs building portfolios** | Ensure projects stand out (our exact use case) |
| **Hackathon participants** | Validate originality in minutes |
| **Open source contributors** | Find genuine gaps to fill |
| **Claude Code users** | Natural fit — install and invoke |

### Who to Show It To

| Target | Why |
|--------|-----|
| **Claude Code skill ecosystem** | Complementary to career-ops, research-companion |
| **Indie Hackers / HN community** | They obsess over "has this been built" |
| **Dev Twitter/LinkedIn** | The origin story is inherently shareable |
| **r/SideProject, r/opensource** | Direct audience |

---

## Data Sources

| Source | Used In | How |
|--------|---------|-----|
| **WebSearch** | Step 2 — Discovery | Broad web search for repos, tools, blog posts |
| **GitHub API (`gh api`)** | Step 3 — Verification | Authoritative repo metadata |
| **GitHub Contents API** | Step 4 — Inspection | README, file tree via API |
| **`git clone --depth 1`** | Step 4 — Inspection | Actual source code analysis |

No paid APIs. No external services. Everything runs through Claude Code's built-in tools + `gh` CLI.

---

## Tech Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| **Format** | Claude Code Skill (SKILL.md) | Zero-friction distribution, `npx` install |
| **Discovery** | WebSearch (Claude Code built-in) | Broad reach, catches non-GitHub results |
| **Verification** | `gh` CLI | Authenticated, authoritative, rate-limit-aware |
| **Inspection** | `git clone --depth 1` + Read tool | Actual code analysis, not README claims |
| **Judgment** | Claude (host model) | Already available in Claude Code — zero cost |
| **Reports** | Markdown files | Readable, versionable, shareable |
| **Temp storage** | `/tmp/reporecon/` | Clone targets, cleaned up after |

### What's NOT in the stack (and why)

| Dropped | Why |
|---------|-----|
| SQLite cache | Premature for v1 — add if rate limits become a problem |
| Dependency parser | Low signal for the effort (knowing they use Flask doesn't matter) |
| Standalone Python CLI | Skill-first. CLI only if there's demand. |
| Cron / monitoring | Out of scope — this is a point-in-time check, not a dashboard |

---

## Skill Structure

```
reporecon/
  SKILL.md                      # Skill definition, protocol, trigger phrases
  plugin.json                   # Claude Code plugin metadata
  package.json                  # npm distribution
  README.md                     # Install instructions + demo
  examples/
    ndis-validator-report.md    # Real report: NDIS validator research
    fsanz-checker-report.md     # Real report: FSANZ checker research
    bot-classifier-report.md    # Real report: bot classifier (ALREADY_EXISTS)
```

### SKILL.md Core Protocol

```markdown
## Protocol (enforced every run)

1. NEVER cite a repo without verifying via `gh api repos/OWNER/REPO`
2. NEVER trust star counts from web scraping — only `gh api`
3. ALWAYS use WebSearch for discovery (GitHub search misses too much)
4. ALWAYS shallow-clone top candidates and inspect actual code
5. ALWAYS flag repos that return 404 as UNVERIFIED
6. ALWAYS timestamp every data point in the report
7. ALWAYS check: does the code actually implement what the README claims?
8. NEVER say "nothing exists" without running 10+ diverse queries
```

---

## Report Format

```markdown
# RepoRecon Report
**Idea:** [user's project description]
**Checked:** 2026-05-19T12:00:00Z
**Queries run:** 12
**Candidates found:** 23
**Verified repos:** 8
**Cloned & inspected:** 5

## Verdict: PARTIALLY_EXISTS

## Prior Art Found

### 1. AussieSmart NDIS Invoice Validator
- **Type:** Commercial web tool (not on GitHub)
- **Found via:** WebSearch
- **Overlap:** PARTIAL (35%)
- **Does:** Single line-item price cap check, legacy code flagging
- **Doesn't do:** Bulk CSV, budget tracking, CLI/API, open source
- **Verified:** N/A (commercial tool, no repo)

### 2. Pwnion/NDIS-Doc-Parser
- **URL:** github.com/Pwnion/NDIS-Doc-Parser
- **Verified:** ✅ 200 OK at 2026-05-19T12:01:00Z
- **Stars:** 1 | **Last commit:** 2022-04-03 | **Status:** ABANDONED
- **Overlap:** SUPERFICIAL (10%)
- **Cloned:** Yes
- **Code inspection:** 2 Python files, 147 lines total. Parses Word
  documents for data transfer. No validation logic. No tests.
- **Verdict:** VAPOR — name suggests overlap but code doesn't deliver

## Your Unique Angle

✅ Bulk CSV/XLSX validation (no repo does this)
✅ Regional multiplier-aware price caps (no repo does this)
✅ Participant budget tracking (no repo does this)
✅ CLI/API access (no repo does this)
⚠️ Single-item price check (AussieSmart does this, but web-only + closed)

## Recommendation

**BUILD** — position as bulk + OSS + budget tracking.
Don't compete with AussieSmart on single-item checks.
```

---

## Dogfooding

RepoRecon validates the other two portfolio projects:
- Run on **LabelLens** → confirm FSANZ gap is still real
- Run on **NDISBulkValidator** → confirm narrow angle holds
- Include both reports as `examples/` in the repo

This creates the README story: "Here's the tool, and here are two real projects it validated."

---

## LinkedIn Pitch

> "I spent 3 hours researching whether my project idea existed on GitHub. The LLM hallucinated repos. Web scraping returned wrong star counts. A cited competitor had been retired a month earlier.
>
> So I built RepoRecon — a Claude Code skill that does project prior-art research properly. Web search for discovery, GitHub API for verification, shallow clone to check if the code is real, and LLM judgment on whether it's actually the same thing.
>
> It found that 5 of my 7 'unique' ideas already existed. The 2 that survived are now in development."
