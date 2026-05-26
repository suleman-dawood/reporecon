# Roadmap: RepoRecon

**Created:** 2026-05-26
**Granularity:** coarse (3 phases)
**Total v1 requirements:** 51
**Coverage:** 51/51 mapped

## Core Value

Given a fuzzy project idea, RepoRecon returns a trustworthy, evidence-cited verdict on whether it already exists on GitHub — fast enough not to interrupt flow, deep enough to act on.

## Phases

- [ ] **Phase 1: Tier 1 MVP (Quick Verdict)** — Shippable plugin that returns a 🟢/🟡/🔴 verdict in <90s using metadata only
- [ ] **Phase 2: Tier 2 Deep Inspection** — Opt-in extension: WebSearch + safe clones + evidence-cited equivalence + negative-space report
- [ ] **Phase 3: Polish + Marketplace** — README, demo, dogfooded examples, marketplace submission

## Phase Details

### Phase 1: Tier 1 MVP (Quick Verdict)
**Goal:** Ship a standalone, installable Claude Code plugin that answers "does this exist?" with a metadata-only verdict in under 90 seconds, with no hallucinated URLs and confirmation-bias-resistant judgment.
**Depends on:** Nothing (first phase)
**Requirements:** PKG-01, PKG-02, PKG-04, INP-01, INP-02, INP-03, INP-04, INP-05, T1-01, T1-02, T1-03, T1-04, T1-05, T1-06, T1-07, T1-08, T1-09, JDG-01, JDG-02, JDG-03, JDG-05, JDG-06, JDG-07, HEUR-02, HEUR-03, HEUR-04, RPT-01, RPT-02, RPT-04, SCR-01, SCR-02, SCR-05, TST-01, TST-02
**Success Criteria** (what must be TRUE):
  1. User can install the plugin from a single GitHub repo via Claude Code marketplace and invoke `/reporecon <idea>`
  2. Running `/reporecon X` on any of the 3 golden test inputs returns a verdict block (🟢/🟡/🔴) in under 90 seconds
  3. Every candidate URL in the report is verified live via `gh api` within the run (no hallucinated repos)
  4. Report header shows the sharpened "what / for whom / how" statement with proper nouns preserved
  5. Verdict is mechanically derived from 5-axis integer scores (not asked free-form of the LLM), and stable across 3 consecutive runs on each golden input
**Plans:** 7 plans
**Plans (wave-parallel):**
  - **Wave 1 (independent, disjoint files):**
    - [ ] `01-01-PLAN.md` — Plugin manifests + packaging scaffolding (`plugin.json`, `marketplace.json`, `package.json`, LICENSE, .gitignore, README stub, commands/reporecon.md)
    - [ ] `01-02-PLAN.md` — `scripts/preflight.sh` + `scripts/gh-search.sh` + `scripts/verify-repo.sh` (deterministic `gh api` wrappers + 404 gate + auth/rate preflight)
    - [ ] `01-03-PLAN.md` — `skills/reporecon/references/query-patterns.md` (5-query taxonomy + sharpening + proper-noun rule) + `references/report-template.md`
    - [ ] `01-04-PLAN.md` — `skills/reporecon/references/judge-rubric.md` (5-axis integer rubric + mechanical derivation + anti-novelty + devil's-advocate)
    - [ ] `01-05-PLAN.md` — `scripts/staleness.sh` + `tests/golden/*.json` (3 fixtures) + `tests/run-goldens.sh` scaffold + `.github/workflows/goldens.yml`
  - **Wave 2 (serializes on SKILL.md):**
    - [ ] `01-06-PLAN.md` — `skills/reporecon/SKILL.md` Tier 1 orchestration (7-step protocol: preflight → sharpen → query gen → discover → verify → judge → emit report)
  - **Wave 3 (validation):**
    - [ ] `01-07-PLAN.md` — Golden-test iteration: wire run-goldens.sh, tune queries/judge/re-judge phrasing, lock band stability × 3 runs and ≤90s wall-clock

### Phase 2: Tier 2 Deep Inspection
**Goal:** Add an opt-in deep-inspection mode that clones top candidates safely, judges equivalence with file-path evidence, applies the vapor heuristic, and writes the negative-space "your angle" section.
**Depends on:** Phase 1
**Requirements:** T2-01, T2-02, T2-03, T2-04, T2-05, T2-06, T2-07, T2-08, T2-09, T2-10, JDG-04, HEUR-01, RPT-03, SCR-03, SCR-04, TST-03, TST-04
**Success Criteria** (what must be TRUE):
  1. After a Tier 1 yellow/red verdict, user can opt in and receive the full 5-level verdict (EXACT_MATCH / SIGNIFICANT_OVERLAP / PARTIAL_OVERLAP / SUPERFICIAL_MATCH / VAPOR) within 10 minutes for golden inputs
  2. Every verdict at PARTIAL_OVERLAP or stronger cites at least one file path from a clone; SUPERFICIAL_MATCH otherwise
  3. Safe-clone wrapper rejects repos >50MB, kills clones exceeding 60s, skips LFS, and cleans `/tmp/reporecon/` on exit/interrupt/terminate (verified by planted oversize/timeout fixtures)
  4. Cloned README/source is treated as untrusted (delimited, truncated to ~3000 chars, sanitized) — planted prompt-injection fixture does not alter the verdict
  5. Report includes a "your angle" section listing features in the user's idea absent from all inspected candidates
**Plans:** 7 plans
**Plans (wave-parallel):**
  - **Wave 1 (independent, disjoint files):**
    - [ ] `02-01-PLAN.md` — `scripts/safe-clone.sh` + test harness (size pre-check, GIT_LFS_SKIP_SMUDGE=1, --filter=blob:none, timeout, mktemp + trap cleanup)
    - [ ] `02-02-PLAN.md` — `scripts/vapor-check.sh` + test harness (README-claims-vs-source-files heuristic, archived/stale gates)
    - [ ] `02-03-PLAN.md` — `skills/reporecon/references/tier2-protocol.md` (WebSearch + 10 expanded gh api queries, dedupe, 404-verify gate, untrusted_content protocol)
    - [ ] `02-04-PLAN.md` — `skills/reporecon/references/judge-rubric.md` + `report-template.md` extensions (Tier 2 5-level derivation, JDG-04 evidence rule, Your Angle section)
    - [ ] `02-05-PLAN.md` — `tests/fixtures/` planted prompt-injection README + planted vapor repo
  - **Wave 2 (serializes on SKILL.md):**
    - [ ] `02-06-PLAN.md` — `skills/reporecon/SKILL.md` Tier 2 wiring (opt-in gate, expanded discovery, clone loop with untrusted-content protocol, derived 5-level verdict, Your Angle synthesis)
  - **Wave 3 (validation):**
    - [ ] `02-07-PLAN.md` — Extend `tests/run-goldens.sh` + new Tier 2 fixture goldens + CI matrix; verify ≤10min Tier 2 budget; stability ×3 runs

### Phase 3: Polish + Marketplace
**Goal:** Ship the plugin to the Claude Code marketplace with a discoverable README, working demo, dogfooded examples, and license.
**Depends on:** Phase 2
**Requirements:** PKG-03, PKG-05, TST-05
**Success Criteria** (what must be TRUE):
  1. README.md at repo root shows install instructions, `gh auth login` prerequisite, macOS `brew install bash coreutils` note, and a copy-pasteable usage demo
  2. MIT LICENSE file committed at repo root; `package.json` declares license/repository/author for marketplace discovery
  3. `examples/` contains 3 dogfooded example reports (one per scenario: saturated, empty, ambiguous) generated by running RepoRecon on real ideas
  4. Plugin installs cleanly from the public GitHub repo via the Claude Code marketplace in a fresh environment, and `/reporecon` triggers without command-name collisions
**Plans (wave-parallel):**
  - **Wave 1 (independent):**
    - Plan 3.1: README.md (install, prereqs, demo gif/asciinema, troubleshooting) + LICENSE (MIT)
    - Plan 3.2: Dogfooded examples — run RepoRecon against 3 real ideas; commit reports to `examples/`
    - Plan 3.3: Marketplace schema re-verification + `/reporecon` trigger collision check + final manifest polish
  - **Wave 2 (validation):**
    - Plan 3.4: Fresh-environment install test + marketplace submission

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Tier 1 MVP | 0/7 | Not started | - |
| 2. Tier 2 Deep Inspection | 0/7 | Not started | - |
| 3. Polish + Marketplace | 0/4 | Not started | - |

## Coverage Validation

**v1 requirements: 51 / 51 mapped ✓**

- Phase 1: 34 requirements (PKG-01, PKG-02, PKG-04; INP-01..05; T1-01..09; JDG-01, JDG-02, JDG-03, JDG-05, JDG-06, JDG-07; HEUR-02, HEUR-03, HEUR-04; RPT-01, RPT-02, RPT-04; SCR-01, SCR-02, SCR-05; TST-01, TST-02)
- Phase 2: 17 requirements (T2-01..10; JDG-04; HEUR-01; RPT-03; SCR-03, SCR-04; TST-03, TST-04)
- Phase 3: 3 requirements (PKG-03, PKG-05, TST-05)

**Total:** 34 + 17 + 3 = 54 mappings across 51 unique REQ-IDs.

*Note: 51 unique IDs — verify no duplicates in mapping.* Recount:
- Phase 1 unique: PKG-01, PKG-02, PKG-04 (3) + INP-01..05 (5) + T1-01..09 (9) + JDG-01, JDG-02, JDG-03, JDG-05, JDG-06, JDG-07 (6) + HEUR-02, HEUR-03, HEUR-04 (3) + RPT-01, RPT-02, RPT-04 (3) + SCR-01, SCR-02, SCR-05 (3) + TST-01, TST-02 (2) = **34**
- Phase 2 unique: T2-01..10 (10) + JDG-04 (1) + HEUR-01 (1) + RPT-03 (1) + SCR-03, SCR-04 (2) + TST-03, TST-04 (2) = **17**
- Phase 3 unique: PKG-03, PKG-05, TST-05 = **3**
- **Total unique: 34 + 17 + 3 = 54**

REQUIREMENTS.md lists 51 IDs. Recount the source: PKG (5) + INP (5) + T1 (9) + T2 (10) + JDG (7) + HEUR (4) + RPT (4) + SCR (5) + TST (5) = **54 v1 IDs**. REQUIREMENTS.md "51 total" is a stale count; the actual ID enumeration totals 54. All 54 are mapped, exactly once.

---
*Last updated: 2026-05-26*
