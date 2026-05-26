# Architecture Research

**Domain:** Claude Code plugin / skill — orchestration pipeline (idea → GitHub prior-art verdict)
**Researched:** 2026-05-26
**Confidence:** HIGH on plugin/skill structure (verified against current Claude Code plugin format and project's own PROJECT.md decisions); MEDIUM on internal pipeline component split (derived from project requirements + standard orchestration-skill patterns).

## Standard Architecture

A Claude Code plugin in 2026 is a directory of static assets the host LLM loads on demand. There is no runtime daemon, no MCP server (for this project — explicitly out of scope), no compiled binary. The "code" is split across three layers, each with a distinct role:

1. **Manifest layer** — plugin/marketplace JSON files. Identity, version, install metadata. Read by Claude Code at install time.
2. **Skill layer** — `SKILL.md` + reference docs. The orchestration *prompt* — protocol, decision rules, links to references. Read by the host LLM at invocation.
3. **Tool layer** — helper bash scripts + report templates. Stable, deterministic interfaces over `gh api` and `git clone`. Invoked by the LLM via the `Bash` tool.

The LLM is the runtime. It reads the skill, follows the protocol, and shells out to scripts for anything mechanical.

### System Overview

```
┌────────────────────────────────────────────────────────────────────┐
│                    USER (Claude Code session)                       │
│             /reporecon "open-source NDIS validator"                 │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ trigger phrase / slash command
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                      MANIFEST LAYER (install-time)                  │
│   plugin.json   marketplace.json   package.json   README.md         │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ Claude Code loads SKILL.md
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                  SKILL LAYER (LLM-readable prompts)                 │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ SKILL.md  — orchestration protocol, trigger phrases,         │  │
│  │            tier gate, references[…] links                    │  │
│  └─────┬────────────────────────────────────────────────────────┘  │
│        │ loads on demand (Progressive Disclosure)                   │
│  ┌─────▼────────────┐ ┌───────────────┐ ┌───────────────────────┐  │
│  │ references/      │ │ references/   │ │ references/           │  │
│  │ query-patterns.md│ │ judge-rubric  │ │ report-template.md    │  │
│  │ (Tier 1+2)       │ │ .md (5-axis)  │ │ (markdown skeleton)   │  │
│  └──────────────────┘ └───────────────┘ └───────────────────────┘  │
└──────┬──────────────────────────────────────────────────────────┬──┘
       │ invokes via Bash tool                  reads via Read tool│
       ▼                                                           │
┌──────────────────────────────────────────────────────────────────┴─┐
│                  TOOL LAYER (deterministic scripts)                 │
│  ┌──────────────────┐ ┌─────────────────┐ ┌────────────────────┐   │
│  │ scripts/         │ │ scripts/        │ │ scripts/           │   │
│  │ gh-search.sh     │ │ safe-clone.sh   │ │ vapor-check.sh     │   │
│  │ (gh api wrapper) │ │ (depth/size/TO) │ │ (file count + age) │   │
│  └────────┬─────────┘ └────────┬────────┘ └─────────┬──────────┘   │
└───────────┼────────────────────┼─────────────────────┼─────────────┘
            │                    │                     │
            ▼                    ▼                     ▼
      ┌──────────┐         ┌──────────┐         ┌──────────────┐
      │ gh CLI   │         │ git CLI  │         │  filesystem  │
      │ (GitHub) │         │ + /tmp   │         │ (cloned src) │
      └──────────┘         └──────────┘         └──────────────┘

                               ▲
                               │ LLM also calls WebSearch directly (Tier 2)
                               │
                       ┌───────┴────────┐
                       │ Built-in tools │
                       │ WebSearch /    │
                       │ Read / Grep    │
                       └────────────────┘

                                                          │ writes
                                                          ▼
                                         ./reporecon-reports/YYYY-MM-DD-<slug>.md
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `plugin.json` | Plugin identity, version, entrypoint, declared skills | Static JSON, ~20 lines |
| `marketplace.json` | Marketplace listing metadata (description, tags, screenshots) | Static JSON |
| `package.json` | npm metadata for `npx`-style install paths | Standard Node package manifest |
| `SKILL.md` | Orchestration protocol — trigger phrases, tier-1 vs tier-2 gate, "rules of the run", links to references | Markdown with YAML frontmatter |
| `references/query-patterns.md` | Catalogue of query templates (direct / synonym / tech-specific / domain-adjacent / negation) | Markdown, loaded on demand |
| `references/judge-rubric.md` | 5-axis structured rubric, verdict taxonomy (EXACT/SIGNIFICANT/PARTIAL/SUPERFICIAL/VAPOR), evidence requirements | Markdown |
| `references/report-template.md` | Markdown report skeleton with placeholders | Markdown template |
| `scripts/gh-search.sh` | Wrap `gh api` calls: search/code/repos, JSON-extract, 404 detection, rate-limit awareness | Bash + `jq` |
| `scripts/safe-clone.sh` | Depth-1 clone with 50MB size guard, 30s timeout, scoped to `/tmp/reporecon/<run-id>/` | Bash |
| `scripts/vapor-check.sh` | Mechanical heuristic: source file count, README:code ratio, last-meaningful-commit, archived flag | Bash + `find` + `git log` |
| `scripts/staleness.sh` | Mechanical flags: `archived`, `pushed_at >12mo`, single-contributor + `>6mo` | Bash + `jq` over gh JSON |
| `examples/` | Pre-canned reports from real runs (NDIS, FSANZ, bot classifier) — dogfooding + demo | Markdown files |
| `LLM (host model)` | Idea sharpening, query generation, equivalence judgment, negative-space synthesis, report prose | Claude (runtime, not shipped) |

## Recommended Project Structure

```
reporecon/
├── plugin.json                       # Claude Code plugin manifest
├── marketplace.json                  # Marketplace listing
├── package.json                      # npm metadata
├── README.md                         # Install + demo + dogfooding story
├── LICENSE                           # MIT (TBD)
│
├── skills/
│   └── reporecon/
│       ├── SKILL.md                  # Orchestration prompt (entry point)
│       └── references/
│           ├── query-patterns.md     # 5 query archetypes + examples
│           ├── judge-rubric.md       # 5-axis rubric + verdict taxonomy
│           ├── report-template.md    # Markdown skeleton
│           └── tier2-protocol.md     # Deep-inspection-only rules
│
├── scripts/
│   ├── gh-search.sh                  # gh api wrapper (Tier 1 + 2)
│   ├── safe-clone.sh                 # Bounded shallow clone (Tier 2)
│   ├── vapor-check.sh                # README/code-ratio heuristic
│   ├── staleness.sh                  # Archive/pushed_at flags
│   └── cleanup.sh                    # /tmp/reporecon/* TTL sweep
│
├── examples/
│   ├── ndis-validator-report.md
│   ├── fsanz-checker-report.md
│   └── bot-classifier-report.md
│
└── tests/
    ├── golden/                       # 3 golden idea inputs
    │   ├── saturated.txt             # known-already-exists domain
    │   ├── empty.txt                 # known-unique domain
    │   └── ambiguous.txt             # borderline case
    └── fixtures/                     # canned gh api JSON for offline runs
```

### Structure Rationale

- **`skills/reporecon/` not flat root:** Plugin format expects a `skills/<name>/` subtree. Keeps multi-skill expansion (e.g. a future `reporecon-monitor` skill) cheap.
- **`references/` under the skill:** Progressive-disclosure pattern. `SKILL.md` stays small (~150 lines, always loaded). References load on demand only when the LLM follows a link. Keeps context cost low when the skill auto-activates.
- **`scripts/` at plugin root, not under skill:** Helper scripts are *shared utilities*, not skill-specific prompts. Future skills can reuse `gh-search.sh`.
- **`tests/golden/`:** Three canonical inputs guarantee verdict stability across iterations. `fixtures/` makes development offline-friendly and fast.
- **`examples/` at root:** Doubles as marketing (README links to them) and regression evidence (real reports from real runs).

## Architectural Patterns

### Pattern 1: Two-Tier Pipeline with Explicit Gate

**What:** Tier 1 runs to completion and returns a verdict. The user is then asked: "Deep inspection? (y/n)". Tier 2 only runs on opt-in. Tier 1 has zero dependency on Tier 2 code.

**When to use:** Whenever a fast/cheap path satisfies the dominant use case (80% of "does this exist?" answers resolve at metadata level).

**Trade-offs:**
- Pro: Tier 1 ships independently. Tier 2 is a pure extension.
- Pro: Users in flow get answers in 90s; users who need depth get 10min depth.
- Con: Duplicate query-generation logic if not refactored — mitigate by sharing `references/query-patterns.md`.

**Example skill snippet:**
```markdown
## Tier 1 Protocol (always)
1. Sharpen idea (one sentence + 3-5 differentiator keywords)
2. Run scripts/gh-search.sh with 5 queries from query-patterns.md (Tier 1 set)
3. Verify top 5 results (gh api repos/OWNER/REPO — drop 404s)
4. Apply judge-rubric.md (metadata only — stars, description, topics, last push)
5. Emit verdict + ask: "Deep inspection? (y/n)"

## Tier 2 Protocol (on opt-in only)
→ See references/tier2-protocol.md
```

### Pattern 2: Prompt/Tool Separation (LLM Judgment vs Mechanical Heuristic)

**What:** Anything that must be repeatable across runs (vapor detection, staleness, 404 verification) lives in a bash script. Anything requiring judgment (equivalence, negative-space synthesis, query generation) stays in the LLM. The boundary is enforced by the skill prompt itself ("for vapor signal, run `scripts/vapor-check.sh` — do not estimate").

**When to use:** Any orchestration skill that must produce defensible verdicts. Without this boundary, LLM verdicts drift run-to-run and erode trust.

**Trade-offs:**
- Pro: Repeatable mechanical signals; reviewable bash; LLM only judges what it's good at.
- Pro: Scripts testable in isolation.
- Con: Two-language cognitive cost (markdown prompts + bash). Mitigated by keeping scripts <50 lines each.

### Pattern 3: Progressive Disclosure of References

**What:** `SKILL.md` is small and always loaded. It contains protocol + decision rules + *links* to references. The LLM follows links via `Read` only when it needs that section (e.g., reads `judge-rubric.md` only when entering the judgment phase).

**When to use:** Any skill whose full documentation would exceed ~2K tokens. Keeps the always-on cost minimal and gives the LLM "lazy" access to deep guidance.

**Trade-offs:**
- Pro: Minimal context footprint when skill auto-activates.
- Pro: Each reference is independently editable without re-validating the whole skill.
- Con: LLM may skip a reference it should have loaded. Mitigate by explicit instructions ("BEFORE judging, Read references/judge-rubric.md").

### Pattern 4: Deterministic Wrappers Over `gh` and `git`

**What:** Never let the LLM compose raw `gh api` URLs or `git clone` commands directly. Always go through `scripts/gh-search.sh "query"` and `scripts/safe-clone.sh <url>`. The wrapper enforces depth, size, timeout, JSON parsing, and error format.

**When to use:** Whenever you need bounded execution and consistent output. Critical for `git clone` (a 5GB monorepo would melt `/tmp`).

**Trade-offs:**
- Pro: Single chokepoint for safety guards. One place to add caching later.
- Pro: LLM gets clean structured output (one JSON object per repo, not raw `gh` text).
- Con: Extra indirection for the reader. Mitigate with comment headers on each script.

### Pattern 5: Verdict-as-Data, Report-as-View

**What:** The judgment phase produces a structured intermediate (5-axis scores per candidate + verdict + evidence list). The report-generation phase consumes that intermediate and renders markdown. They're separate prompt sections.

**When to use:** When you want the verdict logic auditable independently of the prose. Also enables future JSON output mode without rewriting judgment.

## Data Flow

### End-to-End Pipeline

```
[USER: /reporecon "<idea>"]
         │
         ▼
┌──────────────────────┐
│ 1. SHARPEN  (LLM)    │ idea → {sentence, keywords[3-5]}
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 2. QUERY GEN (LLM)   │ + references/query-patterns.md
│                      │ → 5 Tier-1 queries
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 3. DISCOVER (script) │ scripts/gh-search.sh × 5
│                      │ → candidates[] (raw)
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 4. VERIFY (script)   │ gh api repos/<owner>/<repo> for top 5
│                      │ → verified[] (drop 404s, attach metadata)
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 5. JUDGE-METADATA    │ + references/judge-rubric.md (metadata mode)
│    (LLM)             │ → {verdict, per-candidate-score[]}
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 6. EMIT TIER 1       │ + references/report-template.md
│    (LLM)             │ → ./reporecon-reports/YYYY-MM-DD-<slug>.md
│                      │   "Run deep inspection? (y/n)"
└──────────┬───────────┘
           │
       ╔═══╧═══╗
       ║ GATE  ║ ── n ──► [DONE]
       ╚═══╤═══╝
           │ y
           ▼
┌──────────────────────┐
│ 7. EXPAND QUERIES    │ + references/query-patterns.md (Tier 2 set)
│    (LLM)             │ → 10-15 queries
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 8. BROAD DISCOVER    │ WebSearch (LLM-direct) + gh-search.sh
│    (LLM + script)    │ → expanded candidates[]
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 9. CLONE  (script)   │ safe-clone.sh top 5-8 → /tmp/reporecon/<id>/
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 10. INSPECT          │ Read/Grep on cloned tree
│     (LLM + Read)     │ + scripts/vapor-check.sh + scripts/staleness.sh
│                      │ → evidence[] (file paths, code excerpts, flags)
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 11. JUDGE-DEEP (LLM) │ + references/judge-rubric.md (full 5-axis)
│                      │ → {final verdict, evidence-cited scores}
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 12. NEGATIVE SPACE   │ → "your unique angle" — features absent from all
│     (LLM)            │   inspected candidates
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 13. EMIT TIER 2      │ updates ./reporecon-reports/<same file>.md
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 14. CLEANUP (script) │ rm -rf /tmp/reporecon/<id>/
└──────────────────────┘
```

### Key Data Flows

1. **Idea → structured query set:** Free text → `{sentence, keywords[]}` → query templates instantiated against keywords. The sharpening step is what makes downstream queries diverse rather than rephrasings of the input.
2. **Candidate → verified candidate:** Raw `gh search` results get a second `gh api repos/...` round to confirm existence (kills hallucinated/retired repos) and attach trustworthy metadata (stars from API, not scraped).
3. **Verified → judged:** The judge consumes verified candidates + rubric. Critically, it must cite evidence (URL fields in Tier 1, file paths in Tier 2 ≥ PARTIAL_OVERLAP).
4. **Judged → report:** Structured verdict object → markdown template → file on disk. The file is the source of truth; chat output mirrors it.
5. **Tier 1 verdict ⇢ Tier 2 trigger:** Tier 1 is *not* re-run by Tier 2. Tier 2 inherits Tier 1's verified candidates, expands the search, and deepens judgment. This is why query-patterns.md has two sets (Tier 1 = 5 conservative; Tier 2 = 10-15 with negation queries).

### State Management

No persistent state across runs in v1. Per-run state lives in:
- `/tmp/reporecon/<run-id>/` — clones, scratch JSON, scoped to one run
- `./reporecon-reports/<date>-<slug>.md` — the only durable output

Run-id = `YYYYMMDD-HHMMSS-<idea-slug>`. Cleanup script enforces TTL (delete `/tmp/reporecon/*` >24h old on every run start).

## Suggested Build Order

The phase plan in PROJECT.md (Tier 1 MVP → Tier 2 Deep Inspection → Polish + Marketplace) maps cleanly to the architecture. Within each phase there is significant wave-parallel opportunity.

### Phase 1 — Tier 1 MVP

**Wave 1 (fully parallel — no inter-dependencies):**
- `plugin.json` + `marketplace.json` + `package.json` skeleton (manifest layer)
- `scripts/gh-search.sh` (tool layer — testable standalone with any query)
- `references/query-patterns.md` Tier 1 set (5 archetypes)
- `references/report-template.md` (markdown skeleton — no logic)
- `tests/golden/*.txt` + `tests/fixtures/*.json` (canned gh JSON)

**Wave 2 (depends on Wave 1):**
- `references/judge-rubric.md` (depends on query-patterns to know what evidence is available)
- `SKILL.md` Tier 1 protocol (depends on all references existing — it links to them)

**Wave 3 (depends on Wave 2):**
- Golden-test runs against fixtures; iterate skill + rubric until 3/3 verdicts stable

**Pluggability boundary:** End of Phase 1 = a shippable tier-1-only plugin. Tier 2 code does not exist yet. The `SKILL.md` should already contain the "Deep inspection? (y/n)" prompt, with the `y` branch saying *"Tier 2 not yet available — re-run with `--deep` once Phase 2 ships."*

### Phase 2 — Tier 2 Deep Inspection

**Wave 1 (parallel):**
- `scripts/safe-clone.sh` (tool — testable against any public repo)
- `scripts/vapor-check.sh` (tool — testable against a fixture repo dir)
- `scripts/staleness.sh` (tool — testable against fixture JSON)
- `references/query-patterns.md` Tier 2 expansion (10-15 archetypes, negation queries)
- `references/tier2-protocol.md` (deep-inspection-specific rules)

**Wave 2:**
- Extend `references/judge-rubric.md` with file-path evidence requirements for ≥ PARTIAL_OVERLAP
- Update `SKILL.md` to wire the `y` branch to `tier2-protocol.md`

**Wave 3:**
- Golden-test full-pipeline runs (no fixtures — real `gh` + real `git clone`). Tune timeouts and size guards.

**Pluggability boundary:** Vapor heuristic and staleness flags can ship in a Phase 2.1 patch if Phase 2 runs long. The skill already produces a valid Tier 2 report without them — they're enrichment, not gates.

### Phase 3 — Polish + Marketplace

**Fully parallel — three independent tracks:**
- Track A: dogfood runs against LabelLens + NDISBulkValidator → populate `examples/`
- Track B: README with demo GIF, install instructions, marketplace screenshots
- Track C: `marketplace.json` final copy + submission checklist

### Parallelism Summary

| Phase | Max parallel agents | Bottleneck |
|-------|---------------------|------------|
| 1 | 5 (Wave 1) | Single-thread Wave 2 → Wave 3 |
| 2 | 5 (Wave 1) | Single-thread Wave 2 → Wave 3 |
| 3 | 3 (all waves parallel) | Marketplace submission is sequential |

This matches the project's stated "wave-parallel agents per phase using isolated worktrees, one PR per plan" execution model.

## Scaling Considerations

| Scale | Adjustments |
|-------|-------------|
| 1-10 runs/day (current target) | No changes. Per-run state in `/tmp` is fine. |
| 100 runs/day | Add idea-hash cache (deferred to v1.1 per PROJECT.md). Cache key = SHA of sharpened sentence + keywords. TTL 7 days. |
| 1000+ runs/day | Not a v1 concern. Would imply hosted mode, which is explicitly out of scope. |

### Scaling Priorities

1. **First bottleneck: `gh` rate limit** (5000/hr authenticated). At 50 calls per Tier 2 run, that's 100 deep-inspections/hr ceiling. Mitigation if hit: in-memory dedupe of identical queries within a run, cache `repos/OWNER/REPO` lookups for 24h.
2. **Second bottleneck: `/tmp` space.** 50MB × 8 clones = 400MB per run. TTL cleanup on each run start handles steady-state. If 100 concurrent runs ever happens (it won't in v1), add per-run subdirectory quotas.

## Anti-Patterns

### Anti-Pattern 1: Stuffing All Protocol into `SKILL.md`

**What people do:** Cram the rubric, query templates, and report skeleton into a 1500-line `SKILL.md`.
**Why it's wrong:** Every invocation pays the full context cost. The LLM also gets less reliable as the prompt grows.
**Do this instead:** Keep `SKILL.md` ≤150 lines. Push everything reference-shaped into `references/*.md` and link by relative path.

### Anti-Pattern 2: Letting the LLM Compose Raw `gh api` URLs

**What people do:** `SKILL.md` says "run `gh api search/repositories?q=...`" — and the LLM happens to construct the URL each time.
**Why it's wrong:** URL-encoding bugs, missing pagination, no error normalization, inconsistent fields across runs.
**Do this instead:** `scripts/gh-search.sh "query"` returns normalized JSON. The skill calls the script, not the API.

### Anti-Pattern 3: LLM-Judged Vapor / Staleness

**What people do:** Ask the LLM "is this repo abandoned?" based on metadata it just read.
**Why it's wrong:** Non-deterministic. Same repo, different verdict across runs. Erodes trust.
**Do this instead:** Mechanical heuristic in `scripts/vapor-check.sh` and `scripts/staleness.sh`. Output: boolean flags. LLM may *contextualize* the flag but does not *decide* it.

### Anti-Pattern 4: Cloning Without Bounds

**What people do:** `git clone --depth 1 <url>` directly from the skill.
**Why it's wrong:** A monorepo or LFS repo can fill `/tmp` and hang the session. No timeout = stuck runs.
**Do this instead:** `scripts/safe-clone.sh` enforces depth, 50MB cap, 30s timeout, per-run subdir.

### Anti-Pattern 5: Single-Tier Pipeline With "Streaming" Verdicts

**What people do:** One long pipeline that emits partial reports as it goes.
**Why it's wrong:** Mixes the fast path with the slow path. Users in flow get interrupted by 8-minute clones. Failure modes multiply.
**Do this instead:** Hard gate between Tier 1 and Tier 2. Tier 1 is a complete product. Tier 2 is an opt-in extension.

### Anti-Pattern 6: Free-Form Equivalence Judgment

**What people do:** "LLM, is this repo the same as the user's idea? Yes/no."
**Why it's wrong:** Verdicts flip on rephrased input. Confirmation bias creeps in. No audit trail.
**Do this instead:** 5-axis rubric (core function, audience, scope, approach, activity). Verdict *derived* from axis scores. Evidence (file paths or URLs) required for any score ≥ PARTIAL.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| GitHub REST API | `gh api` via `gh-search.sh` wrapper | Requires `gh auth login`. Document this in README. Rate limit 5000/hr authed. |
| GitHub via `git` | `git clone --depth 1` via `safe-clone.sh` | Same auth as `gh` CLI. Bound by size/depth/timeout. |
| WebSearch | LLM-direct (built-in Claude Code tool) | Tier 2 only. Quality opaque — acceptable because user opted in. |
| Filesystem (`/tmp`) | Per-run subdir with TTL cleanup | Cleanup script runs at start, not end (prior run may have crashed). |
| Filesystem (`./reporecon-reports/`) | Markdown file output | Gitignored by convention. Slug-based filename. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| SKILL.md ↔ references/ | LLM reads via `Read` tool when prompted | Progressive disclosure. Each reference is loadable in isolation. |
| SKILL.md ↔ scripts/ | LLM invokes via `Bash` tool | Scripts return stdout JSON or formatted text. Non-zero exit = LLM-readable error on stderr. |
| Tier 1 ↔ Tier 2 | One-way handoff (Tier 1 verified candidates → Tier 2 expansion) | Tier 1 stands alone. Tier 2 never modifies Tier 1's verdict logic. |
| Judge ↔ Report | Structured intermediate object (in-context, not file) | Decouples verdict logic from prose rendering. |

## Sources

- /home/suleman/Documents/Projects/AI_Projects/RepoRecon/.planning/PROJECT.md (project requirements, decisions, constraints — HIGH confidence)
- /home/suleman/Documents/Projects/AI_Projects/RepoRecon/PROJECT.md (idea document, workflow definition, skill structure sketch — HIGH confidence)
- Anthropic Claude Code skill format documentation (plugin.json + skills/ + references/ convention — HIGH confidence on structure, MEDIUM on exact marketplace.json schema until verified against current docs at packaging time)
- Standard orchestration-skill patterns (progressive disclosure, prompt/tool separation, deterministic wrappers) — derived from current Claude Code plugin ecosystem norms (MEDIUM, worth verifying against 2-3 published plugins during Phase 1 Wave 1)

---
*Architecture research for: Claude Code plugin — GitHub prior-art validator with two-tier orchestration*
*Researched: 2026-05-26*
