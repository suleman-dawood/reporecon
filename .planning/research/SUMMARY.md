# Project Research Summary — RepoRecon

**Project:** RepoRecon
**Domain:** Claude Code plugin / skill — GitHub prior-art validator for project ideas
**Researched:** 2026-05-26
**Confidence:** HIGH

## Executive Summary

RepoRecon is a zero-runtime Claude Code plugin (SKILL.md + bash helper scripts + manifest JSON). The "stack" is a static package the host LLM loads on demand, shelling out to `gh`, `git`, `jq`, plus built-in `WebSearch`/`Read`/`Grep`. Three layers: manifest (install-time JSON), skill prompt (LLM-readable orchestration with progressive disclosure of references), tool layer (deterministic bash wrappers over `gh api` and `git clone`).

Two-tier pipeline with a hard gate. Tier 1 = sub-90s metadata-only verdict (~10 `gh api` calls, 5 diverse queries, derived 5-axis rubric). Tier 2 = opt-in 5-10 min deep inspection (WebSearch breadth + safe shallow clones + file-path-cited equivalence + negative-space "your angle"). Wedge = the *combination* idea-input + 404-verify + clone inspection + structured rubric + evidence — no competitor composes all of these.

Key risks: LLM-judgment trust (flip-flop, confirmation bias), adversarial inputs (README prompt injection, hallucinated citations — the origin bug), operational safety (clone size blow-up, /tmp leaks, rate-limit exhaustion), marketplace mechanics (schema drift, trigger collisions). Mitigations designed-in: structured rubric with derived verdicts, mechanical heuristics for vapor/staleness, `<untrusted_content>` delimiters around cloned text, hard 404-verification gate, safe-clone wrapper (size + timeout + trap-cleanup), `gh auth` + `gh api rate_limit` preflight.

## Key Findings

### Recommended Stack
Pure-bash plugin. No Node, no MCP, no embeddings.

- Claude Code plugin format (`.claude-plugin/plugin.json` + `marketplace.json`) — repo doubles as single-plugin marketplace for v1
- Agent Skill (`skills/reporecon/SKILL.md` + `references/`) — progressive disclosure; SKILL.md ≤150 lines
- `gh` CLI ≥ 2.55 via `gh api` — authed, rate-aware
- `git` ≥ 2.40 with `--depth 1 --filter=blob:none --single-branch --no-tags` — wrapped by safety guards
- `jq` ≥ 1.7
- Built-in `WebSearch` / `Read` / `Grep`
- POSIX bash 4+ helper scripts under `scripts/`

Prereqs: `gh auth login`; macOS `brew install bash coreutils`.

### Expected Features

**Must have:** NL idea input + LLM query expansion; live `gh api` metadata; 404 verification on every cited repo; ranked candidates with evidence; markdown report to `./reporecon-reports/YYYY-MM-DD-<slug>.md`; mechanical staleness; safe local cloning; Tier 1 <90s.

**Differentiators:** two-tier output; 5-axis rubric → derived verdict (EXACT/SIGNIFICANT/PARTIAL/SUPERFICIAL/VAPOR); evidence-cited verdicts; mechanical vapor heuristic; confirmation-bias-resistant judge; negative-space report; clone inspection of source; dual WebSearch+`gh api` discovery (Tier 2); idea sharpening with proper-noun preservation.

**Defer:** idea-hash caching, privacy mode, GitLab/Codeberg/registries, embeddings, MCP, CLI/`gh` extension, auto-monitoring.

### Architecture

Three layers:
1. Manifest layer (`plugin.json`, `marketplace.json`)
2. Skill layer (`SKILL.md` + `references/query-patterns.md`, `judge-rubric.md`, `report-template.md`, `tier2-protocol.md`)
3. Tool layer (`gh-search.sh`, `safe-clone.sh`, `vapor-check.sh`, `staleness.sh`, `cleanup.sh`)
4. LLM (host) — sharpening, query gen, judgment, prose
5. Tests + examples (`tests/golden/`, `tests/fixtures/`, `examples/`)

Patterns: prompt/tool separation (mechanical=bash, judgment=LLM); progressive disclosure; deterministic wrappers; verdict-as-data + report-as-view.

### Critical Pitfalls

1. **Judge flip-flop** — 5-axis integer rubric, derived verdict, evidence-required ≥PARTIAL, temp=0, one judge call per candidate.
2. **Confirmation bias toward novelty** — anti-novelty framing; devil's-advocate re-judge on GREEN; strip original pitch from judge context.
3. **README prompt injection** — `<untrusted_content>` delimiters, ~3000 char truncation, HTML-comment / zero-width sanitization, isolated sub-agent for inspection.
4. **Hallucinated citations (origin bug)** — HARD RULE: no URL in output without `gh api repos/OWNER/REPO` 200 OK timestamped within the run.
5. **Clone size blow-up + /tmp leaks** — pre-check `gh api .size` (50MB cap), `GIT_LFS_SKIP_SMUDGE=1`, `--filter=blob:limit=1m`, `timeout 60s`, `mktemp -d`, `trap 'rm -rf' EXIT INT TERM`, boot-time sweep.
6. **`gh` rate-limit exhaustion** — preflight `gh api rate_limit` + `gh auth status`; track 30/min search bucket separately; never use `/search/code`.
7. **Sharpening distorts intent** — preserve proper nouns; show sharpened statement in report header.

## Implications for Roadmap

Three-phase plan maps cleanly. Each phase has Wave-1 parallelism (3-5 independent tracks).

### Phase 1: Tier 1 MVP
Shippable on its own. All trust-critical features day-one (404 verify, 5-axis rubric, sharpening, mechanical staleness, confirmation-bias guard).
Waves: W1 (×5) manifests + `gh-search.sh` + Tier 1 query-patterns + report-template + golden fixtures. W2: judge-rubric + SKILL.md Tier 1 protocol. W3: golden-test iteration.
Addresses pitfalls: 1, 2, 4, 6, 7.

### Phase 2: Tier 2 Deep Inspection
Pure extension. All clone-handling pitfalls concentrate here.
Waves: W1 (×5) safe-clone + vapor-check + staleness + Tier 2 query patterns + tier2-protocol. W2: rubric extension + SKILL.md Tier 2 wiring. W3: real-network golden runs.
Addresses pitfalls: 3, 5.

### Phase 3: Polish + Marketplace
Three independent tracks. Manifest finalization + README/demo + dogfooded examples; schema validation; fresh-env install; submission.

### Research Flags
- Phase 1: verify current Claude Code plugin schema via Context7/official docs before Wave 1 manifest work.
- Phase 2: prompt-injection sub-agent isolation patterns; `GIT_LFS_SKIP_SMUDGE` with partial clones.
- Phase 3: re-verify marketplace schema + submission process immediately before submission.

## Confidence Assessment

| Area | Confidence |
|------|------------|
| Stack | HIGH |
| Features | HIGH |
| Architecture | HIGH on structure, MEDIUM on internal split |
| Pitfalls | HIGH |

**Overall:** HIGH

### Gaps to Address
- Marketplace schema drift — verify at Phase 1 start and Phase 3 submission. Reserve `reporecon` name early.
- Sub-agent tool restriction — verify in Phase 2; fall back to delimiters + sanitization.
- WebSearch quality calibration — calibrate during Phase 2 golden runs; >20% 404 rate = P0 bug.
- Trigger collision — verify `/reporecon` unique at Phase 3.
- macOS toolchain — document `brew install bash coreutils` in README.
- Devil's-advocate re-judge cost — budget-tune in Phase 1 W3.

## Sources

Primary: PROJECT.md; Claude Code official docs (plugin marketplaces, skills); anthropics/claude-code marketplace.json; GitHub REST rate-limit docs; `git` documentation; schemastore.org schemas.
Secondary: cli/cli discussions #5381 + #7754; SKILL.md format refs; indirect-prompt-injection literature.
