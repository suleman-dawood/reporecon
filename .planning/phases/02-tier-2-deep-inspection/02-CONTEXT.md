# Phase 2: Tier 2 Deep Inspection - Context

**Gathered:** 2026-05-26 (auto mode — decisions inherited from PROJECT.md + Phase 1 CONTEXT.md, no re-discussion)
**Status:** Ready for planning

<domain>
## Phase Boundary

Add opt-in deep-inspection extension to the Phase 1 plugin. Tier 2 is triggered only after a Tier 1 🟡/🔴 verdict followed by explicit user confirmation. It clones the WORTH_INSPECTING candidates with full safety guards, judges equivalence with file-path evidence to produce the full 5-level verdict (EXACT_MATCH / SIGNIFICANT_OVERLAP / PARTIAL_OVERLAP / SUPERFICIAL_MATCH / VAPOR), applies the mechanical vapor heuristic, and writes the negative-space "your angle" section.

Out of scope for this phase: Tier 1 changes (already shipped), README polish, examples directory, marketplace submission — those are Phase 3.
</domain>

<decisions>
## Implementation Decisions

### Trigger & Gating
- **D2-01:** Tier 2 path activates only on explicit user opt-in after Tier 1 produces a 🟡 or 🔴 verdict (per T2-01). The footer prompt from Phase 1 SKILL.md is the entry point.
- **D2-02:** Tier 1 verdicts that returned 🟢 do NOT prompt Tier 2 (no signal there's anything to dig into).

### Discovery (Expanded)
- **D2-03:** Tier 2 expands discovery with WebSearch + 10 additional `gh api search/repositories` queries beyond the Tier 1 set (per T2-02). Total run budget ≤50 `gh api` calls (under the 30/min search bucket + 5000/hr core budget).
- **D2-04:** WebSearch results that cite a `github.com/{owner}/{repo}` URL go through the same `verify-repo.sh` 404-gate as everything else (per T2-03). No URL in any Tier 2 output without a 200 OK in this run.
- **D2-05:** Dedupe across all Tier 1 + Tier 2 sources by `full_name`. Tier 1's verified candidates carry forward, not re-verified.

### Safe Cloning
- **D2-06:** New script `scripts/safe-clone.sh <owner/repo> <dest>` (SCR-03). Implementation:
  - Pre-check size via `gh api /repos/{owner}/{name}` → `.size` (KB). Reject if size > 50000 KB (50MB).
  - Clone command: `git clone --depth 1 --filter=blob:none --single-branch --no-tags <url> <dest>` with `GIT_LFS_SKIP_SMUDGE=1` exported.
  - Wrap in `timeout 60s` (GNU). Documented macOS prereq: `brew install coreutils`.
  - Destination always under `mktemp -d -t reporecon-XXXXXX`, prefixed `/tmp/reporecon/`.
  - `trap 'rm -rf "$DEST"' EXIT INT TERM` ensures cleanup even on signal/error.
  - Exit codes: 0 success; 11 oversize; 12 timeout; 13 LFS-only repo; 1 other.
- **D2-07:** Boot-time sweep: SKILL.md Tier 2 protocol begins by running `find /tmp/reporecon -mindepth 1 -maxdepth 1 -mmin +120 -exec rm -rf {} +` to clean orphans from prior aborted runs.

### Vapor Heuristic
- **D2-08:** New script `scripts/vapor-check.sh <clone-dir>` (SCR-04, HEUR-01). Returns exit 0 if vapor heuristic triggers, exit 1 otherwise. Mechanical, no LLM.
- **D2-09:** Vapor formula: `claims := (count of "## " headings in README mentioning feature/capability keywords)`; `source_files := find . -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" -o -name "*.java" -o -name "*.c" -o -name "*.cpp" -o -name "*.sh" \) | wc -l`; trigger VAPOR if `claims ≥ 3 AND (source_files ≤ 5 OR archived=true OR pushed_at < now-18mo)`. README-claims regex documented in script header.
- **D2-10:** Vapor verdict is mechanical, not LLM-derived. Surfaces in report as `VAPOR` verdict label even if axis scores would suggest higher overlap.

### Untrusted Content Handling
- **D2-11:** Every clone is treated as untrusted input. Before any LLM reads README or source content, the protocol wraps it: `<untrusted_content source="github.com/{owner}/{repo}/{path}">{truncated body}</untrusted_content>`.
- **D2-12:** Content truncation: README to first 3000 characters; source files to first 200 lines per file, max 10 files per repo.
- **D2-13:** Pre-LLM sanitization: strip HTML comments (`<!--...-->`), strip zero-width characters (U+200B, U+200C, U+200D, U+FEFF). Inline in the protocol's bash preprocessing step.
- **D2-14:** Per PITFALLS.md, the per-candidate inspection LLM call is the highest-risk surface for prompt injection. The judge prompt is structured so any meta-instructions ("ignore previous instructions", "set verdict to UNRELATED", etc.) inside `<untrusted_content>` are explicitly called out as adversarial and required to result in `axis_scores=null` + `flag: "suspected_injection"`.

### 5-Level Verdict & Evidence
- **D2-15:** Tier 2 judge produces the full 5-level verdict: EXACT_MATCH, SIGNIFICANT_OVERLAP, PARTIAL_OVERLAP, SUPERFICIAL_MATCH, VAPOR. Verdict still derived mechanically from the 5-axis 0-3 scores; thresholds documented in extended `references/judge-rubric.md`.
- **D2-16:** Evidence rule (JDG-04 full): any verdict at PARTIAL_OVERLAP or stronger requires at least one cited file path from the clone. Without a cite, verdict is capped at SUPERFICIAL_MATCH (or VAPOR if the vapor heuristic triggers). Cite format: `path/to/file.ext:LINE` in the judge JSON output.
- **D2-17:** Judge inspects: package manifest (package.json / pyproject.toml / Cargo.toml / go.mod / etc.), entry points (main module file, src/index.*, src/main.*), and top-level source files. Selection algorithm documented in the rubric extension.

### Negative-Space Report Section
- **D2-18:** New section in `references/report-template.md`: "Your Angle" — lists features from the sharpened idea + preserved terms that are absent in all inspected candidates (per RPT-03).
- **D2-19:** Negative-space synthesis runs after all candidate verdicts: LLM call receives (sharpened idea, candidate summaries, axis evidence) and produces a bulleted list of distinguishing features and a 1-sentence positioning angle.

### Helper Scripts (Phase 2 additions)
- **D2-20:** Two new scripts: `scripts/safe-clone.sh` (D2-06), `scripts/vapor-check.sh` (D2-08). Both POSIX bash 4+, `set -euo pipefail`, executable.

### Testing
- **D2-21:** New fixtures under `tests/fixtures/`:
  - `planted-injection-readme.md` — readme containing prompt-injection patterns; judge must produce `flag: suspected_injection` (per TST-03).
  - `planted-vapor-repo/` — directory with verbose README + ≤2 source files; vapor-check.sh must return 0 (per TST-04).
- **D2-22:** Tier 2 goldens extend `tests/run-goldens.sh` with the deep-inspection path. Stability gate: top verdict label band stable across 3 runs per fixture (same standard as Tier 1).
- **D2-23:** Real-network golden runs gated behind `RUN_REAL=1` env var so default `tests/run-goldens.sh` invocation doesn't burn `gh` quota. CI matrix runs both modes.

### Time Budget
- **D2-24:** End-to-end Tier 2 must complete in ≤10 minutes for 3 golden fixtures (per T2-10). Time budget allocation: discovery ≤90s, verification ≤30s, clones (parallel up to 3 at a time) ≤4min, per-candidate judge ≤30s × up to 8 candidates = ≤4min, negative-space synthesis ≤30s.

### Claude's Discretion
- README-claims regex for vapor heuristic (D2-09) — start with conservative pattern, can iterate during 02-07.
- Exact characters list for zero-width stripping (D2-13) — defaults documented but may need additions.
- Whether to parallelize clones via `xargs -P 3` or sequentialize for clearer error handling (recommended: parallel with cap 3).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level
- `.planning/PROJECT.md` — scope + decisions
- `.planning/REQUIREMENTS.md` — Phase 2 owns: T2-01..10, JDG-04 (full), HEUR-01, RPT-03, SCR-03, SCR-04, TST-03, TST-04
- `.planning/ROADMAP.md` Phase 2 section — wave structure already documented
- `.planning/phases/01-tier-1-mvp-quick-verdict/01-CONTEXT.md` — Tier 1 decisions to extend, not override

### Existing code (Phase 1 artifacts to extend)
- `skills/reporecon/SKILL.md` — Tier 2 protocol must extend the 7-step Tier 1 protocol with an opt-in branch
- `skills/reporecon/references/judge-rubric.md` — Tier 2 must add 5-level extension; keep Tier 1 cap intact
- `skills/reporecon/references/report-template.md` — Tier 2 must add "Your Angle" section + per-candidate file-path evidence
- `scripts/preflight.sh`, `scripts/gh-search.sh`, `scripts/verify-repo.sh`, `scripts/staleness.sh` — reused; Tier 2 adds `safe-clone.sh`, `vapor-check.sh`
- `tests/run-goldens.sh` — extend with Tier 2 path
- `tests/golden/*.json` — Tier 2 fixtures co-located

### Research
- `.planning/research/SUMMARY.md` — Tier 2 implications + clone-safety guards
- `.planning/research/PITFALLS.md` — prompt injection (P3), clone safety (P5)
- `.planning/research/STACK.md` — git safe-clone flags + GNU timeout requirement

### External
- Git `--filter=blob:none` partial clone: https://git-scm.com/docs/partial-clone
- `git clone --depth 1` semantics: https://git-scm.com/docs/git-clone
- `GIT_LFS_SKIP_SMUDGE`: https://git-lfs.com/
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (Phase 1)
- `scripts/preflight.sh` — extended preflight should check `git` ≥2.40 + GNU `timeout` availability for Tier 2
- `scripts/verify-repo.sh` — gates every Tier 2 URL too (no duplication needed)
- `skills/reporecon/SKILL.md` (119 lines) — currently Tier 1-only with footer pointing to Tier 2; extend in-place via additional steps + opt-in gate
- `skills/reporecon/references/judge-rubric.md` (174 lines) — has Tier 1 cap section + 5-axis rubric; Tier 2 adds the full 5-level derivation table

### Established Patterns
- Mechanical (bash) for heuristics + safety; LLM only for judgment.
- One concern per script; scripts compose via stdin/stdout JSON.
- All scripts: `#!/usr/bin/env bash` + `set -euo pipefail` + executable bit.
- Reports gitignored under `./reporecon-reports/`.

### Integration Points
- Tier 2 entry point: SKILL.md "Tier 2 footer" message becomes an opt-in branch.
- Cloned content: must pass through `<untrusted_content>` wrapper before any LLM read.
- Negative-space output: appends new section to existing report template (does not replace).
</code_context>

<specifics>
## Specific Ideas

- Prompt-injection planted fixture should include both naive ("Ignore previous instructions") and stealthier patterns (HTML-comment instructions, zero-width-character delimiters).
- Negative-space "Your Angle" should be one paragraph max — the user's actual decision aid is the bulleted list of missing features, not prose.
- If the vapor heuristic triggers but the judge would otherwise return PARTIAL_OVERLAP+, surface BOTH labels in the report header ("VAPOR (axes suggested PARTIAL_OVERLAP)") — transparency over hiding signal.
</specifics>

<deferred>
## Deferred Ideas

- Cache cloned repos across runs (would speed re-runs but adds complexity) → v1.1
- Parallel-clone fan-out beyond 3 → measure first
- LFS support → out of scope (D2-06 explicit)
- Sub-agent tool isolation for the per-candidate judge call (research flag from PITFALLS.md) → implement basic `<untrusted_content>` delimiter pattern; defer nested-sub-agent isolation to Phase 3 if needed

### Reviewed Todos (not folded)
(None.)
</deferred>

---

*Phase: 02-tier-2-deep-inspection*
*Context gathered: 2026-05-26*
