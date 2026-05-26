<!-- GSD:project-start source:PROJECT.md -->
## Project

**RepoRecon**

RepoRecon is a Claude Code plugin (packaged as a skill + plugin manifest, distributed via the Claude Code marketplace) that validates whether a developer's project idea already exists on GitHub before they build it. It runs a two-tier workflow: a fast verdict in ~90 seconds, and an optional deep inspection that clones top candidates and judges equivalence with cited evidence. The audience is solo developers and small teams who want to stop building things that already exist.

**Core Value:** Given a fuzzy project idea, RepoRecon returns a trustworthy, evidence-cited verdict on whether it already exists on GitHub — fast enough to not interrupt flow, deep enough that the user can act on the answer.

### Constraints

- **Tech stack**: Claude Code plugin format (SKILL.md + plugin.json + marketplace.json + package.json) — required for marketplace listing.
- **Runtime tools**: Only `gh` CLI, `git`, `WebSearch`, host LLM. No external services, no MCP server, no embeddings index in v1.
- **Performance**: Tier 1 must complete in under 90 seconds for the 3 golden test inputs. Tier 2 budget ~10 minutes.
- **Rate limits**: Tier 1 ≤10 `gh api` calls, Tier 2 ≤50. Document `gh auth login` requirement.
- **Storage**: Clones written to `/tmp/reporecon/<run-id>/` with TTL cleanup. Reports written to `./reporecon-reports/` (gitignored by convention).
- **Distribution**: Public GitHub repo registered with the Claude Code plugin marketplace. License TBD (likely MIT).
- **Execution model**: Each phase plan executed in an isolated git worktree by a parallel agent; one branch + one PR per plan; merges synchronize at wave boundaries.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## TL;DR — The Stack
| Layer | Choice | Rationale |
|-------|--------|-----------|
| **Plugin format** | Claude Code plugin (`.claude-plugin/plugin.json` + bundled skill) | Required for marketplace distribution; auto-discovery from `skills/`, `commands/`, `scripts/` |
| **Skill format** | `SKILL.md` (Agent Skills open standard, YAML frontmatter) | Required by Claude Code; progressive disclosure (body loads only when invoked) |
| **Distribution** | `.claude-plugin/marketplace.json` in same repo, hosted on public GitHub | Anthropic's documented path; users add via `/plugin marketplace add owner/repo` |
| **Orchestration** | Host LLM (Claude) reading SKILL.md | Plugin is instructions + scripts, not code. No agent framework needed. |
| **GitHub access** | `gh` CLI ≥ 2.55 via `gh api` (REST + GraphQL) | Authenticated, rate-aware, already required by Claude Code users; avoids token plumbing |
| **Repo inspection** | `git` ≥ 2.40 with `clone --depth 1 --filter=blob:none --single-branch` | Minimum bytes pulled; partial clone keeps directory listings cheap |
| **JSON parsing in scripts** | `jq` ≥ 1.7 | Universally installed alongside `gh`; only reliable way to slice `gh api` JSON in bash |
| **Web discovery** | Built-in `WebSearch` tool (Tier 2 only) | Already in Claude Code; no Brave/Exa key required for v1 |
| **Source reading** | Built-in `Read` + `Grep` tools | Reads cloned working tree; no extra deps |
| **Report output** | Plain Markdown to `./reporecon-reports/YYYY-MM-DD-<slug>.md` | Versionable, shareable, no renderer needed |
| **Temp storage** | `/tmp/reporecon/<run-id>/` with `trap`-based cleanup | POSIX; survives sandbox restarts; auto-cleaned by OS on reboot |
| Tool | Minimum | Why |
|------|---------|-----|
| Claude Code | latest (May 2026 channel) | Plugin marketplace + skill features stabilized 2025-Q4; older builds lack `/plugin` command |
| `gh` | 2.55.0 | Stable `gh api --paginate`, `--jq`, GraphQL pagination; current release line as of 2026-05 |
| `git` | 2.40 | `--filter=blob:none` partial-clone reliability; `--single-branch` default safety |
| `jq` | 1.7 | `--rawfile`, stable error handling |
| `bash` | 4.0+ (macOS users: prefer `/usr/bin/env bash`) | Arrays, `set -euo pipefail`, `mapfile` |
## Plugin Package Layout
- `.claude-plugin/` is the **only required directory**. Everything else is convention.
- `skills/<name>/SKILL.md` is auto-discovered when the plugin is loaded; no need to register in `plugin.json`.
- `references/` siblings to SKILL.md are the documented pattern for progressive disclosure — the skill body stays small (cheap to load), and references are read by Claude only when the protocol points to them. This matters: SKILL.md gets injected into context on activation, so keeping it short while parking detail in `references/*.md` is the standard skill-author pattern.
- `scripts/` are referenced from SKILL.md by **path relative to the plugin root** (`${CLAUDE_PLUGIN_ROOT}` is set by Claude Code at runtime). The skill calls them via Bash. The scripts exist so prompts don't have to encode brittle `gh`/`git` flag combos inline.
## Manifest Schemas (Verified)
### `.claude-plugin/plugin.json`
### `.claude-plugin/marketplace.json`
### `skills/reporecon/SKILL.md` frontmatter
- `description` must be auto-trigger-quality — Claude reads it to decide whether to activate the skill in ambient mode. Include trigger phrases verbatim.
- `allowed-tools` restricts tool surface — RepoRecon does **not** need `Edit`, `WebFetch`, or general write access beyond report output.
- `effort: medium` — Tier 1 is short, Tier 2 involves multi-step reasoning. `high` is overkill and costs latency.
- We do **not** set `disable-model-invocation` — we want Claude to be able to suggest the skill when a user describes an idea.
## Runtime Tool Patterns
### `gh` CLI — Repo Search and Metadata
| Endpoint family | Authed limit | RepoRecon usage |
|-----------------|--------------|-----------------|
| Core REST (`/repos/...`) | 5,000 / hour | ~10 (T1) + ~50 (T2) → ≤1.2% of budget |
| Search (`/search/repositories`) | **30 / minute** (authed) | T1: 5 queries, T2: +10 queries → well under |
| Code search (`/search/code`) | **10 / hour** — DO NOT USE | Avoid entirely; use repo search + clone inspection instead |
### `git` — Safe Shallow Clone
| Flag | Why |
|------|-----|
| `--depth 1` | Only latest commit; no history |
| `--filter=blob:none` | Partial clone — file blobs fetched on-demand (when `Read` opens them). Cuts initial bytes for repos with large binaries. |
| `--single-branch` | Only default branch refs |
| `--no-tags` | Skip tag objects (often heavy in popular repos) |
# Pre-check size via gh api (size is in KB)
# Timeout wrapper — 30s for clone, kill cleanly on hang
# Trap-based cleanup on script exit (success or failure)
## Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jq` | ≥ 1.7 | Slice/transform `gh api` JSON inside bash scripts | Every gh wrapper script; never parse JSON with grep |
| `coreutils` `timeout` | any (GNU coreutils) | Kill runaway clones/searches | `safe-clone.sh` only |
| `mktemp` | POSIX | Run-ID directory creation | `safe-clone.sh`: `mktemp -d /tmp/reporecon/XXXXXX` |
## What's NOT in the Stack (and Why)
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Node.js runtime / `package.json` with deps** | Plugin runs zero JS at execution time; adding npm deps creates an install step Anthropic doesn't require and that breaks `npx`-free use | Pure bash scripts under `scripts/` |
| **`@octokit/rest` or `@octokit/graphql`** | Adds Node dep, token plumbing, and version drift; `gh api` is already authenticated and rate-aware | `gh api` |
| **WebFetch tool** | Lower signal than `gh api` for metadata; bypasses `gh` rate-limit awareness; produced wrong star counts in the origin-story session | `gh api repos/{owner}/{repo}` |
| **MCP server (custom)** | All needed tools are already Claude Code built-ins; an MCP server adds install friction with no capability gain | Built-in `Bash` + `gh`/`git` |
| **Embeddings / vector DB / pre-indexed repos** | PROJECT.md explicitly out-of-scope for v1; runtime workflow handles the volume | Diverse `gh api` queries + LLM judgment |
| **SQLite cache by idea-hash** | Premature for v1; documented in PROJECT.md as deferred to v1.1 | Stateless runs; report files on disk are the cache |
| **`git clone` without `--depth 1`** | Pulls full history; busts size budget on any popular repo | `safe-clone.sh` (depth-1, blob-filtered, size-gated, timeout-wrapped) |
| **GitHub code search (`/search/code`)** | 10 requests/hour authed limit — breaks Tier 2 budget immediately | Clone top candidates and use `Grep` |
| **Python helper scripts** | Adds Python to user's prereq list; bash + `jq` covers all parsing | POSIX bash + `jq` |
| **`npm` publishing** | Plugin is installed via `/plugin install`, not `npm install`; npm distribution is documented as out-of-scope in PROJECT.md | GitHub marketplace registration only |
| **Pre-built JSON schemas inside repo** | `$schema` URLs from schemastore.org give free IDE validation | Reference schemastore URLs in `plugin.json` / `marketplace.json` |
## Alternatives Considered
| Recommended | Alternative | When the Alternative Would Win |
|-------------|-------------|--------------------------------|
| Pure-bash helper scripts | TypeScript scripts + `tsx` shim | If reports needed templating engines or complex data transforms (they don't) |
| `gh api` directly | `gh search repos` (high-level cmd) | `gh search repos` is friendlier but exposes fewer filters; we need `pushed:`, `archived:`, sort flexibility |
| `git clone --depth 1 --filter=blob:none` | `gh api .../contents/{path}` per-file | Per-file API calls burn rate limit fast; clone is one-shot |
| `WebSearch` (built-in) | Brave Search API / Exa MCP | Only if v1 ships and WebSearch quality proves blocking; deferred per PROJECT.md scope |
| Single-plugin marketplace (this repo) | Submit to anthropics/claude-plugins-official | Worth doing after v1 stabilizes; not a v1 blocker |
| `effort: medium` on skill | `effort: high` | Only for the equivalence judgment step — can be overridden per-invocation via SKILL.md instructions, doesn't need frontmatter change |
## Stack Patterns by Variant
- Skill loads SKILL.md body + `references/query-patterns.md`
- Calls `scripts/gh-search-repos.sh` (×5) + `scripts/gh-repo-meta.sh` (×5)
- LLM rates from metadata alone; no clones
- ~10 API calls total
- Skill additionally loads `references/judge-rubric.md` + `references/safety-rules.md`
- Calls `WebSearch` (×5 expanded queries)
- Calls `scripts/safe-clone.sh` (×3-5 top candidates)
- Uses `Read` + `Grep` against `/tmp/reporecon/<run-id>/`
- LLM applies 5-axis rubric with file-path evidence
- `scripts/cleanup-tmp.sh` runs on completion or trap
- ~50 API calls total
- SKILL.md protocol: refuse Tier 2; warn and offer Tier 1 with 60 req/hr cap (degraded mode)
- Surface `gh auth login` instruction in error path
## Version Compatibility
| Tool A | Compatible With | Notes |
|--------|-----------------|-------|
| `gh` 2.55+ | `git` 2.40+ | `gh repo clone` not used; we call `git clone` directly so any modern git works |
| Claude Code (current) | Plugin schema v1 | `$schema` URLs at schemastore.org track current release |
| `jq` 1.7 | `gh` 2.x | `gh api --jq` embeds jq filter syntax; same syntax works standalone |
| Bash 4+ | `mktemp`, `timeout` (GNU) | macOS users need `brew install bash coreutils` for GNU `timeout` — document in README |
## Installation (End User)
# In Claude Code
# Prereqs (one-time, surfaced in README)
## Sources
- [Create and distribute a plugin marketplace — Claude Code Docs](https://code.claude.com/docs/en/plugin-marketplaces) — marketplace.json structure, source types, `strict` flag, hosting
- [Extend Claude with skills — Claude Code Docs](https://code.claude.com/docs/en/skills) — SKILL.md frontmatter, progressive disclosure, `references/` convention, `allowed-tools`
- [anthropics/claude-code marketplace.json reference](https://github.com/anthropics/claude-code/blob/main/.claude-plugin/marketplace.json) — canonical marketplace example
- [anthropics/claude-plugins-official marketplace.json](https://github.com/anthropics/claude-plugins-official/blob/main/.claude-plugin/marketplace.json) — second canonical example
- [hesreallyhim/claude-code-json-schema](https://github.com/hesreallyhim/claude-code-json-schema) — unofficial but schemastore-hosted JSON schemas (`https://json.schemastore.org/claude-code-marketplace.json`)
- [GitHub REST rate-limit docs](https://docs.github.com/en/rest/rate-limit/rate-limit) — 5000/hr core, 30/min search, 10/hr code-search
- [cli/cli discussion #5381 — rate-limit behavior](https://github.com/cli/cli/discussions/5381) — confirms `gh` uses both REST + GraphQL, both share hourly limits
- [cli/cli discussion #7754 — handling rate limits](https://github.com/cli/cli/discussions/7754) — `gh api rate_limit` pattern
- [SKILL.md Spec — agensi.io](https://www.agensi.io/learn/skill-md-format-reference) — frontmatter field enumeration
- [Claude Code Skill Frontmatter — Frontend Master](https://allahabadi.dev/blogs/ai/claude-code-skills-frontmatter-complete-guide/) — `disable-model-invocation`, `effort`, `hooks` field semantics
- [cc-marketplace PLUGIN_SCHEMA.md](https://github.com/ananddtyagi/claude-code-marketplace/blob/main/PLUGIN_SCHEMA.md) — community-documented plugin schema
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
