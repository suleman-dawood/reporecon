# Changelog

All notable changes to RepoRecon will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## v0.4.1 — 2026-05-27 — Bug fixes

- `verify-repo.sh` now propagates exit code 78 from `gh_with_backoff` correctly. Previously, secondary-rate-limit exhaustion exited with 1, indistinguishable from 404/other errors. Callers (and the SKILL.md retry-aware logic) can now branch on 78 specifically.
- `preflight.sh` now exits 2 with a clear error on malformed `gh api rate_limit` responses, instead of bubbling up `jq`'s exit code via `set -e`.
- Unit tests tightened: assertions for these cases now require the exact documented exit codes rather than "non-zero".

## v0.4.0 — 2026-05-27 — Performance + UX

**Performance**
- Per-candidate deep-search judge calls now fan out via subagents (~4 min → ~1.5 min); one subagent per candidate, dispatched in a single turn, mechanical verdict derivation stays in the orchestrator.
- First-search WebSearch + gh-search query batches now run in parallel (xargs -P 4 for gh-search; 5 WebSearch calls in one turn).
- Result cache keyed on sharpened-sentence sha1 with 1hr TTL — re-runs of the same idea skip redundant network work. `scripts/cache.sh` verbs: `key`, `get`, `put`, `invalidate`, `prune`.

**UX**
- Progress ticks via stderr (`scripts/status.sh`) so the user sees what step the protocol is on — verbs `start`, `tick`, `done`, `error`, stdout stays clean for JSON pipelines.
- Report template rewritten for narrative-first output: every candidate gets a "What it does" + "Overlap with your idea" prose block; metadata moved to collapsible footer. New placeholders: `{{VERDICT_HEADLINE}}`, `{{NARRATIVE_LEAD}}`, `{{CAND_DESCRIPTION_NARRATIVE}}`, `{{CAND_OVERLAP_NARRATIVE}}`, `{{CAND_FILE_PATHS_PROSE}}`, `{{CAND_EVIDENCE_NARRATIVE}}`, `{{PROVENANCE_SUMMARY}}`, `{{CAND_STALENESS_SUFFIX}}`.
- New `--no-cache` / `--fresh` user override for skipping the cache on a single invocation.

**Resilience**
- `gh api` calls now retry once with exponential backoff (5s → 10s) on secondary rate-limit hits, exiting cleanly with code 78 after exhaustion. `gh-search.sh` and `verify-repo.sh` both wrap the new `gh_with_backoff` helper.

## [0.3.1] — 2026-05-27 — Terminology Purge

Internal-vocabulary cleanup. v0.3.0 renamed user-facing headings but left
internal references (provenance tags, step IDs, invariant rule names,
filenames) using "Tier 1 / Tier 2" wording. v0.3.1 finishes the sweep so the
plugin speaks one vocabulary end-to-end: **first search** and **deep search**.

### Changed
- Provenance tags renamed: `tier1-gh` → `first-gh`, `tier1-web` → `first-web`,
  `tier1-web-saas` → `first-web-saas`, `tier2-gh` → `deep-gh`,
  `tier2-web` → `deep-web`, `tier2-web-saas` → `deep-web-saas`.
- Step IDs renamed: `T2-A` … `T2-G` → `DEEP-A` … `DEEP-G`.
- Reference file renamed: `tier2-protocol.md` → `deep-search-protocol.md`.
- Golden fixtures renamed: `tier2-vapor.json` → `deep-vapor.json`,
  `tier2-injection.json` → `deep-injection.json`.
- Template placeholders renamed: `{{TIER2_*}}` → `{{DEEP_*}}`,
  `{{CAND_TIER1_LABEL}}` → `{{CAND_FIRST_LABEL}}`.
- Invariant rule names: "Tier 1 cap" → "first-search cap", "Tier 2 cap" →
  "deep-search cap".
- All prose, comments, and headings across `skills/`, `scripts/`, `tests/`,
  `examples/`, and `SUBMISSION.md` rephrased to use first-search / deep-search.

### Preserved
- User-input opt-in aliases `tier 2`, `tier2`, `--tier2` retained in
  SKILL.md Step 8.5 trigger list as back-compat shims through v1.0 — typing
  the old word still works. New documentation guides users to `deep search`.

### Notes
- Bumped to v0.3.1. No behavioural changes; pure refactor.

## [0.2.0] — 2026-05-26 — Discovery Blind Spots

User testing on v0.1.0 surfaced systematic blind spots in the GitHub-only discovery path: closed-source SaaS, YC startups, GitHub Apps / Marketplace entries, awesome-list incumbents, and well-known products with brittle keyword recall.

### Added
- **First-search Web Cross-Check (mandatory)** — Step 3.5 invokes 5 WebSearch queries per run across canonical products, YC + funded startups, awesome-lists, GitHub Marketplace / Apps, HN / Product Hunt. Results feed a parallel candidate pool. WebSearch is no longer deep-search-only.
- **Two new query archetypes** — `CANONICAL-NAMES` (model enumerates known incumbents at runtime; cutoff-bound) and `TOPIC-TAG` (queries the GitHub topic index directly, bypassing keyword ranking). Total archetypes 5 → 7.
- **Non-GitHub Competitor Rule** in `judge-rubric.md` — non-GitHub candidates scored on the same 5-axis rubric with verdict capped at `WORTH_INSPECTING` (first search) or `SUPERFICIAL_MATCH` (deep search) per JDG-04. New aggregation: any SaaS candidate with `axis_sum ≥ 10` drives the overall verdict to 🔴 with a `(saturated lane — closed-source SaaS exists)` annotation.
- **Closed-Source / SaaS Competitors block** in `report-template.md` — separate report section for `first-web-saas` candidates with category, evidence snippet, source query, axis scores, axis-badge (⚠️/🔶).
- **`web-cross-check.md` reference** — formal protocol doc for the new WebSearch step.

### Changed
- `gh-search.sh` `per_page` default 10 → 30 (recall over precision; downstream dedup absorbs noise).
- `gh-search.sh` auto-detects `topic:` queries and routes them to the topic index.
- `gh-search.sh` accepts `--in {name,description,readme}` and `--per-page <n>` flags (backward-compatible).
- SKILL.md first search generates **7 queries** (was 5) and runs Step 3.5 web cross-check before dedup.
- Overall verdict aggregation now considers both gh-pool and SaaS-pool candidates.

### Fixed
- v0.1.0 produced 🟢 / 🟡 verdicts on idea spaces with strong closed-source competitors (e.g. inbox triage vs. PanzaMail / Shortwave / Ellie; PR babysitter vs. Ellipsis YC W24, CodeRabbit Autofix, Sweep, Greptile, Cursor Background Agent). v0.2.0 catches these via Step 3.5.
- v0.1.0's GitHub keyword recall was brittle — popular incumbents like `elie222/inbox-zero` could miss top-10 results because of token-overlap ranking. `per_page=30` + canonical-names archetype + topic-tag archetype together close most of the gap.

### Notes
- Cutoff-bound: `CANONICAL-NAMES` archetype only catches incumbents the model already knows by name. Post-cutoff products surface via the `first-web` candidates of Step 3.5.
- WebSearch quota: Step 3.5 caps at exactly 5 WebSearch calls per first-search run.

## [0.1.0] — 2026-05-26 — Initial release

- First search (`gh api` metadata only, ≤90s) — 5-query discovery + 404 verification + mechanical 5-axis rubric + 🟢/🟡/🔴 verdict.
- Deep search (opt-in, ≤10min) — WebSearch expansion + safe shallow clones + file-path evidence + 5-level verdict (EXACT/SIGNIFICANT/PARTIAL/SUPERFICIAL/VAPOR) + Your Angle synthesis + vapor heuristic.
- Plugin packaging for Claude Code marketplace.
- 3 golden fixtures + planted-injection + planted-vapor fixtures.

[0.4.0]: https://github.com/suleman-dawood/reporecon/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/suleman-dawood/reporecon/compare/v0.3.0...v0.3.1
[0.2.0]: https://github.com/suleman-dawood/reporecon/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/suleman-dawood/reporecon/releases/tag/v0.1.0
