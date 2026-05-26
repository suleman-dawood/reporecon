# 🟢 RepoRecon Report

> **Generated from fixture data** — this is an illustrative report, not a live RepoRecon run. Real reports require user-side validation (see README).

## Sharpened Idea

Sharpened idea: An automated compliance auditor for NDIS support plans against legislative quality indicators

Preserved terms: ["NDIS"]

Verdict: 🟢 "No close match"

## Run Metadata

- Timestamp: 2025-11-14T20:11:03Z
- gh rate budget (core) before run: 4998 / 5000
- gh rate budget (search) before run: 30 / 30
- gh rate budget (core) after run: 4978 / 5000
- gh rate budget (search) after run: 27 / 30

## Candidates

### govtech-au/policy-audit

[https://github.com/govtech-au/policy-audit](https://github.com/govtech-au/policy-audit) — verified at 2025-11-14T20:11:14Z

**Verdict:** UNRELATED

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 1 |
| target_audience | 1 |
| scope           | 1 |
| approach        | 2 |
| activity        | 2 |

Staleness: none

> Generic policy-document linter; no NDIS-specific rules or quality-indicator framework. README mentions "compliance rule engine" — adjacent approach only.

### opendata-au/ndis-scraper

[https://github.com/opendata-au/ndis-scraper](https://github.com/opendata-au/ndis-scraper) — verified at 2025-11-14T20:11:15Z

**Verdict:** UNRELATED

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 0 |
| target_audience | 2 |
| scope           | 0 |
| approach        | 0 |
| activity        | 1 |

Staleness: stale-12mo

> Scrapes public NDIS pricing data into CSV; same audience (NDIS-adjacent users) but no auditing or support-plan analysis happens here.

### care-tools/support-plan-template

[https://github.com/care-tools/support-plan-template](https://github.com/care-tools/support-plan-template) — verified at 2025-11-14T20:11:16Z

**Verdict:** UNRELATED

| Axis            | Score (0-3) |
| --------------- | ----------- |
| core_function   | 0 |
| target_audience | 2 |
| scope           | 0 |
| approach        | 0 |
| activity        | 1 |

Staleness: solo-stale-6mo

> A markdown template for writing NDIS support plans. No audit logic, no quality-indicator mapping — just a document skeleton.

## Your Angle

The NDIS quality-indicator audit space is genuinely open — no inspected repo combines plan parsing with legislative-rule mapping. Strong wedge.

**Features in your idea absent from all inspected candidates:**

- Mapping of free-text support-plan sections to the specific legislative quality indicators they satisfy
- Versioned ruleset that tracks NDIS Practice Standards revisions over time
- Provider-facing remediation suggestions per failed indicator (not just pass/fail)
- Audit-trail export suitable for NDIS Commission submissions

## What's Next?

> A devil's-advocate re-judge was run on the top-scoring candidate (govtech-au/policy-audit) per the rubric. The 🟢 verdict held.
