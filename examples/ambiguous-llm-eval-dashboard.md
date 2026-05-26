# 🟡 RepoRecon Report

> **Generated from fixture data** — this is an illustrative report, not a live RepoRecon run. Real reports require user-side validation (see README).

## Sharpened Idea

Sharpened idea: A web dashboard for side-by-side LLM evaluation across providers (OpenAI, Anthropic, Google)

Preserved terms: ["LLM", "OpenAI", "Anthropic", "Google"]

Verdict: 🟡 "Some overlap"

## Run Metadata

- Timestamp: 2025-11-14T20:33:48Z
- gh rate budget (core) before run: 4998 / 5000
- gh rate budget (search) before run: 30 / 30
- gh rate budget (core) after run: 4951 / 5000
- gh rate budget (search) after run: 25 / 30

## Candidates

### evalkit/promptfoo-similar

[https://github.com/evalkit/promptfoo-similar](https://github.com/evalkit/promptfoo-similar) — verified at 2025-11-14T20:33:59Z

**Verdict:** WORTH_INSPECTING

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 3 |
| target_audience | 2 |
| scope           | 2 |
| approach        | 2 |
| activity        | 3 |

Staleness: none

> README: "compare LLM outputs across OpenAI, Anthropic, and local models in a web UI" — overlaps strongly on core_function and approach.

### labs-oss/llm-eval-cli

[https://github.com/labs-oss/llm-eval-cli](https://github.com/labs-oss/llm-eval-cli) — verified at 2025-11-14T20:34:00Z

**Verdict:** WORTH_INSPECTING

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 2 |
| target_audience | 2 |
| scope           | 1 |
| approach        | 1 |
| activity        | 2 |

Staleness: none

> CLI eval harness for LLM prompts across OpenAI and Anthropic; lacks the dashboard / side-by-side UX entirely.

### research/prompt-bench-framework

[https://github.com/research/prompt-bench-framework](https://github.com/research/prompt-bench-framework) — verified at 2025-11-14T20:34:01Z

**Verdict:** WORTH_INSPECTING

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 2 |
| target_audience | 2 |
| scope           | 2 |
| approach        | 1 |
| activity        | 1 |

Staleness: stale-12mo

> Library for running LLM benchmark suites; outputs JSON reports but no interactive web dashboard.

### vibes/llm-eval-ultra

[https://github.com/vibes/llm-eval-ultra](https://github.com/vibes/llm-eval-ultra) — verified at 2025-11-14T20:34:02Z

**Verdict:** WORTH_INSPECTING

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 2 |
| target_audience | 2 |
| scope           | 2 |
| approach        | 2 |
| activity        | 1 |

Staleness: none

> README claims "the ultimate side-by-side dashboard for OpenAI, Anthropic, Google, and 12 other providers" — promising on paper, repo otherwise sparse.

## Tier 2 Inspection

### evalkit/promptfoo-similar

[https://github.com/evalkit/promptfoo-similar](https://github.com/evalkit/promptfoo-similar) — verified at 2025-11-14T20:39:21Z — provenance: tier1

**Verdict:** PARTIAL_OVERLAP

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 3 |
| target_audience | 2 |
| scope           | 2 |
| approach        | 2 |
| activity        | 3 |

Staleness: none

**Evidence (file paths):**
- package.json:14
- src/providers/openai.ts:8
- src/providers/anthropic.ts:8
- web/app/dashboard/page.tsx:55

> Multi-provider eval with a dashboard, but the comparison view is per-prompt scoring; no true side-by-side diff of completions.

### labs-oss/llm-eval-cli

[https://github.com/labs-oss/llm-eval-cli](https://github.com/labs-oss/llm-eval-cli) — verified at 2025-11-14T20:39:33Z — provenance: tier1

**Verdict:** SUPERFICIAL_MATCH

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 2 |
| target_audience | 2 |
| scope           | 1 |
| approach        | 1 |
| activity        | 2 |

Staleness: none

**Evidence (file paths):**
- pyproject.toml:3
- src/llm_eval_cli/main.py:24

> Same broad problem area, different interface — CLI-only. No web component anywhere in the source tree.

### research/prompt-bench-framework

[https://github.com/research/prompt-bench-framework](https://github.com/research/prompt-bench-framework) — verified at 2025-11-14T20:39:44Z — provenance: tier1

**Verdict:** SUPERFICIAL_MATCH

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 2 |
| target_audience | 2 |
| scope           | 2 |
| approach        | 1 |
| activity        | 1 |

Staleness: stale-12mo

**Evidence (file paths):**
- pyproject.toml:5
- src/prompt_bench/runner.py:67

> Benchmark harness for academic LLM comparison studies; emits static reports, not an interactive dashboard.

### vibes/llm-eval-ultra

[https://github.com/vibes/llm-eval-ultra](https://github.com/vibes/llm-eval-ultra) — verified at 2025-11-14T20:39:55Z — provenance: tier2-gh

**Verdict:** VAPOR (axes suggested PARTIAL_OVERLAP)

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 2 |
| target_audience | 2 |
| scope           | 2 |
| approach        | 2 |
| activity        | 1 |

Staleness: none

**Evidence (file paths):**
- README.md:1
- main.py:1

> Repo contains only `README.md` and a 12-line `main.py` stub printing "Hello dashboard" — `vapor-check.sh` flagged it. README claims do not match code.

## Your Angle

Every inspected competitor either lacks a dashboard or treats comparison as per-prompt scoring; a true side-by-side diff of completions across OpenAI, Anthropic, and Google in one pane is unoccupied territory.

**Features in your idea absent from all inspected candidates:**

- Synchronized scrolling side-by-side completion view across 3+ providers
- Inline token-cost overlay per provider per prompt
- Save-and-share permalink for a comparison run (no auth required to view)
- Diff highlighting between completions at the token / sentence level

## Tier 2 Inspection Stats

- Clones attempted: 4
- Clones succeeded: 4
- Clones skipped: 0 (oversize/timeout/LFS/injection)
- gh rate budget (core) Tier 2 delta: -22
- gh rate budget (search) Tier 2 delta: -1

## What's Next?

> Tier 2 inspection complete. 4 candidates cloned; 0 skipped (oversize/timeout/LFS/injection). See **Your Angle** section above for differentiation guidance.
