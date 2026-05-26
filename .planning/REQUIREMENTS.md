# Requirements: RepoRecon

**Defined:** 2026-05-26
**Core Value:** Given a fuzzy project idea, return a trustworthy, evidence-cited verdict on whether it already exists on GitHub — fast enough not to interrupt flow, deep enough to act on.

## v1 Requirements

### Packaging

- [ ] **PKG-01**: Plugin installs from a single GitHub repo via Claude Code marketplace using `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`
- [ ] **PKG-02**: `package.json` declares plugin metadata (name, version, description, author, license, repository) for marketplace discovery
- [ ] **PKG-03**: README.md includes install instructions, prerequisites (`gh auth login`, optional `bash`/`coreutils` on macOS), and a usage demo
- [ ] **PKG-04**: Plugin trigger phrase `/reporecon` is unique and not colliding with built-in commands
- [ ] **PKG-05**: License file (MIT) committed at repo root

### Input & Sharpening

- [ ] **INP-01**: Skill triggers on phrases like "is there already a tool that does X", "validate my idea", or `/reporecon X`
- [ ] **INP-02**: Free-form natural language idea accepted as input (no specific format required)
- [ ] **INP-03**: Idea sharpening step restates input as one-sentence "what / for whom / how" + 3-5 differentiator keywords
- [ ] **INP-04**: Sharpening preserves proper nouns (e.g., NDIS, FSANZ, HIPAA) without paraphrasing them away
- [ ] **INP-05**: Sharpened statement displayed in report header for user visibility

### Tier 1 — Quick Verdict (≤90s)

- [ ] **T1-01**: Generates 5 diverse queries (literal, synonym-shifted, outcome-framed, tech-stack-framed, adjacent-domain)
- [ ] **T1-02**: Preflight check runs `gh auth status` and `gh api rate_limit`; aborts with friendly error if unauthed or near-limit
- [ ] **T1-03**: Uses `gh api search/repositories` only (no WebSearch in Tier 1)
- [ ] **T1-04**: Verifies top 5 unique candidates exist via `gh api /repos/{owner}/{name}` (no candidate cited without 200 OK in the run)
- [ ] **T1-05**: Fetches metadata: stars, last-pushed, archived flag, default branch, primary language
- [ ] **T1-06**: Tier 1 judge rates each candidate as `LIKELY_MATCH / WORTH_INSPECTING / UNRELATED` on README + metadata only (no clones)
- [ ] **T1-07**: Produces a verdict block: 🟢 No close match / 🟡 Some overlap / 🔴 This exists
- [ ] **T1-08**: Prompts user to opt into Tier 2 with candidate count
- [ ] **T1-09**: Total Tier 1 run completes in ≤90 seconds for the 3 golden test inputs

### Tier 2 — Deep Inspection

- [ ] **T2-01**: Tier 2 triggers only on explicit user confirmation after Tier 1
- [ ] **T2-02**: Expands discovery with WebSearch + 10 additional `gh api` queries; dedupes across sources
- [ ] **T2-03**: Verifies every cited URL (including web sources) via `gh api`; flags 404s
- [ ] **T2-04**: Shallow-clones (`git clone --depth 1 --filter=blob:none --single-branch --no-tags`) repos flagged WORTH_INSPECTING
- [ ] **T2-05**: Safe-clone wrapper enforces 50MB size cap (pre-check `gh api .size`), `GIT_LFS_SKIP_SMUDGE=1`, 60s timeout
- [ ] **T2-06**: Clones written to `mktemp -d` directory under `/tmp/reporecon/`; cleaned via `trap` on exit, interrupt, or terminate
- [ ] **T2-07**: Cloned README/source treated as untrusted content (wrapped in `<untrusted_content>` delimiters; truncated to ~3000 chars; HTML comments and zero-width chars stripped)
- [ ] **T2-08**: Judge inspects entry points, package manifests, and top-level source files; cites file paths as evidence
- [ ] **T2-09**: Tier 2 produces full 5-level verdict: EXACT_MATCH / SIGNIFICANT_OVERLAP / PARTIAL_OVERLAP / SUPERFICIAL_MATCH / VAPOR
- [ ] **T2-10**: Total Tier 2 run completes in ≤10 minutes for 3 golden test inputs

### Judgment Rubric

- [ ] **JDG-01**: 5-axis rubric: core function match, target audience match, scope match, implementation approach match, activity status
- [ ] **JDG-02**: Each axis scored as integer with stated evidence
- [ ] **JDG-03**: Verdict mechanically derived from axis scores (not asked directly of the LLM)
- [ ] **JDG-04**: Verdicts ≥ PARTIAL_OVERLAP require at least one cited file path from a clone; otherwise capped at SUPERFICIAL_MATCH
- [ ] **JDG-05**: Judge prompt explicitly resists user confirmation bias ("the user wants their idea to be novel; resist this")
- [ ] **JDG-06**: Devil's-advocate re-judge runs on GREEN verdicts near the threshold to catch missed matches
- [ ] **JDG-07**: Judgment runs with temperature pinned to 0 (or lowest available) for repeatability

### Mechanical Heuristics

- [ ] **HEUR-01**: Vapor heuristic flags repos with (≥3 README claims) AND (≤5 source files OR archived OR last commit >18mo)
- [ ] **HEUR-02**: Staleness flags: `archived=true`; `pushed_at < now-12mo`; single-contributor + last commit >6mo
- [ ] **HEUR-03**: Staleness surfaced as badges; does NOT auto-downgrade verdict (fork-it case is valid)
- [ ] **HEUR-04**: Mechanical heuristics implemented in bash (not LLM) for repeatability

### Report Output

- [ ] **RPT-01**: Reports written to `./reporecon-reports/YYYY-MM-DD-<slug>.md`
- [ ] **RPT-02**: Report includes: sharpened statement, verdict badge, candidates with verdict + axis scores + evidence + URL + staleness badges + check timestamp
- [ ] **RPT-03**: Report includes negative-space section listing features in the user's idea absent from all inspected candidates ("your angle")
- [ ] **RPT-04**: Each candidate URL paired with a "verified at {timestamp}" annotation

### Helper Scripts

- [ ] **SCR-01**: `scripts/gh-search.sh <query>` wraps `gh api search/repositories` with jq filtering; returns normalized JSON
- [ ] **SCR-02**: `scripts/verify-repo.sh <owner/repo>` returns metadata JSON or non-zero on 404
- [ ] **SCR-03**: `scripts/safe-clone.sh <owner/repo> <dest>` enforces size + timeout + LFS skip + cleanup-trap
- [ ] **SCR-04**: `scripts/vapor-check.sh <clone-dir>` returns 0 if vapor heuristic triggers, else 1
- [ ] **SCR-05**: `scripts/staleness.sh <metadata-json>` emits badge tags

### Testing & Examples

- [ ] **TST-01**: 3 golden test cases in `tests/golden/`: saturated domain (todo CLI), empty domain (genuinely novel), ambiguous domain
- [ ] **TST-02**: Tier 1 produces stable verdicts across 3 consecutive runs on each golden input
- [ ] **TST-03**: Golden tests include a planted prompt-injection README fixture
- [ ] **TST-04**: Golden tests include a planted vapor repo fixture
- [ ] **TST-05**: Examples directory contains 3 dogfooded example reports (one per scenario)

## v2 Requirements

### Caching & Performance

- **CACH-01**: Cache verified repo metadata by idea-hash to skip re-verification on re-runs
- **PERF-01**: Streaming verdict output (progressive disclosure as candidates verify)

### Sources Expansion

- **SRC-01**: GitLab repo search
- **SRC-02**: Codeberg repo search
- **SRC-03**: Package registry search (npm, PyPI, crates) as supplementary signal

### Privacy & UX

- **PRIV-01**: Local-only privacy mode (no WebSearch, host-LLM only)
- **UX-01**: Background/async mode that returns when done

### Distribution

- **DIST-01**: Standalone CLI (`npx reporecon`)
- **DIST-02**: `gh` extension distribution

### Monitoring

- **MON-01**: Auto re-run weekly on a saved idea; alert on new matches

## Out of Scope

| Feature | Reason |
|---------|--------|
| Embeddings-based pre-indexed repo search | Infrastructure overhead; runtime workflow sufficient for v1 |
| MCP server distribution | Plugin-only for v1; MCP adds setup friction |
| Commercial SaaS competitor detection | Cannot verify equivalence; out of scope to keep verdicts trustworthy |
| Dependency-graph compare | Beyond v1 judgment scope |
| Free-form LLM verdicts (no rubric) | Reintroduces non-determinism; structured rubric is the moat |
| Async/background mode in v1 | Two-tier output already addresses blocking-chat problem |
| Single combined Tier 1+2 mode | Defeats the speed vs. depth tradeoff that gives the tool its UX |

## Traceability

(Populated during roadmap creation by gsd-roadmapper.)

| Requirement | Phase | Status |
|-------------|-------|--------|
| All v1 REQ-IDs | TBD | Pending |

**Coverage:**
- v1 requirements: 51 total
- Mapped to phases: 0
- Unmapped: 51 ⚠️ (to be resolved by roadmapper)

---
*Requirements defined: 2026-05-26*
*Last updated: 2026-05-26 after initialization*
