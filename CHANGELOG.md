# Changelog

All notable changes to RepoRecon will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [0.2.0] — 2026-05-26 — Discovery Blind Spots

User testing on v0.1.0 surfaced systematic blind spots in the GitHub-only discovery path: closed-source SaaS, YC startups, GitHub Apps / Marketplace entries, awesome-list incumbents, and well-known products with brittle keyword recall.

### Added
- **Tier 1 Web Cross-Check (mandatory)** — Step 3.5 invokes 5 WebSearch queries per run across canonical products, YC + funded startups, awesome-lists, GitHub Marketplace / Apps, HN / Product Hunt. Results feed a parallel candidate pool. WebSearch is no longer Tier 2-only.
- **Two new query archetypes** — `CANONICAL-NAMES` (model enumerates known incumbents at runtime; cutoff-bound) and `TOPIC-TAG` (queries the GitHub topic index directly, bypassing keyword ranking). Total archetypes 5 → 7.
- **Non-GitHub Competitor Rule** in `judge-rubric.md` — non-GitHub candidates scored on the same 5-axis rubric with verdict capped at `WORTH_INSPECTING` (Tier 1) or `SUPERFICIAL_MATCH` (Tier 2) per JDG-04. New aggregation: any SaaS candidate with `axis_sum ≥ 10` drives the overall verdict to 🔴 with a `(saturated lane — closed-source SaaS exists)` annotation.
- **Closed-Source / SaaS Competitors block** in `report-template.md` — separate report section for `tier1-web-saas` candidates with category, evidence snippet, source query, axis scores, axis-badge (⚠️/🔶).
- **`web-cross-check.md` reference** — formal protocol doc for the new WebSearch step.

### Changed
- `gh-search.sh` `per_page` default 10 → 30 (recall over precision; downstream dedup absorbs noise).
- `gh-search.sh` auto-detects `topic:` queries and routes them to the topic index.
- `gh-search.sh` accepts `--in {name,description,readme}` and `--per-page <n>` flags (backward-compatible).
- SKILL.md Tier 1 generates **7 queries** (was 5) and runs Step 3.5 web cross-check before dedup.
- Overall verdict aggregation now considers both gh-pool and SaaS-pool candidates.

### Fixed
- v0.1.0 produced 🟢 / 🟡 verdicts on idea spaces with strong closed-source competitors (e.g. inbox triage vs. PanzaMail / Shortwave / Ellie; PR babysitter vs. Ellipsis YC W24, CodeRabbit Autofix, Sweep, Greptile, Cursor Background Agent). v0.2.0 catches these via Step 3.5.
- v0.1.0's GitHub keyword recall was brittle — popular incumbents like `elie222/inbox-zero` could miss top-10 results because of token-overlap ranking. `per_page=30` + canonical-names archetype + topic-tag archetype together close most of the gap.

### Notes
- Cutoff-bound: `CANONICAL-NAMES` archetype only catches incumbents the model already knows by name. Post-cutoff products surface via the `tier1-web` candidates of Step 3.5.
- WebSearch quota: Step 3.5 caps at exactly 5 WebSearch calls per Tier 1 run.

## [0.1.0] — 2026-05-26 — Initial release

- Tier 1 (`gh api` metadata only, ≤90s) — 5-query discovery + 404 verification + mechanical 5-axis rubric + 🟢/🟡/🔴 verdict.
- Tier 2 (opt-in, ≤10min) — WebSearch expansion + safe shallow clones + file-path evidence + 5-level verdict (EXACT/SIGNIFICANT/PARTIAL/SUPERFICIAL/VAPOR) + Your Angle synthesis + vapor heuristic.
- Plugin packaging for Claude Code marketplace.
- 3 golden fixtures + planted-injection + planted-vapor fixtures.

[0.2.0]: https://github.com/suleman-dawood/reporecon/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/suleman-dawood/reporecon/releases/tag/v0.1.0
