# Stack Research — RepoRecon

**Domain:** Claude Code plugin (skill + helper bash scripts) for GitHub prior-art reconnaissance
**Researched:** 2026-05-26
**Confidence:** HIGH (plugin/skill schema verified against official docs and anthropics/claude-code reference repo; gh CLI / git semantics verified via official sources)

---

## TL;DR — The Stack

RepoRecon is a **zero-runtime** Claude Code plugin. No Node process runs at execution time; no package needs `npm install` to use the plugin. The "stack" is really a packaging layout plus a set of host-provided runtime tools (`gh`, `git`, `WebSearch`, `Read`/`Grep`, host LLM) wrapped by **POSIX bash helper scripts**.

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

**Required versions (minima):**

| Tool | Minimum | Why |
|------|---------|-----|
| Claude Code | latest (May 2026 channel) | Plugin marketplace + skill features stabilized 2025-Q4; older builds lack `/plugin` command |
| `gh` | 2.55.0 | Stable `gh api --paginate`, `--jq`, GraphQL pagination; current release line as of 2026-05 |
| `git` | 2.40 | `--filter=blob:none` partial-clone reliability; `--single-branch` default safety |
| `jq` | 1.7 | `--rawfile`, stable error handling |
| `bash` | 4.0+ (macOS users: prefer `/usr/bin/env bash`) | Arrays, `set -euo pipefail`, `mapfile` |

**Confidence: HIGH** — Versions verified against current release notes; marketplace schema verified against anthropics/claude-code reference repo (see Sources).

---

## Plugin Package Layout

The canonical RepoRecon plugin layout (auto-discovery friendly — Claude Code finds these without manual registration in `plugin.json`):

```
reporecon/                              # repo root
├── .claude-plugin/
│   ├── plugin.json                     # plugin manifest (name required; rest optional)
│   └── marketplace.json                # marketplace catalog (this repo IS the marketplace for v1)
├── skills/
│   └── reporecon/
│       ├── SKILL.md                    # orchestration protocol, trigger phrases, tool budget
│       └── references/                 # progressive-disclosure docs loaded on-demand
│           ├── query-patterns.md       # 5 diverse query template families
│           ├── judge-rubric.md         # 5-axis equivalence rubric + verdict thresholds
│           ├── report-template.md      # markdown report scaffold
│           └── safety-rules.md         # clone size/timeout guards, vapor heuristic
├── scripts/                            # POSIX bash helpers, stable interfaces over gh + git
│   ├── gh-search-repos.sh              # wraps `gh api -X GET search/repositories`
│   ├── gh-repo-meta.sh                 # wraps `gh api repos/{owner}/{repo}` → flat JSON
│   ├── gh-rate-check.sh                # `gh api rate_limit` — fails fast if budget exhausted
│   ├── safe-clone.sh                   # depth-1, size-capped, timeout-wrapped clone
│   ├── cleanup-tmp.sh                  # `rm -rf /tmp/reporecon/<run-id>`
│   └── report-path.sh                  # computes `./reporecon-reports/YYYY-MM-DD-<slug>.md`
├── commands/                           # optional slash-command shims (auto-discovered)
│   └── reporecon.md                    # `/reporecon "<idea>"` → invokes skill
├── README.md                           # install + demo
├── LICENSE                             # MIT
└── examples/                           # dogfooded reports (LabelLens, NDISBulkValidator)
```

**Why this layout:**

- `.claude-plugin/` is the **only required directory**. Everything else is convention.
- `skills/<name>/SKILL.md` is auto-discovered when the plugin is loaded; no need to register in `plugin.json`.
- `references/` siblings to SKILL.md are the documented pattern for progressive disclosure — the skill body stays small (cheap to load), and references are read by Claude only when the protocol points to them. This matters: SKILL.md gets injected into context on activation, so keeping it short while parking detail in `references/*.md` is the standard skill-author pattern.
- `scripts/` are referenced from SKILL.md by **path relative to the plugin root** (`${CLAUDE_PLUGIN_ROOT}` is set by Claude Code at runtime). The skill calls them via Bash. The scripts exist so prompts don't have to encode brittle `gh`/`git` flag combos inline.

---

## Manifest Schemas (Verified)

### `.claude-plugin/plugin.json`

Only `name` is required. The rest is optional because Claude Code auto-discovers components from `skills/`, `commands/`, `agents/`, `hooks/`.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-plugin.json",
  "name": "reporecon",
  "version": "0.1.0",
  "description": "Validate whether your project idea already exists on GitHub before you build it.",
  "author": {
    "name": "<author>",
    "email": "<email>",
    "url": "https://github.com/<author>"
  },
  "homepage": "https://github.com/<author>/reporecon",
  "repository": "https://github.com/<author>/reporecon",
  "license": "MIT",
  "keywords": ["github", "prior-art", "validation", "research", "skill"]
}
```

### `.claude-plugin/marketplace.json`

This repo doubles as its own marketplace for v1 (single-plugin marketplace). Users run `/plugin marketplace add <owner>/reporecon` once, then `/plugin install reporecon@reporecon`.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-marketplace.json",
  "name": "reporecon",
  "owner": {
    "name": "<author>",
    "email": "<email>",
    "url": "https://github.com/<author>"
  },
  "plugins": [
    {
      "name": "reporecon",
      "source": "./",
      "description": "Prior-art reconnaissance for GitHub project ideas.",
      "category": "research",
      "tags": ["github", "validation", "prior-art"],
      "strict": true
    }
  ]
}
```

**Source types** (`source` field): `./` for in-repo plugin (this is our case), or a git URL / GitHub shorthand for external plugins. `strict: true` enforces schema validation on install — recommended.

### `skills/reporecon/SKILL.md` frontmatter

Per the Agent Skills standard (which Claude Code follows), only `name` and `description` are required. RepoRecon uses:

```yaml
---
name: reporecon
description: |
  Validate whether a project idea already exists on GitHub. Run when the user
  asks "does X exist", "has Y been built", "is Z taken", or invokes /reporecon.
  Performs Tier 1 quick verdict (~90s) then optional Tier 2 deep inspection
  with shallow clones and evidence-cited equivalence judgment.
allowed-tools:
  - Bash
  - WebSearch
  - Read
  - Grep
  - Write
effort: medium
---
```

**Field rationale:**

- `description` must be auto-trigger-quality — Claude reads it to decide whether to activate the skill in ambient mode. Include trigger phrases verbatim.
- `allowed-tools` restricts tool surface — RepoRecon does **not** need `Edit`, `WebFetch`, or general write access beyond report output.
- `effort: medium` — Tier 1 is short, Tier 2 involves multi-step reasoning. `high` is overkill and costs latency.
- We do **not** set `disable-model-invocation` — we want Claude to be able to suggest the skill when a user describes an idea.

---

## Runtime Tool Patterns

### `gh` CLI — Repo Search and Metadata

**Tier 1 query (one of 5 diverse queries):**

```bash
gh api -X GET search/repositories \
  -f q="NDIS invoice validator language:python" \
  -f sort=stars -f order=desc -f per_page=10 \
  --jq '.items[] | {name: .full_name, stars: .stargazers_count, pushed: .pushed_at, archived: .archived, desc: .description}'
```

**Repo metadata (verify a single candidate exists + freshness):**

```bash
gh api repos/Pwnion/NDIS-Doc-Parser \
  --jq '{full_name, stars: .stargazers_count, pushed_at, archived, default_branch, size, language, topics}'
```

**Rate-limit pre-check** (run at start of each tier):

```bash
gh api rate_limit --jq '.resources.search.remaining, .resources.core.remaining'
```

**Critical rate-limit facts** (verified against GitHub Docs + cli/cli discussions):

| Endpoint family | Authed limit | RepoRecon usage |
|-----------------|--------------|-----------------|
| Core REST (`/repos/...`) | 5,000 / hour | ~10 (T1) + ~50 (T2) → ≤1.2% of budget |
| Search (`/search/repositories`) | **30 / minute** (authed) | T1: 5 queries, T2: +10 queries → well under |
| Code search (`/search/code`) | **10 / hour** — DO NOT USE | Avoid entirely; use repo search + clone inspection instead |

**Auth requirement:** `gh auth login` is a documented prerequisite. The plugin README and SKILL.md must surface this — unauthed `gh api` falls back to 60 req/hr which breaks Tier 2 budget.

### `git` — Safe Shallow Clone

`scripts/safe-clone.sh` wraps the canonical safe-clone invocation:

```bash
git clone \
  --depth 1 \
  --filter=blob:none \
  --single-branch \
  --no-tags \
  -- "https://github.com/${OWNER}/${REPO}.git" \
  "/tmp/reporecon/${RUN_ID}/${REPO}"
```

Flag-by-flag rationale:

| Flag | Why |
|------|-----|
| `--depth 1` | Only latest commit; no history |
| `--filter=blob:none` | Partial clone — file blobs fetched on-demand (when `Read` opens them). Cuts initial bytes for repos with large binaries. |
| `--single-branch` | Only default branch refs |
| `--no-tags` | Skip tag objects (often heavy in popular repos) |

**Guards layered on top in `safe-clone.sh`:**

```bash
# Pre-check size via gh api (size is in KB)
size_kb=$(gh api "repos/${OWNER}/${REPO}" --jq .size)
[ "$size_kb" -gt 51200 ] && { echo "SKIP: ${OWNER}/${REPO} >50MB"; exit 2; }

# Timeout wrapper — 30s for clone, kill cleanly on hang
timeout --signal=TERM --kill-after=5s 30s git clone ... || exit 3

# Trap-based cleanup on script exit (success or failure)
trap 'rm -rf "/tmp/reporecon/${RUN_ID}/${REPO}"' EXIT
```

The `gh api .size` pre-check is critical — `--depth 1 --filter=blob:none` is cheap for source-only repos but can still pull megabytes for repos with checked-in binaries or LFS pointers.

---

## Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jq` | ≥ 1.7 | Slice/transform `gh api` JSON inside bash scripts | Every gh wrapper script; never parse JSON with grep |
| `coreutils` `timeout` | any (GNU coreutils) | Kill runaway clones/searches | `safe-clone.sh` only |
| `mktemp` | POSIX | Run-ID directory creation | `safe-clone.sh`: `mktemp -d /tmp/reporecon/XXXXXX` |

That's the complete supporting-library list. No Node, no Python, no SDKs.

---

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

---

## Alternatives Considered

| Recommended | Alternative | When the Alternative Would Win |
|-------------|-------------|--------------------------------|
| Pure-bash helper scripts | TypeScript scripts + `tsx` shim | If reports needed templating engines or complex data transforms (they don't) |
| `gh api` directly | `gh search repos` (high-level cmd) | `gh search repos` is friendlier but exposes fewer filters; we need `pushed:`, `archived:`, sort flexibility |
| `git clone --depth 1 --filter=blob:none` | `gh api .../contents/{path}` per-file | Per-file API calls burn rate limit fast; clone is one-shot |
| `WebSearch` (built-in) | Brave Search API / Exa MCP | Only if v1 ships and WebSearch quality proves blocking; deferred per PROJECT.md scope |
| Single-plugin marketplace (this repo) | Submit to anthropics/claude-plugins-official | Worth doing after v1 stabilizes; not a v1 blocker |
| `effort: medium` on skill | `effort: high` | Only for the equivalence judgment step — can be overridden per-invocation via SKILL.md instructions, doesn't need frontmatter change |

---

## Stack Patterns by Variant

**If Tier 1 only (90-second quick verdict):**
- Skill loads SKILL.md body + `references/query-patterns.md`
- Calls `scripts/gh-search-repos.sh` (×5) + `scripts/gh-repo-meta.sh` (×5)
- LLM rates from metadata alone; no clones
- ~10 API calls total

**If Tier 2 deep inspection (opt-in):**
- Skill additionally loads `references/judge-rubric.md` + `references/safety-rules.md`
- Calls `WebSearch` (×5 expanded queries)
- Calls `scripts/safe-clone.sh` (×3-5 top candidates)
- Uses `Read` + `Grep` against `/tmp/reporecon/<run-id>/`
- LLM applies 5-axis rubric with file-path evidence
- `scripts/cleanup-tmp.sh` runs on completion or trap
- ~50 API calls total

**If user is unauthenticated (`gh auth status` fails):**
- SKILL.md protocol: refuse Tier 2; warn and offer Tier 1 with 60 req/hr cap (degraded mode)
- Surface `gh auth login` instruction in error path

---

## Version Compatibility

| Tool A | Compatible With | Notes |
|--------|-----------------|-------|
| `gh` 2.55+ | `git` 2.40+ | `gh repo clone` not used; we call `git clone` directly so any modern git works |
| Claude Code (current) | Plugin schema v1 | `$schema` URLs at schemastore.org track current release |
| `jq` 1.7 | `gh` 2.x | `gh api --jq` embeds jq filter syntax; same syntax works standalone |
| Bash 4+ | `mktemp`, `timeout` (GNU) | macOS users need `brew install bash coreutils` for GNU `timeout` — document in README |

---

## Installation (End User)

```
# In Claude Code
/plugin marketplace add <author>/reporecon
/plugin install reporecon@reporecon

# Prereqs (one-time, surfaced in README)
gh auth login                   # required for Tier 2 rate budget
gh --version                    # confirm ≥ 2.55
git --version                   # confirm ≥ 2.40
jq --version                    # confirm ≥ 1.7
```

No `npm install`. No language runtime. The plugin ships as Markdown + bash.

---

## Sources

**Authoritative (HIGH confidence):**
- [Create and distribute a plugin marketplace — Claude Code Docs](https://code.claude.com/docs/en/plugin-marketplaces) — marketplace.json structure, source types, `strict` flag, hosting
- [Extend Claude with skills — Claude Code Docs](https://code.claude.com/docs/en/skills) — SKILL.md frontmatter, progressive disclosure, `references/` convention, `allowed-tools`
- [anthropics/claude-code marketplace.json reference](https://github.com/anthropics/claude-code/blob/main/.claude-plugin/marketplace.json) — canonical marketplace example
- [anthropics/claude-plugins-official marketplace.json](https://github.com/anthropics/claude-plugins-official/blob/main/.claude-plugin/marketplace.json) — second canonical example
- [hesreallyhim/claude-code-json-schema](https://github.com/hesreallyhim/claude-code-json-schema) — unofficial but schemastore-hosted JSON schemas (`https://json.schemastore.org/claude-code-marketplace.json`)
- [GitHub REST rate-limit docs](https://docs.github.com/en/rest/rate-limit/rate-limit) — 5000/hr core, 30/min search, 10/hr code-search
- [cli/cli discussion #5381 — rate-limit behavior](https://github.com/cli/cli/discussions/5381) — confirms `gh` uses both REST + GraphQL, both share hourly limits
- [cli/cli discussion #7754 — handling rate limits](https://github.com/cli/cli/discussions/7754) — `gh api rate_limit` pattern

**Verified (MEDIUM confidence — community sources cross-checked against official docs):**
- [SKILL.md Spec — agensi.io](https://www.agensi.io/learn/skill-md-format-reference) — frontmatter field enumeration
- [Claude Code Skill Frontmatter — Frontend Master](https://allahabadi.dev/blogs/ai/claude-code-skills-frontmatter-complete-guide/) — `disable-model-invocation`, `effort`, `hooks` field semantics
- [cc-marketplace PLUGIN_SCHEMA.md](https://github.com/ananddtyagi/claude-code-marketplace/blob/main/PLUGIN_SCHEMA.md) — community-documented plugin schema

---

*Stack research for: Claude Code plugin (RepoRecon)*
*Researched: 2026-05-26*
