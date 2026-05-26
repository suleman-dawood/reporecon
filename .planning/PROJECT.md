# RepoRecon

## What This Is

RepoRecon is a Claude Code plugin (packaged as a skill + plugin manifest, distributed via the Claude Code marketplace) that validates whether a developer's project idea already exists on GitHub before they build it. It runs a two-tier workflow: a fast verdict in ~90 seconds, and an optional deep inspection that clones top candidates and judges equivalence with cited evidence. The audience is solo developers and small teams who want to stop building things that already exist.

## Core Value

Given a fuzzy project idea, RepoRecon returns a trustworthy, evidence-cited verdict on whether it already exists on GitHub — fast enough to not interrupt flow, deep enough that the user can act on the answer.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Idea sharpening step: restate user input as one-sentence "what/for whom/how" + 3-5 differentiator keywords
- [ ] Tier 1 quick verdict: 5 diverse `gh api` queries → top 5 verified candidates → metadata-only LLM rating → green/yellow/red verdict in <90s
- [ ] Tier 2 deep inspection: WebSearch + expanded queries + shallow clones + evidence-cited equivalence judgment in 5-10 min
- [ ] Verdict taxonomy: EXACT_MATCH / SIGNIFICANT_OVERLAP / PARTIAL_OVERLAP / SUPERFICIAL_MATCH / VAPOR — each with file-path or URL evidence
- [ ] Mechanical vapor heuristic (≥3 README claims AND ≤5 source files OR archived OR >18mo stale)
- [ ] Mechanical staleness flags (archived, pushed_at >12mo, single-contributor + >6mo)
- [ ] Negative-space report section: features in the user's idea absent from all inspected candidates ("your angle")
- [ ] Structured 5-axis rubric (core function, audience, scope, approach, activity) — verdict derived from axis scores, not vibes
- [ ] Safe clone wrapper: depth-1, 50MB size guard, timeout, /tmp cleanup
- [ ] Markdown report output to `./reporecon-reports/YYYY-MM-DD-<slug>.md`
- [ ] Claude Code plugin packaging: `plugin.json`, `marketplace.json`, `package.json`, README with demo
- [ ] 3 golden test cases (saturated domain, empty domain, ambiguous domain)
- [ ] Marketplace submission

### Out of Scope

- GitLab / Codeberg / Sourcehut sources — GitHub-only for v1; broader sources deferred (avoid scope creep, GitHub covers ~80% of cases)
- Package registries (npm / PyPI / crates) as primary search target — same reason
- Embeddings-based pre-indexed repo search — infrastructure overhead; runtime workflow is sufficient for v1
- Result caching by idea-hash — defer to v1.1 if re-runs become common
- Async / background mode — Tier 1/Tier 2 split already addresses the "blocking chat" problem
- Idea-privacy / local-only mode — defer until users actually request it
- Auto-monitoring / weekly re-run — out of v1 scope
- Standalone CLI (`npx reporecon`) or `gh` extension distribution — plugin-only for v1
- Commercial SaaS competitor detection — only GitHub repos verified

## Context

**Domain landscape:** No direct competitor exists. Closest tools are SimilarGit / RepoPal / ghindex (find repos similar to a *given repo*, not to an idea) and GitHub's own keyword search (no semantic understanding, no LLM judgment, no clone inspection). The combination of idea-driven discovery + 404 verification + clone inspection + LLM-judged equivalence with structured rubric is the moat.

**Why a Claude Code plugin:** Marketplace distribution. Plugin packaging lets us bundle the SKILL.md (orchestration), reference docs (query patterns, judge rubric, report template), and helper bash scripts (stable interfaces over `gh api` + `git clone`) into one installable unit.

**Tools used at runtime — all built-in:**
- `WebSearch` for broad discovery (Tier 2 only)
- `Bash` for `gh api` and `git clone --depth 1`
- `Read` / `Grep` for inspecting cloned source
- The host LLM for query generation, equivalence judgment, and report writing

**Known v1 limitations accepted:**
- WebSearch quality is opaque and fluctuates — acceptable in Tier 2 because the user explicitly opted in.
- LLM judgment can still flip on borderline cases — mitigated by structured rubric and evidence requirements, not eliminated.
- `gh` rate limit (5000/hr authed) — Tier 1 ~10 calls, Tier 2 ~50 calls; well under budget per run.
- Confirmation bias risk — judge prompt explicitly instructs the model to resist user pressure toward novelty verdicts.

**Design decisions already made (from brainstorming session 2026-05-26):**
- GitHub-only scope
- Two-tier output (quick verdict + opt-in deep dive)
- Claude Code plugin for marketplace distribution
- 3-phase build: Tier 1 MVP → Tier 2 Deep Inspection → Polish + Marketplace
- Wave-parallel agents per phase using isolated worktrees, one PR per plan

## Constraints

- **Tech stack**: Claude Code plugin format (SKILL.md + plugin.json + marketplace.json + package.json) — required for marketplace listing.
- **Runtime tools**: Only `gh` CLI, `git`, `WebSearch`, host LLM. No external services, no MCP server, no embeddings index in v1.
- **Performance**: Tier 1 must complete in under 90 seconds for the 3 golden test inputs. Tier 2 budget ~10 minutes.
- **Rate limits**: Tier 1 ≤10 `gh api` calls, Tier 2 ≤50. Document `gh auth login` requirement.
- **Storage**: Clones written to `/tmp/reporecon/<run-id>/` with TTL cleanup. Reports written to `./reporecon-reports/` (gitignored by convention).
- **Distribution**: Public GitHub repo registered with the Claude Code plugin marketplace. License TBD (likely MIT).
- **Execution model**: Each phase plan executed in an isolated git worktree by a parallel agent; one branch + one PR per plan; merges synchronize at wave boundaries.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| GitHub-only for v1 | ~80% of cases; broader sources would balloon scope and complicate judgment | — Pending |
| Two-tier output (quick + deep) | 80% of "does this exist?" questions answered in <90s; deep mode reserved for opt-in | — Pending |
| Claude Code plugin distribution | Marketplace discoverability; bundles skill + references + helper scripts cleanly | — Pending |
| Structured 5-axis rubric over free-form LLM judgment | Reduces non-determinism; requires file-path evidence ≥ PARTIAL_OVERLAP | — Pending |
| Mechanical vapor + staleness heuristics (not LLM) | Repeatability; avoids judgment flips between runs | — Pending |
| Wave-parallel execution per phase via isolated worktrees | User explicitly requested; maximizes throughput; PR-per-plan keeps review clean | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-26 after initialization*
