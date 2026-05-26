# RepoRecon — Recon before you build

> Stop building things that already exist. RepoRecon validates project ideas against GitHub in ~90 seconds, with cited evidence.

```
🟢  No close match — your idea looks novel.
🟡  Adjacent prior art exists — worth a closer look.
🔴  Strong overlap — someone has likely shipped this already.
```

## What's new in v0.2.0

- **WebSearch in Tier 1.** Closed-source SaaS, YC startups, GitHub Apps, and awesome-list incumbents are now caught in the baseline run — not just the opt-in deep dive.
- **7 query archetypes (was 5).** Added `CANONICAL-NAMES` (model-recalled incumbents) and `TOPIC-TAG` (GitHub topic-index lookup).
- **Closed-Source / SaaS Competitors report block.** Surfaces non-GitHub competitors with evidence snippets and axis scores.
- **Saturated-lane verdict.** A strong SaaS competitor (`axis_sum ≥ 10`) now drives 🔴 even when GitHub returns nothing.

See [CHANGELOG.md](./CHANGELOG.md) for the full diff.

## Why

Every developer has shipped a side project only to discover a more mature, better-named, more-starred version already lives on GitHub. The cost is real: weeks of work, a stalled launch, and the slow realization that the differentiator you imagined doesn't actually differentiate.

The usual tools fail in predictable ways. GitHub's own search ranks by stars and recency, not by *idea equivalence* — a one-line query rarely surfaces the canonical prior art. LLMs cheerfully hallucinate repository names that don't resolve. READMEs lie: archived repos describe themselves in the present tense, vapor projects ship 200-line READMEs over 50 lines of code, and "production-ready" usually means "the author's personal demo."

RepoRecon is the structured pre-build check you'd do if you had the patience. It runs five diverse `gh api` queries from different framings, verifies every candidate is actually reachable (404 = dropped), and asks an LLM to judge each one on a fixed 5-axis rubric against metadata only — fast, cheap, no cloning. If the fast verdict is uncertain, an opt-in deep mode clones the top candidates, sanitizes the content, and produces a file-path-cited equivalence report.

## How it works

RepoRecon runs in two tiers. The first is always-on and fast. The second is opt-in and slower but pays for itself when the first tier is uncertain.

### Tier 1 — Fast verdict (~90 seconds)

1. **Sharpen** the user's one-sentence idea into a preserved-term vector (proper nouns kept verbatim).
2. **Generate 5 diverse queries** — one per archetype (literal, synonym-shifted, outcome-framed, tech-stack-framed, adjacent-domain) — in a single deterministic LLM call.
3. **Discover** via `gh api` search; dedupe + rank by rank-sum across the five result sets.
4. **Verify** the top 5 candidates with parallel `verify-repo.sh` calls. Any 404 drops the candidate entirely — no URL ever appears in the report without a fresh 200 OK in this run.
5. **Judge** each verified candidate with a metadata-only LLM call (description + topics + first 3000 chars of README) against a 5-axis rubric. Verdict labels are derived *mechanically* from axis thresholds — the LLM never picks the label.
6. **Emit** a Markdown report under `./reporecon-reports/YYYY-MM-DD-<slug>.md` plus a ≤10-line verdict block to chat: 🟢 (no close match), 🟡 (worth inspecting), or 🔴 (likely match).

If the Tier 1 verdict is 🟢, you're done.

### Tier 2 — Deep dive (~10 minutes, opt-in)

Triggered only when Tier 1 returns 🟡 or 🔴 and the user explicitly opts in (`tier 2`, `yes`, `deep dive`, etc.).

1. **Expand discovery** — 10 more `gh api` queries from a richer archetype set (topic-tag, license-filter, size-bound, fork-excluded, recent-activity, …) plus 5 `WebSearch` queries biased toward `site:github.com`.
2. **Verify** every newly discovered candidate (HARD RULE: no URL without a 200 OK).
3. **Safe shallow clone** the top ≤8 candidates into `/tmp/reporecon/run-*` with size/time/LFS guards and a run-scoped cleanup trap.
4. **Vapor-check** each clone mechanically — a README-to-source-code ratio heuristic that flags projects which exist mostly as prose.
5. **Sanitize and judge** — each cloned file is stripped of HTML comments, zero-width chars, and unicode tag blocks, then wrapped in `<untrusted_content>` before any LLM reads it. The judge call cites evidence by `path/to/file.ext:LINE`. Without ≥1 citation, the verdict is capped at `SUPERFICIAL_MATCH`.
6. **Emit a 5-level verdict** per candidate: `EXACT_MATCH`, `SIGNIFICANT_OVERLAP`, `PARTIAL_OVERLAP`, `SUPERFICIAL_MATCH`, or `VAPOR`.
7. **Your Angle** — a final synthesis call lists 3–7 missing-feature bullets describing the negative space: what every existing candidate fails to do that your idea would.

The Tier 1 and Tier 2 sections are appended into a single combined report — one artifact per run.

## Install

Via the Claude Code marketplace (recommended):

```
/plugin marketplace add suleman-dawood/reporecon
/plugin install reporecon@reporecon
```

Manual local install (for development or off-marketplace use):

```
git clone https://github.com/suleman-dawood/reporecon ~/.claude/plugins/reporecon
```

Then restart Claude Code so the plugin is registered.

## Prerequisites

- **`gh auth login`** — a logged-in GitHub CLI session is mandatory. Anonymous `gh` requests have a 60/hr core rate budget and will be exhausted by a single Tier 2 run. Authenticated sessions get 5000/hr.
- **`gh` ≥ 2.55** — older versions miss `--jq` flags this skill relies on.
- **`jq` ≥ 1.7** — used for streaming JSON manipulation in the shell scripts.
- **macOS users:** `brew install bash coreutils` — RepoRecon's scripts call GNU `timeout` and assume `bash ≥ 4`.

Verify your environment:

```
gh auth status && gh --version && jq --version && bash --version
```

## Quick start

Inside Claude Code:

```
/reporecon I want to build a CLI that previews diff output as a side-by-side TUI
```

Or trigger the skill ambiently — any of these phrasings work:

- "does this already exist on github"
- "is there a tool that does X"
- "validate my idea before I start building"

Tier 1 runs automatically. If the verdict is 🟡 or 🔴, RepoRecon prints an opt-in footer; reply with `tier 2` (or `yes`, `deep dive`, `go`) to escalate.

## Example report output

The verdict block that lands in your chat after Tier 1:

```
🟡  WORTH INSPECTING — adjacent prior art exists

Sharpened: "side-by-side TUI diff previewer with syntax highlighting"
Preserved: ["TUI", "diff", "syntax-highlighting"]

Top candidate:  dandavison/delta  →  WORTH_INSPECTING
Report:         ./reporecon-reports/2026-05-26-tui-diff-previewer.md
Rate budget:    Δ core=-9   Δ search=-5

▸ Reply "tier 2" for a deep dive (clones top candidates, ~10 min).
```

The on-disk Markdown report carries the full per-axis breakdown, rationale per candidate, staleness/archived badges, and (after Tier 2) file-path citations. See [`examples/`](./examples/) for complete sample reports.

## Limitations

RepoRecon is honest about what it can and can't do:

- **WebSearch quality is variable.** Tier 2's web expansion depends on whatever the underlying search backend returns on a given day. Results can drift.
- **The ≤90s / ≤10min budgets are best-effort, not guarantees.** GitHub rate-limit pressure, slow clones, or large READMEs can push a run over.
- **`gh auth login` is your responsibility.** RepoRecon never touches your token, prints your token, or runs `gh auth` for you. An unauthenticated environment will fail preflight.
- **LLM judgment can flip on borderline cases.** The 5-axis rubric, mechanical verdict derivation, and devil's-advocate re-judge mitigate this but don't eliminate it. Treat 🟡 verdicts as "look closer," not "definitely overlaps."
- **GitHub-only scope.** GitLab, Bitbucket, Codeberg, SourceHut, and self-hosted forges are out of scope. RepoRecon's discovery and verification surface is `gh api` + `github.com` WebSearch hits only.
- **Vapor-check is a heuristic.** A high README-to-code ratio is a signal, not proof. Some legitimate documentation-first projects will trip it; treat the `VAPOR` label as an invitation to read the repo yourself.

## Contributing

Bug reports and structured proposals are welcome via GitHub issues. For non-trivial changes, please open an issue first with a short plan in the style of the in-repo `.planning/phases/*/PLAN.md` files — it keeps the scope explicit and the review cheap. Pull requests should keep the existing skill structure (`skills/reporecon/`), the bash-script entry-point pattern (`scripts/*.sh`), and the determinism discipline (temperature 0, mechanical verdict derivation, no URL without 200 OK).

## License

MIT — see [LICENSE](./LICENSE).
