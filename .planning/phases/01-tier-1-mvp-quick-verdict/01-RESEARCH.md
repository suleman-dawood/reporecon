# Phase 1: Tier 1 MVP (Quick Verdict) - Research

**Researched:** 2026-05-26
**Domain:** Claude Code plugin packaging + bash/jq orchestration over `gh api` + structured LLM judgment
**Confidence:** HIGH on packaging/stack, MEDIUM on judge prompt calibration (must validate during Wave 3)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Plugin Packaging**
- **D-01:** Single-plugin self-marketplace layout — repo root contains `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`, marketplace source `./`, `strict: true`. Repo IS the marketplace for v1.
- **D-02:** `package.json` at repo root supplies marketplace search metadata (name `reporecon`, version `0.1.0`, description, author placeholder, MIT license, repository URL).
- **D-03:** Skill at `skills/reporecon/SKILL.md` with `references/` + `scripts/` subdirectories. Manifest schemas referenced via `https://json.schemastore.org/claude-code-{plugin,marketplace}.json`.
- **D-04:** Plugin name reserved early via Phase 1 commit; trigger collision check is Phase 3.

**Skill Authoring**
- **D-05:** `SKILL.md` ≤ 150 lines. Orchestration inline; rubric / query patterns / report template on-demand from `references/`.
- **D-06:** Triggers: `/reporecon <idea>` + natural phrases (`"is there already a tool that does X"`, `"validate my idea"`, `"does this exist on github"`). Listed in SKILL.md frontmatter.
- **D-07:** Skill orchestrates: preflight → sharpen → query gen → discover → verify → judge-lite → report. Each step = helper script (deterministic) OR LLM (judgment), never both for the same concern.

**Discovery & Verification**
- **D-08:** Tier 1 uses **only** `gh api search/repositories`. No WebSearch. Per-query rate budget tracked against 30/min search bucket.
- **D-09:** 5 LLM-generated queries from sharpened idea: (1) literal, (2) synonym-shifted, (3) outcome-framed, (4) tech-stack-framed, (5) adjacent-domain. Single LLM call.
- **D-10:** Dedup by `full_name`. Top 5 unique candidates by rank-sum feed verification.
- **D-11:** Every candidate verified via `gh api /repos/{owner}/{name}` with metadata (`stargazers_count`, `pushed_at`, `archived`, `default_branch`, `language`). Any 404 drops the candidate. No URL appears in output without a 200 OK timestamped within the run.
- **D-12:** Preflight: `gh auth status` + `gh api rate_limit`. Abort if unauthed or remaining < 50. Print rate budget.

**Idea Sharpening**
- **D-13:** Sharpening restates as `<one-sentence what/for-whom/how> + <3-5 differentiator keywords>`. Single LLM call, temp 0.
- **D-14:** Proper-noun guard: terms matching `[A-Z]{2,}` or capitalized multi-word phrases extracted verbatim into "preserved terms" list and re-inserted into sharpened sentence and query templates.
- **D-15:** Sharpened statement is the first line of the report header.

**Judgment Rubric (Tier 1 — metadata-only mode)**
- **D-16:** 5-axis integer rubric: `core_function`, `target_audience`, `scope`, `approach`, `activity`. Each 0-3 per candidate.
- **D-17:** Judge prompt: temp 0, one candidate per call (no batching), explicit anti-novelty framing, output JSON `{axis_scores, rationale, candidate_verdict}`.
- **D-18:** Tier 1 verdict per candidate: `LIKELY_MATCH` / `WORTH_INSPECTING` / `UNRELATED` — derived mechanically (thresholds in `references/judge-rubric.md`). Full 5-level (EXACT/SIGNIFICANT/PARTIAL/SUPERFICIAL/VAPOR) is Phase 2.
- **D-19:** Overall run verdict 🟢/🟡/🔴 derived from highest per-candidate verdict: `LIKELY_MATCH` → 🔴; `WORTH_INSPECTING` only → 🟡; all `UNRELATED` → 🟢.
- **D-20:** Devil's-advocate re-judge only on 🟢 verdicts where any axis score ≥ 2. Reverse-framed second pass; mismatch downgrades 🟢 → 🟡. At most 2 re-judges per run.

**Mechanical Heuristics (Tier 1 scope)**
- **D-21:** Staleness implemented in bash in `scripts/staleness.sh`. Badges: `archived`, `stale-12mo`, `solo-stale-6mo`. Vapor is Phase 2.
- **D-22:** Badges surfaced next to candidate URL; never auto-downgrade verdict.

**Reporting**
- **D-23:** Report → `./reporecon-reports/YYYY-MM-DD-<slug>.md`. mkdir if absent. Slug = kebab-case sharpened sentence, ≤40 chars.
- **D-24:** Header: sharpened statement, preserved terms, verdict badge, timestamp, gh rate budget consumed.
- **D-25:** Per-candidate block: `full_name` URL, "verified at {ISO timestamp}", axis scores, Tier 1 verdict, staleness badges, one-line rationale.
- **D-26:** Footer: `--tier2` opt-in pointer (documented, disabled in Phase 1).

**Helper Scripts (Tier 1 scope)**
- **D-27:** `scripts/preflight.sh` — `gh auth status` + `gh api rate_limit`, prints budget, non-zero on failure.
- **D-28:** `scripts/gh-search.sh <query>` — wraps `gh api -X GET search/repositories -F q="<query>" -F per_page=10`, jq-normalizes to `{full_name, description, stars, pushed_at, archived, language, url}`.
- **D-29:** `scripts/verify-repo.sh <owner/repo>` — `gh api /repos/...`; returns normalized metadata JSON or non-zero on 404.
- **D-30:** `scripts/staleness.sh <metadata-json>` — emits space-separated badge tags or empty.
- **D-31:** All scripts POSIX bash 4+, `set -euo pipefail`, `jq` for parsing. macOS toolchain doc in SKILL.md preflight; enforcement deferred to Phase 3 README.

**Determinism & Testing**
- **D-32:** Temperature 0 in every LLM call where host supports it; else prompt says "respond deterministically."
- **D-33:** Golden tests in `tests/golden/` — 3 fixtures: `todo-cli` (saturated), `obscure-niche` (novel), `llm-eval-dashboard` (ambiguous). Each: `{idea: "...", expected_verdict_band: "🟢|🟡|🔴"}`.
- **D-34:** Tier 1 must produce same verdict band across 3 consecutive runs per fixture. Stability is the ship gate, not axis-score exact match.
- **D-35:** Smoke runner: `tests/run-goldens.sh` invokes skill non-interactively, asserts band × 3 runs. Wired into a single GitHub Actions workflow (CI scaffold in Phase 1; submission gating Phase 3).

### Claude's Discretion
- Exact prose tone of `references/report-template.md` (clear, terse, max one verdict emoji).
- Filename slug edge cases (collision suffix scheme).
- Fail-open vs fail-closed on malformed `gh api rate_limit` JSON (recommend: fail closed with actionable error).
- Re-judge prompt phrasing for D-20.

### Deferred Ideas (OUT OF SCOPE)
- WebSearch dual-discovery (Phase 2)
- Shallow clones, `safe-clone.sh`, vapor heuristic, file-path evidence (Phase 2)
- EXACT/SIGNIFICANT/PARTIAL/SUPERFICIAL/VAPOR verdicts (Phase 2)
- Negative-space "your angle" section (Phase 2)
- Prompt-injection delimiters around cloned content (Phase 2)
- Planted-fixture goldens (Phase 2)
- README polish, demo gif/asciinema, dogfooded examples, marketplace submission, LICENSE polish (Phase 3)
- Streaming verdict output (v2), idea-hash cache (v2)
- GitLab/Codeberg/npm/PyPI/crates sources (v2)
- Standalone CLI / gh extension distribution (v2)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PKG-01 | Plugin installs via marketplace from single repo with `plugin.json` + `marketplace.json` | Manifest section + schemastore URLs |
| PKG-02 | `package.json` declares marketplace metadata | Stack research — name/version/license/repository fields |
| PKG-04 | `/reporecon` trigger uniqueness | Deferred verification to Phase 3 per D-04; documented for forward awareness |
| INP-01 | Trigger phrases (`/reporecon`, natural phrases) | SKILL.md frontmatter description field |
| INP-02 | Free-form NL idea input | Sharpening step consumes raw text |
| INP-03 | Sharpening = "what/for-whom/how" + 3-5 keywords | Sharpening prompt design (D-13) |
| INP-04 | Proper-noun preservation | Regex extraction (D-14) |
| INP-05 | Sharpened statement in report header | Report template structure |
| T1-01 | 5 diverse queries | Query taxonomy + single-call generation |
| T1-02 | Preflight gh auth + rate_limit | preflight.sh (D-27) |
| T1-03 | gh api search/repositories only, no WebSearch | gh-search.sh (D-28) |
| T1-04 | Verify top 5 candidates via gh api repos | verify-repo.sh (D-29); 404-drop hard rule |
| T1-05 | Metadata: stars, pushed_at, archived, default_branch, language | jq normalizer schema |
| T1-06 | Judge per-candidate LIKELY_MATCH/WORTH_INSPECTING/UNRELATED, README + metadata only | Rubric (D-16, D-18) |
| T1-07 | 🟢/🟡/🔴 verdict block | Mechanical aggregation (D-19) |
| T1-08 | Prompt user to opt into Tier 2 | Report footer (D-26) |
| T1-09 | ≤90s total for 3 golden inputs | Performance budget — gh api parallel fan-out pattern |
| JDG-01 | 5-axis rubric | judge-rubric.md (D-16) |
| JDG-02 | Integer scores with stated evidence | JSON schema for axis_scores |
| JDG-03 | Verdict mechanically derived | Threshold table in references |
| JDG-05 | Anti-novelty framing | Literal prompt line (specifics section) |
| JDG-06 | Devil's-advocate re-judge | D-20 conditional, budgeted |
| JDG-07 | Temperature 0 / lowest available | D-32 |
| HEUR-02 | Staleness flags: archived / >12mo / solo+>6mo | staleness.sh (D-21) |
| HEUR-03 | Badges, no auto-downgrade | D-22 |
| HEUR-04 | Mechanical in bash | staleness.sh implementation language |
| RPT-01 | `./reporecon-reports/YYYY-MM-DD-<slug>.md` | D-23 path scheme |
| RPT-02 (partial) | Header + per-candidate axis scores + URL + staleness + timestamp (no evidence file paths — Phase 2) | report-template.md (D-25) |
| RPT-04 | Per-candidate verification timestamp | D-25 "verified at {ISO timestamp}" |
| SCR-01 | gh-search.sh | D-28 |
| SCR-02 | verify-repo.sh | D-29 |
| SCR-05 | staleness.sh | D-21, D-30 |
| TST-01 | 3 golden fixtures | D-33 |
| TST-02 | Stable across 3 consecutive runs | D-34 — ship gate |
| JDG-04 (partial cap) | Tier 1 capped at WORTH_INSPECTING; ≥PARTIAL needs clone evidence (Phase 2) | D-18 explicit cap |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

| Constraint | Source | Phase 1 Implication |
|------------|--------|---------------------|
| Plugin format SKILL.md + plugin.json + marketplace.json + package.json | CLAUDE.md `## Project > Constraints` | All four files committed Wave 1 |
| Runtime tools: only `gh`, `git`, `WebSearch`, host LLM | CLAUDE.md | No Node/Python/MCP runtime in scripts; WebSearch deferred to Phase 2 by D-08 |
| Tier 1 ≤ 90s; ≤ 10 gh api calls | CLAUDE.md + REQ T1-09 | 5 search + 5 verify = 10. Parallel fan-out required. |
| `gh auth login` documented prereq | CLAUDE.md | preflight.sh enforces; SKILL.md mentions |
| Reports to `./reporecon-reports/` (gitignored by convention) | CLAUDE.md | Plan 1.1 must add `reporecon-reports/` to `.gitignore` |
| Each plan in isolated git worktree, one PR per plan | CLAUDE.md | Plans must touch disjoint files (Wave 1) |
| GSD entry points required | CLAUDE.md GSD Workflow Enforcement | Execution via `/gsd-execute-phase` |

## Summary

Phase 1 ships a **zero-runtime** Claude Code plugin: static JSON manifests + a ≤150-line `SKILL.md` + on-demand `references/*.md` + 4 POSIX-bash helper scripts wrapping `gh api`. The host LLM is the runtime. The trust-critical machinery (preflight gate, 404-verify gate, 5-axis integer rubric with mechanically derived verdict, anti-novelty judge prompt, devil's-advocate re-judge, mechanical staleness badges, idea sharpening with proper-noun guard) all ship day one — they are the product's promise, not enrichment.

Total external dependencies at runtime: `gh` CLI ≥2.55 (authed), `jq` ≥1.7, `bash` 4+. No Node, no Python, no MCP, no embeddings. Tier 1 budget: 5 search calls + 5 verify calls = 10 `gh api` calls; well under the 30/min search bucket and 5000/hr core bucket. End-to-end target ≤90s for 3 golden fixtures, achieved via parallel fan-out (background jobs / `xargs -P`) for the verify step.

**Primary recommendation:** Build the 11 plans in 3 waves as drawn in the roadmap. Wave 1 (5 disjoint-file plans) is fully parallelisable in worktrees; Wave 2 (SKILL.md wiring) serializes because every reference is linked from it; Wave 3 (golden iteration) is single-stream tuning until band-stability locks across 3 runs per fixture. Treat the marketplace schema as MEDIUM-confidence until re-verified at Wave 1 start via Context7 / direct fetch of `https://code.claude.com/docs/en/plugin-marketplaces` — schema drift is a documented Phase 1 risk.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Claude Code plugin format | current channel (2026-05) | Distribution + auto-discovery of `skills/`, `commands/`, `scripts/` | Anthropic-documented marketplace path [CITED: code.claude.com/docs/en/plugin-marketplaces] |
| Agent Skill (`SKILL.md` + YAML frontmatter) | open standard | LLM-readable orchestration prompt; progressive disclosure | Required by Claude Code skill subsystem [CITED: code.claude.com/docs/en/skills] |
| `gh` CLI | ≥ 2.55 | Auth + rate-aware GitHub REST/GraphQL access | Already a Claude Code prereq for most users; eliminates token plumbing [CITED: STACK.md] |
| `jq` | ≥ 1.7 | JSON slicing inside bash | Universally co-installed with gh; only reliable JSON parser in bash [CITED: STACK.md] |
| `bash` | ≥ 4.0 | `set -euo pipefail`, arrays, `mapfile` | POSIX baseline for helper scripts [CITED: STACK.md] |
| GNU `coreutils` (`timeout`, `mktemp`) | any | Bounded execution + per-run temp dirs (Tier 1 uses `mktemp` only) | macOS users need `brew install coreutils` [CITED: STACK.md] |

### Supporting (Phase 1 doesn't ship these, but design space hooks for them)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `git` ≥ 2.40 | runtime | Shallow clone | **Phase 2 only** — Tier 1 must not invoke it |
| Built-in `WebSearch` | host | Discovery breadth | **Phase 2 only** — D-08 forbids in Tier 1 |
| Built-in `Read` / `Grep` | host | File inspection | **Phase 2 only** — Tier 1 reads no third-party files |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pure-bash scripts | TypeScript + `tsx` | Adds Node runtime + install step; D-31 forbids |
| `gh api` direct | `gh search repos` high-level cmd | Friendlier but fewer filters (no `pushed:`, sort flexibility); we need raw |
| Schemastore `$schema` reference | Embedded local schema | Schemastore gives free IDE validation; embedding bloats repo |
| `effort: high` in skill frontmatter | `effort: medium` | Tier 1 is short; `high` costs latency without benefit |
| Single combined search+verify call | Separate scripts | Verification is the 404-gate; conflating burns the audit trail |

**Installation (developer machine, for golden CI):**
```bash
# Linux
sudo apt-get install gh jq
# or upgrade gh:  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg ...
gh auth login

# macOS
brew install gh jq bash coreutils
gh auth login
```

**Version verification:**
- `gh --version` must report ≥ 2.55 for `gh api --paginate --jq` stability [VERIFIED: STACK.md research dated 2026-05-26]
- `jq --version` must report ≥ 1.7 for `--rawfile` and stable error handling
- `bash --version` 4.0+ (macOS ships 3.2 by default — `brew install bash` needed)

> **Dev-environment note:** This worktree has `gh 2.4.0` (stale), `jq` missing, `git 2.34.1`. These are end-user-machine requirements for golden test CI. Plans 1.5 / 1.7 must either install fresh tools in GitHub Actions or document the version pinning in `tests/run-goldens.sh`.

## Architecture Patterns

### Recommended Phase 1 Plugin Structure

```
reporecon/                                  # repo root
├── .claude-plugin/
│   ├── plugin.json                         # Plan 1.1
│   └── marketplace.json                    # Plan 1.1
├── package.json                            # Plan 1.1 — marketplace metadata
├── LICENSE                                 # Plan 1.1 — minimal MIT (polish in Phase 3)
├── .gitignore                              # Plan 1.1 — includes reporecon-reports/
├── skills/
│   └── reporecon/
│       ├── SKILL.md                        # Plan 1.6 (Wave 2)
│       └── references/
│           ├── query-patterns.md           # Plan 1.3
│           ├── judge-rubric.md             # Plan 1.4
│           └── report-template.md          # Plan 1.3
├── scripts/
│   ├── preflight.sh                        # Plan 1.2
│   ├── gh-search.sh                        # Plan 1.2
│   ├── verify-repo.sh                      # Plan 1.2
│   └── staleness.sh                        # Plan 1.5
├── tests/
│   ├── golden/
│   │   ├── todo-cli.json                   # Plan 1.5  {idea, expected_verdict_band}
│   │   ├── obscure-niche.json              # Plan 1.5
│   │   └── llm-eval-dashboard.json         # Plan 1.5
│   └── run-goldens.sh                      # Plan 1.5 (scaffold) → Plan 1.7 (wires)
└── .github/
    └── workflows/
        └── goldens.yml                     # Plan 1.5 or 1.7 — CI scaffold (gates Phase 3)
```

**File-ownership (Wave 1 parallelism = disjoint sets):**

| Plan | Owns files (no other plan touches these in Wave 1) |
|------|-----------------------------------------------------|
| 1.1 | `.claude-plugin/*.json`, `package.json`, `LICENSE`, `.gitignore`, root `README.md` stub |
| 1.2 | `scripts/preflight.sh`, `scripts/gh-search.sh`, `scripts/verify-repo.sh` |
| 1.3 | `skills/reporecon/references/query-patterns.md`, `skills/reporecon/references/report-template.md` |
| 1.4 | `skills/reporecon/references/judge-rubric.md` |
| 1.5 | `scripts/staleness.sh`, `tests/golden/*.json`, `tests/run-goldens.sh`, `.github/workflows/goldens.yml` |
| 1.6 (Wave 2) | `skills/reporecon/SKILL.md` only (must wait for 1.1–1.5 merged) |
| 1.7 (Wave 3) | iterative edits across `references/*` and `SKILL.md` and golden fixtures — single agent, no parallel |

This satisfies the "Wave 1 disjoint files, parallel worktrees" constraint from CLAUDE.md and the orchestrator brief.

### Pattern 1: Manifest / Skill / Tool 3-Layer Split
**What:** Plugin = static JSON manifests (install-time) + `SKILL.md` prompt (load-time) + bash scripts (execute-time). LLM is the runtime.
**When:** Always for Claude Code plugins — the format demands it.
**Example:**
```json
// .claude-plugin/plugin.json — minimum viable
// Source: STACK.md + json.schemastore.org/claude-code-plugin.json
{
  "$schema": "https://json.schemastore.org/claude-code-plugin.json",
  "name": "reporecon",
  "version": "0.1.0",
  "description": "Validate whether your project idea already exists on GitHub before you build it.",
  "license": "MIT"
}
```

### Pattern 2: Progressive Disclosure of References
**What:** `SKILL.md` ≤ 150 lines, always loaded. References (`query-patterns.md`, `judge-rubric.md`, `report-template.md`) loaded only when SKILL.md instructs the LLM to `Read` them.
**When:** Any skill whose full documentation > 2K tokens.
**Example:**
```markdown
## Step 4: Judge each candidate
BEFORE judging, Read `${CLAUDE_PLUGIN_ROOT}/skills/reporecon/references/judge-rubric.md`.
For each verified candidate, invoke the judge prompt with temp 0, ONE candidate per call.
```

### Pattern 3: Prompt/Tool Separation (Mechanical = Bash, Judgment = LLM)
**What:** Anything that must be repeatable across runs (preflight, search, verify, staleness, slug generation) lives in bash. Anything requiring judgment (sharpening, query gen, axis scoring) stays in the LLM. The boundary is enforced by SKILL.md instructions.
**When:** Always for trust-critical orchestration skills.

### Pattern 4: Deterministic Wrappers over `gh`
**What:** LLM never composes raw `gh api` URLs. Always calls `scripts/gh-search.sh "<query>"` or `scripts/verify-repo.sh owner/repo`. Wrapper enforces flags, jq normalization, exit codes.
**When:** Always — URL-encoding bugs, missing pagination, inconsistent fields are otherwise inevitable.

### Pattern 5: Verdict-as-Data, Report-as-View
**What:** Judge phase emits structured JSON `{axis_scores, candidate_verdict, rationale}`. Report phase consumes that JSON + `report-template.md` to render markdown. Separate prompt sections.
**When:** When verdict logic must be auditable independently of prose.

### Pattern 6: 404-Verify Gate (HARD RULE)
**What:** No URL appears in any intermediate or final output without a `gh api /repos/{owner}/{repo}` 200 OK timestamped within the run. 404 → drop. SKILL.md states this in capital letters.
**When:** Always — it's the project's origin-bug fix.

### Anti-Patterns to Avoid

- **Stuffing all protocol into SKILL.md:** Pay full context cost every invocation. Push detail into `references/*.md`.
- **Letting the LLM construct `gh api` URLs:** URL-encoding bugs, missing fields. Use wrappers.
- **Free-form LLM verdict:** "Is this the same?" → flip-flop. Use mechanical derivation from axis scores.
- **Batching candidates into one judge call:** Cross-contamination. One candidate per call (D-17).
- **Bundling search + verify in one script:** Verification is the 404-gate; conflating burns the audit trail.
- **Trusting README claims without flag:** Tier 2 needs vapor check (deferred); Tier 1 must at least not over-weight README prose in axis scoring.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub API auth + rate-aware fetch | Token plumbing + curl + 401 retry | `gh api` | Already authed via `gh auth login`; handles GraphQL + REST + rate headers |
| JSON parsing in bash | grep / sed / awk on JSON | `jq` | One bracket-mismatched repo description and your regex eats stderr |
| Plugin/marketplace schema validation | Hand-written validator | `$schema` URL + schemastore | IDE-side validation free; updates track Anthropic releases |
| Per-run temp dir | hardcoded `/tmp/reporecon` | (Tier 1 doesn't need temp dirs — skip until Phase 2) | Collisions on parallel runs |
| Timestamp formatting | bespoke format strings | `date -u +%Y-%m-%dT%H:%M:%SZ` (ISO 8601) | Sortable, unambiguous, no locale games |
| Slug generation | regex chain in bash | `tr` + `sed` minimal pipeline OR LLM-emitted slug constrained to `[a-z0-9-]{1,40}` | Punctuation/unicode edge cases multiply; constrain at source |
| Rate-limit polling | While-loop on 403 | Preflight `gh api rate_limit` + early abort | Polling burns calls; abort is honest |
| Markdown report templating | Heredoc in bash | LLM renders from `report-template.md` placeholders | Templating engines = scope creep; LLM is already the runtime |
| YAML frontmatter parsing | bash regex | Claude Code's loader handles it | The skill loader is the consumer |

**Key insight:** The plugin is structurally a *configuration artifact*, not an application. The temptation to invent application-layer machinery (custom HTTP client, custom JSON parser, custom templater) is the largest threat to scope. Every helper script must be ≤ 50 lines.

## Common Pitfalls

(Selected from PITFALLS.md, filtered to Phase 1 scope. Phase 2 pitfalls — clone size, /tmp leaks, prompt injection, WebSearch noise — explicitly excluded.)

### Pitfall 1: LLM Judgment Flip-Flop on Borderline Repos
**What goes wrong:** Same idea + same candidate → EXACT one run, PARTIAL next.
**Why it happens:** Free-form judging has no anchor; temp/sampling/order all move it.
**How to avoid:** 5-axis integer rubric (D-16); mechanical verdict derivation (D-18); temp 0 (D-32); ONE candidate per judge call (D-17); log score vector in report (D-25).
**Warning signs:** Two runs differ on same repo; judge rationale lacks specifics; all-same-number axis rows.

### Pitfall 2: Confirmation Bias Toward "Your Idea Is Unique"
**What goes wrong:** Sycophantic model downgrades real matches because user wants novelty.
**Why it happens:** Idea text appears multiple times in context, reads as preferred framing.
**How to avoid:** Anti-novelty prompt line (literal text, per specifics section). Devil's-advocate re-judge on 🟢 with any axis ≥ 2 (D-20). Strip user's framing from judge context — pass only the sharpened sentence + the candidate metadata.
**Warning signs:** All candidates land at UNRELATED; rationale uses "the user's angle is different because…"; saturated golden (`todo-cli`) does not get 🔴.

### Pitfall 3: Hallucinated Repo Citation (The Origin Bug)
**What goes wrong:** Model invents plausible-looking GitHub URLs; report cites 404 repo; user clicks; trust gone.
**Why it happens:** Pretrained models confidently generate fake URLs; skipping verify "to save calls" tempts.
**How to avoid:** HARD RULE in SKILL.md: no URL in any output without `gh api /repos/...` 200 OK timestamped within the run (D-11). Judge step receives only verified candidates. Stating the rule prominently in SKILL.md is itself a guard.
**Warning signs:** Report URLs without "verified at" timestamp; user reports 404 — treat as P0.

### Pitfall 4: gh API Rate-Limit Exhaustion (and Silent Degradation)
**What goes wrong:** Tool hits 403; either crashes opaquely or silently downgrades.
**Why it happens:** Search bucket is 30/min (not the 5000/hr core); secondary rate limits hit on rapid sequential calls; unauthed users get 60/hr.
**How to avoid:** `scripts/preflight.sh` runs `gh auth status` + `gh api rate_limit`; aborts with actionable error if unauthed or core <50 or search <10. 200-500ms sleep between the 5 search calls to dodge secondary limits. Print rate budget consumed in report footer.
**Warning signs:** Search returns empty in CI but works locally; 403 in logs; intermittent results.

### Pitfall 5: Idea-Sharpening Distorts the User's Intent
**What goes wrong:** "NDIS invoice validator" rewritten as "billing compliance tool"; queries miss the narrow domain; verdict wrong.
**Why it happens:** LLMs over-generalize when asked to extract keywords; paraphrase to common phrasings.
**How to avoid:** Proper-noun guard (D-14) — extract `[A-Z]{2,}` and capitalized multi-word terms verbatim into "preserved terms," reinsert into sharpened sentence and queries. Show sharpened statement in report header so user can spot drift (D-15).
**Warning signs:** Generated queries don't contain user's original proper nouns; final report uses different terminology than input.

### Pitfall 6: Plugin Manifest Schema Drift
**What goes wrong:** Manifest copied from old plugin → install fails or fields silently ignored.
**Why it happens:** Marketplace schema evolves faster than tutorials.
**How to avoid:** Re-fetch `https://code.claude.com/docs/en/plugin-marketplaces` and the schemastore `$schema` URLs at Wave 1 start of Plan 1.1. Validate JSON against schema in CI (Plan 1.5 workflow scaffold can add a `jq`-or-`ajv`-based schema-check step).
**Warning signs:** Local install works, fresh-env install fails; schema linter warnings.

### Pitfall 7: Wave-1 Plan File Collisions
**What goes wrong:** Two parallel agents both edit `references/judge-rubric.md` or both touch `package.json` → merge conflict at PR time.
**Why it happens:** Plans not designed disjoint.
**How to avoid:** Use the "File-ownership" table above. Plan 1.1 owns root manifests; Plan 1.4 owns judge-rubric; Plan 1.3 owns query-patterns + report-template. Each plan lists its owned paths in the plan file's "Files Touched" section so the human reviewer can spot overlap before dispatch.
**Warning signs:** Two plans both list the same file; PR merge fails on text conflict.

### Pitfall 8: 90-Second Budget Blown by Sequential Verify Calls
**What goes wrong:** 5 search × ~1s + 5 verify × ~1s sequential + 5 judge LLM calls @ ~5s each = 35-60s plus sharpening/query-gen overhead; on slower LLM infra this blows 90s.
**Why it happens:** Default sequential bash + serial LLM calls.
**How to avoid:** Parallel fan-out for verify step (`xargs -P 5` or background jobs + `wait`). LLM-side: keep judge prompts terse (rubric loaded once, candidate metadata small). If LLM concurrency unavailable, judge calls serialize — design for ≤ 4s per judge call.
**Warning signs:** Wall-clock >90s on any golden fixture during Wave 3.

## Code Examples

### Preflight script skeleton
```bash
#!/usr/bin/env bash
# Source: D-12, D-27 + STACK.md gh rate-limit doc
set -euo pipefail

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login" >&2
  exit 1
fi

rate_json="$(gh api rate_limit 2>/dev/null)" || {
  echo "ERROR: gh api rate_limit failed (network? auth?)" >&2
  exit 2
}

core_rem=$(echo "$rate_json" | jq -r '.resources.core.remaining')
search_rem=$(echo "$rate_json" | jq -r '.resources.search.remaining')

if [[ "$core_rem" -lt 50 || "$search_rem" -lt 10 ]]; then
  echo "ERROR: gh rate budget too low (core=$core_rem search=$search_rem). Wait for reset." >&2
  exit 3
fi

# Print budget for SKILL.md to capture in report header
printf '{"core_remaining":%s,"search_remaining":%s}\n' "$core_rem" "$search_rem"
```

### Search wrapper (jq-normalized output)
```bash
#!/usr/bin/env bash
# Source: D-28 + STACK.md gh search example
set -euo pipefail
query="${1:?usage: gh-search.sh <query>}"

gh api -X GET search/repositories \
  -f q="$query" \
  -f sort=stars \
  -f order=desc \
  -f per_page=10 \
  --jq '[.items[] | {
    full_name,
    description,
    stars: .stargazers_count,
    pushed_at,
    archived,
    language,
    url: .html_url
  }]'
```

### Verify wrapper (404-gate)
```bash
#!/usr/bin/env bash
# Source: D-11, D-29
set -euo pipefail
repo="${1:?usage: verify-repo.sh <owner/repo>}"

if ! out="$(gh api "repos/${repo}" 2>/dev/null)"; then
  # 404 or other failure — drop the candidate
  exit 1
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "$out" | jq --arg ts "$ts" '{
  full_name,
  stars: .stargazers_count,
  pushed_at,
  archived,
  default_branch,
  language,
  url: .html_url,
  verified_at: $ts
}'
```

### Staleness badge emitter
```bash
#!/usr/bin/env bash
# Source: D-21, D-30
set -euo pipefail
meta="${1:?usage: staleness.sh <metadata-json>}"

archived=$(echo "$meta" | jq -r '.archived')
pushed_at=$(echo "$meta" | jq -r '.pushed_at')

now_s=$(date -u +%s)
pushed_s=$(date -u -d "$pushed_at" +%s 2>/dev/null || \
           date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$pushed_at" +%s)  # macOS fallback
age_d=$(( (now_s - pushed_s) / 86400 ))

badges=()
[[ "$archived" == "true" ]] && badges+=("archived")
[[ "$age_d" -gt 365 ]] && badges+=("stale-12mo")
# solo-stale-6mo requires contributor count → defer to follow-up gh api call;
# Plan 1.5 decides whether to do that here or in SKILL.md

echo "${badges[*]}"
```

### SKILL.md frontmatter (Plan 1.6)
```yaml
---
name: reporecon
description: |
  Validate whether a project idea already exists on GitHub before you build it.
  Triggers on `/reporecon <idea>`, "is there already a tool that does X",
  "validate my idea", "does this exist on github". Returns a 🟢/🟡/🔴 verdict
  in ~90 seconds using gh api metadata only.
allowed-tools:
  - Bash
  - Read
  - Write
effort: medium
---
```

### Judge prompt anti-novelty line (verbatim, per `<specifics>`)
> The user wants their idea to be novel. Resist this. Your job is to find matches, not validate originality.

This line MUST appear literally in `references/judge-rubric.md` and be loaded into context for every judge call.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WebFetch-based metadata | `gh api` via gh CLI | 2024+ | Auth + rate-aware + accurate star counts (origin bug was WebFetch hallucination) |
| Free-form LLM verdict | 5-axis integer rubric → derived verdict | Project's key decision | Deterministic across runs; auditable |
| README-only judgment | README + metadata (Tier 1); + cloned source (Tier 2) | Project's two-tier design | Avoids vapor false-positives; cited evidence |
| Embedded JSON schemas | `$schema` URLs at schemastore.org | 2025 | Free IDE validation; tracks Anthropic releases |
| Single-tier "search and answer" | Two-tier gate (fast / deep opt-in) | Project's UX decision | 80% of "does this exist" resolves <90s |

**Deprecated / outdated:**
- `gh api search/code` — 10/hr authed limit makes it unusable [VERIFIED: GitHub docs]
- WebFetch for GitHub metadata — produced wrong star counts in origin session [CITED: PITFALLS.md]
- npm distribution for Claude Code plugins — out of scope; marketplace install is the path

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Claude Code plugin schema as of 2026-05 still uses `.claude-plugin/plugin.json` + `marketplace.json` with `source: "./"` and `strict: true` | Code Examples / Architecture | Manifest must be re-validated against current docs at Wave 1 start; if changed, Plan 1.1 schema differs. Mitigation: Plan 1.1 first task = fetch `https://code.claude.com/docs/en/plugin-marketplaces`. |
| A2 | `${CLAUDE_PLUGIN_ROOT}` env var is set by Claude Code at skill runtime and resolves to the installed plugin directory | Code Examples (SKILL.md Read paths) | If undefined, SKILL.md must compute path differently (relative to invocation cwd). Verify at Wave 1 via reference plugin (anthropics/claude-plugins-official). |
| A3 | `effort: medium` is a valid SKILL.md frontmatter key in 2026 schema | Code Examples (frontmatter) | Listed in STACK.md sources (agensi.io, allahabadi.dev) but unofficial; re-verify against official docs. If invalid, drop the field — `name` + `description` + `allowed-tools` are the verified required/known fields. |
| A4 | gh search/repositories rate bucket is 30/min authed (separate from 5000/hr core) | Common Pitfalls #4 | If actually higher, preflight is over-cautious (harmless). If lower, 5 queries × per-run × CI parallel runs could trip. Verify via `gh api rate_limit` output at Wave 1. |
| A5 | macOS `date -u -d` doesn't work; `date -u -j -f` fallback needed | staleness.sh example | If wrong, staleness.sh breaks on macOS only — caught in dev. Plan 1.5 should add a sanity test. |
| A6 | Devil's-advocate re-judge on 🟢 with any axis ≥ 2 is calibrated correctly (D-20) | Pitfall #2 mitigation | If too aggressive, all 🟢 become 🟡 (false alarm). If too lax, false-novelty leaks. Wave 3 calibrates via `obscure-niche` golden — band must stay 🟢 across 3 runs. |
| A7 | Wall-clock per judge LLM call ≤ 4s on host Claude Code infra | Pitfall #8 | If higher, 5 sequential judge calls + sharpening + query gen blow 90s. Wave 3 measures; fallback is to reduce candidate count to 3 (drop 4th/5th from verify stage). |

**Status:** 7 assumptions, all flagged for Wave 1 / Wave 3 verification. None are silent.

## Open Questions

1. **Devil's-advocate re-judge prompt phrasing (D-20 is Claude's Discretion).**
   - What we know: trigger condition is 🟢 with any axis ≥ 2; budget at most 2 per run; mismatch downgrades 🟢 → 🟡.
   - What's unclear: exact prompt phrasing — "argue this idea already exists" vs "list the strongest case that this candidate IS the user's idea."
   - Recommendation: Plan 1.4 drafts two phrasings; Plan 1.7 picks the one that stabilizes the `obscure-niche` golden at 🟢 × 3 runs.

2. **Slug collision suffix scheme (D-23 is Claude's Discretion).**
   - What we know: filename = `YYYY-MM-DD-<slug>.md`; slug kebab-case ≤ 40 chars.
   - What's unclear: two runs same day same idea → overwrite, append `-2`, or refuse?
   - Recommendation: Plan 1.3 spec = if file exists, append `-N` where N is smallest integer ≥ 2 that doesn't collide. Documented in report-template.md.

3. **Fail-open vs fail-closed on malformed `gh api rate_limit` JSON (Claude's Discretion).**
   - Recommendation per CONTEXT.md: fail closed with actionable error ("could not parse rate_limit; run `gh api rate_limit` manually and retry"). Encode in preflight.sh.

4. **Where the solo-contributor-stale check lives (HEUR-02 `solo-stale-6mo`).**
   - What we know: needs contributor count, which is a separate `gh api /repos/{r}/contributors?per_page=1` call.
   - What's unclear: does staleness.sh fetch that, or does verify-repo.sh add it to the metadata blob?
   - Recommendation: verify-repo.sh adds `contributor_count` (one extra call per candidate × 5 = +5 calls; still well under budget). staleness.sh stays pure-derivation. Documented in Plan 1.2.

5. **Does Phase 1 ship a `commands/reporecon.md` slash-command file in addition to the SKILL.md frontmatter?**
   - What we know: D-06 says triggers in SKILL.md frontmatter; STACK.md mentions optional `commands/` auto-discovery.
   - What's unclear: whether `/reporecon` requires a `commands/reporecon.md` shim or fires purely from frontmatter triggers.
   - Recommendation: Plan 1.1 includes minimal `commands/reporecon.md` shim that invokes the skill. Cheap; eliminates "skill didn't fire" failure mode. If skill loads from frontmatter alone, the shim is harmless.

## Environment Availability

| Dependency | Required By | Available (dev) | Version | Fallback |
|------------|------------|-----------------|---------|----------|
| `gh` CLI | All Tier 1 scripts; CI golden runs | ✓ (stale) | 2.4.0 (need ≥ 2.55) | Plan 1.5 GitHub Actions installs current gh via official apt repo |
| `gh auth login` | preflight.sh; all gh api calls | ✓ | logged in as suleman-dawood | none — required |
| `jq` | All gh wrappers; staleness; tests | ✗ | — | `sudo apt install jq` for dev; GH Actions installs in CI |
| `bash` | All scripts | ✓ | 5.1.16 | — |
| `git` | none in Phase 1 (Phase 2 only) | ✓ | 2.34.1 (need 2.40 for Phase 2) | n/a for Phase 1 |
| GNU `date` / `coreutils` | staleness.sh | ✓ (Linux) | — | macOS needs `brew install coreutils` (gdate) — staleness.sh includes BSD `date -j -f` fallback |
| `mktemp` | n/a Phase 1 (Phase 2) | ✓ | — | n/a |
| Claude Code host | Skill runtime | assumed in user env | latest 2026-05 channel | none — required |

**Missing dependencies with no fallback:** `jq` on dev machine (one apt install away; CI installs automatically). `gh` ≥ 2.55 on dev machine (current 2.4.0 still works for most calls but Plan 1.5 CI must install ≥ 2.55 for `--paginate` / `--jq` guarantees).

**Missing dependencies with fallback:** None blocking.

**Action items for plans:**
- Plan 1.5 `.github/workflows/goldens.yml` MUST `apt-get install jq` and install gh via official apt repo to get ≥ 2.55.
- Plan 1.1 README stub mentions prereqs (`gh auth login`, `jq`, `bash 4+`) — Phase 3 README expands.

## Security Domain

*(Light section — Phase 1 has no untrusted-content surface since no clones and no WebSearch. Full security work concentrates in Phase 2.)*

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | `gh auth login` is the auth surface; we never handle tokens directly |
| V3 Session Management | no | stateless per-run |
| V4 Access Control | no | local plugin; no multi-user surface |
| V5 Input Validation | yes (light) | User idea is free-form NL; sharpening must not interpret it as instructions (anti-injection by separation in prompts). Slug derivation must sanitize → `[a-z0-9-]{1,40}` |
| V6 Cryptography | no | no secrets in Phase 1 |

### Known Threat Patterns for Phase 1 stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Hallucinated repo citation (origin bug) | Information Disclosure / Repudiation of evidence | HARD 404-verify gate (D-11); no URL without `gh api 200 OK` |
| User-idea-as-prompt-injection (idea contains "ignore previous instructions") | Tampering / Elevation | Sharpening prompt isolates user text; judge step receives only sharpened sentence + verified metadata, never raw idea text |
| Filename-path traversal via slug | Tampering | Slug regex strict `[a-z0-9-]{1,40}`; no `/` or `..` permitted |
| gh token leak via report | Information Disclosure | Report-template.md must never reference env vars or `gh auth` output; SKILL.md states this explicitly |
| Private-repo accidental disclosure | Information Disclosure | gh search/repositories returns only public repos by default — verify in Plan 1.2 wrapper that no `is:private` qualifier sneaks in |

## Sources

### Primary (HIGH confidence)

- `.planning/research/STACK.md` — full stack spec [CITED]
- `.planning/research/ARCHITECTURE.md` — 3-layer model + wave-parallel build order [CITED]
- `.planning/research/PITFALLS.md` — 11 pitfalls with mitigations [CITED]
- `.planning/research/SUMMARY.md` — synthesis [CITED]
- `.planning/REQUIREMENTS.md` — 54 v1 REQ-IDs with traceability [CITED]
- `.planning/ROADMAP.md` — Phase 1 plan structure (Wave 1 ×5 / Wave 2 / Wave 3) [CITED]
- `.planning/phases/01-tier-1-mvp-quick-verdict/01-CONTEXT.md` — 37 locked decisions [CITED]
- `CLAUDE.md` — project constraints, stack table [CITED]
- Claude Code plugin docs: https://code.claude.com/docs/en/plugin-marketplaces [CITED — re-verify Wave 1]
- Claude Code skills docs: https://code.claude.com/docs/en/skills [CITED — re-verify Wave 1]
- anthropics/claude-code marketplace.json: https://github.com/anthropics/claude-code/blob/main/.claude-plugin/marketplace.json [CITED reference]
- GitHub REST rate-limit docs: https://docs.github.com/en/rest/rate-limit/rate-limit [CITED]
- json.schemastore.org/claude-code-plugin.json / claude-code-marketplace.json [CITED]

### Secondary (MEDIUM confidence)

- agensi.io SKILL.md format reference [CITED — community]
- allahabadi.dev Claude Code skill frontmatter guide [CITED — community]
- cli/cli discussions #5381 and #7754 (rate-limit semantics) [CITED]

### Tertiary (LOW / re-verify)

- `effort: medium` frontmatter field [ASSUMED A3 — verify at Wave 1]
- `${CLAUDE_PLUGIN_ROOT}` env var availability [ASSUMED A2 — verify at Wave 1]

## Metadata

**Confidence breakdown:**
- Packaging / manifests: HIGH — schemastore + Anthropic docs + reference plugins
- Helper script patterns: HIGH — `gh api` + `jq` is standard
- 5-axis rubric design: MEDIUM — established in CONTEXT.md decisions; thresholds calibrated in Wave 3
- Anti-novelty + devil's-advocate effectiveness: MEDIUM — must validate on golden fixtures
- 90s budget: MEDIUM — depends on host LLM latency; parallel-verify mitigates
- Wave-disjoint file ownership: HIGH — explicit table

**Research date:** 2026-05-26
**Valid until:** 2026-06-25 (30 days for stable packaging; sooner if Claude Code plugin schema announces breaking change). Re-verify manifest schema at Wave 1 start of Plan 1.1.
