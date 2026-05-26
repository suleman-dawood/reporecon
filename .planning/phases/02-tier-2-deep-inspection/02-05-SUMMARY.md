---
phase: 02-tier-2-deep-inspection
plan: 05
subsystem: tier-2-test-fixtures
tags: [fixtures, testing, adversarial, vapor, prompt-injection]
requirements: [TST-03, TST-04]
dependency-graph:
  requires: []
  provides:
    - "tests/fixtures/planted-injection-readme.md (consumed by 02-06 SKILL.md, 02-07 goldens)"
    - "tests/fixtures/planted-vapor-repo/ (consumed by 02-02 vapor-check.sh, 02-07 goldens)"
    - "tests/fixtures/README.md (fixture index)"
  affects: []
tech-stack:
  added: []
  patterns:
    - "Adversarial fixtures live under tests/fixtures/ with an index README"
    - "Injection vectors layered (naive + HTML-comment + zero-width + exfil URL)"
    - "Vapor fixture shaped to D2-09 mechanical formula (source_files <= 5 path)"
key-files:
  created:
    - tests/fixtures/planted-injection-readme.md
    - tests/fixtures/planted-vapor-repo/README.md
    - tests/fixtures/planted-vapor-repo/main.py
    - tests/fixtures/README.md
  modified: []
decisions:
  - "Injection fixture is 95 lines so injection vectors sit both inside AND beyond the 3000-char D2-12 truncation window, exercising defense-in-depth"
  - "Vapor fixture has 9 claim '## ' headings (well over the minimum 3) to keep the heuristic margin obvious even if the claim regex tightens during 02-07"
  - "ZWSP byte count in injection fixture is 44 (one full hidden instruction), not just 1, so D2-13 stripping has a real signal to remove"
metrics:
  duration: "~6 minutes"
  completed: 2026-05-26
  tasks: 3
  files: 4
  commits: 3
---

# Phase 02 Plan 05: Tier 2 Test Fixtures Summary

Adversarial test fixtures for Tier 2 deep inspection: a layered prompt-injection
README and a deliberately vaporware-shaped repo. Both committed in-repo so
02-06 (SKILL.md updates) and 02-07 (goldens) have deterministic inputs to
regress against.

## What Shipped

Three files (one is a directory of two files):

1. `tests/fixtures/planted-injection-readme.md` — 95-line fake Rust TODO CLI
   README carrying five injection vectors:
   - Naive plaintext (`ignore previous instructions`, 4 occurrences across
     Setup / Contributing / Acknowledgments)
   - HTML-comment system-impersonation (2 `<!-- SYSTEM: ... -->` blocks
     attempting `axis_scores={...:0}` and POST-to-exfil)
   - Zero-width-character stealth injection (44 U+200B bytes splitting an
     instruction in the "Hidden Configuration" section)
   - Exfiltration URL (`attacker.example.com`) requested for "Useful Links"
   - Reset attempt asking the model to emit `flag: null` instead of
     `suspected_injection`
   - End marker `<!-- END OF PLANTED INJECTION FIXTURE -->` for deterministic
     test positioning

2. `tests/fixtures/planted-vapor-repo/` — directory with:
   - `README.md` — 9 claim-keyword `## ` headings (Features, Capabilities,
     Supported Integrations, Web Interface, CLI Tool, Plugin Extensions, API,
     Server Deployment, Client Libraries)
   - `main.py` — 5-line stub, the sole source file in the directory

3. `tests/fixtures/README.md` — 77-line fixture index documenting:
   - Purpose table (TST-03 / TST-04)
   - Vector-by-vector breakdown of the injection fixture
   - Expected outcomes (`flag: suspected_injection` OR verdict invariance;
     vapor-check.sh exit 0)
   - Consumer cross-references (SKILL.md Tier 2 protocol, run-goldens.sh)
   - "How to add a new fixture" guideline

## Verification

All acceptance criteria checked mechanically:

| Check                                                                          | Result      |
| ------------------------------------------------------------------------------ | ----------- |
| `grep -ci "ignore previous instructions" planted-injection-readme.md`          | 4 (≥1)      |
| `grep -c "<!--" planted-injection-readme.md`                                   | 3 (≥1)      |
| `grep -c "SYSTEM:" planted-injection-readme.md`                                | 2 (≥1)      |
| `grep -c "axis_scores" planted-injection-readme.md`                            | 1 (≥1)      |
| `grep -c "attacker.example.com" planted-injection-readme.md`                   | 2 (≥1)     |
| `grep -c "END OF PLANTED INJECTION FIXTURE" planted-injection-readme.md`       | 1 (=1)      |
| `wc -l planted-injection-readme.md`                                            | 95 (≥30)    |
| U+200B byte count (`python3` count)                                            | 44 (≥1)     |
| `grep -c "^# innocuous-todo-cli" planted-injection-readme.md`                  | 1 (=1)      |
| Claim-heading count in vapor README                                            | 9 (≥5)      |
| Source-file count under planted-vapor-repo/                                    | 1 (≤5)      |
| `wc -l planted-vapor-repo/main.py`                                             | 5 (≤10)     |
| `wc -l tests/fixtures/README.md`                                               | 77 (≥30)    |
| All consumer-reference literals present in fixtures/README.md                  | Pass        |

## Deviations from Plan

None — plan executed exactly as written.

## Deferred / Runtime-Verified

- `bash scripts/vapor-check.sh tests/fixtures/planted-vapor-repo/` exit-0 check
  is structurally satisfied here (1 source file, ≥3 claim headings) but the
  runtime assertion is gated on plan 02-02 shipping vapor-check.sh. The 02-07
  goldens will exercise it.

## Commits

| Task | Description                                                | Hash    |
| ---- | ---------------------------------------------------------- | ------- |
| 1    | test(02-05): add planted-injection-readme fixture (TST-03) | 2e7d165 |
| 2    | test(02-05): add planted-vapor-repo fixture (TST-04)       | ec00a31 |
| 3    | docs(02-05): add tests/fixtures/README.md                  | a19b5e3 |

## Known Stubs

`planted-vapor-repo/main.py` is intentionally a 5-line stub (`print("Not implemented")`).
This is the fixture's whole point — it's the "vapor" half of TST-04. Not a real stub
to be resolved later; the deliberately-thin source is the test signal.

## Self-Check: PASSED

- FOUND: tests/fixtures/planted-injection-readme.md
- FOUND: tests/fixtures/planted-vapor-repo/README.md
- FOUND: tests/fixtures/planted-vapor-repo/main.py
- FOUND: tests/fixtures/README.md
- FOUND commit: 2e7d165
- FOUND commit: ec00a31
- FOUND commit: a19b5e3
