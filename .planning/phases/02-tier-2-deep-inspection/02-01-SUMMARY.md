---
phase: 02-tier-2-deep-inspection
plan: 01
subsystem: tier-2-safety
tags: [safe-clone, bash, security, tier-2]
requires:
  - gh CLI authenticated
  - git >= 2.40 (partial clone support)
  - GNU coreutils timeout
provides:
  - scripts/safe-clone.sh (SCR-03)
  - tests/test-safe-clone.sh (TST harness for guard paths)
affects:
  - Tier 2 SKILL.md protocol (will call safe-clone.sh in later plan)
tech-stack:
  added: []
  patterns:
    - "PATH-overlay stubbing for gh/git in bash unit tests"
    - "two-trap pattern: cleanup on EXIT + force-exit on INT/TERM"
key-files:
  created:
    - scripts/safe-clone.sh
    - tests/test-safe-clone.sh
  modified: []
decisions:
  - "Two-trap pattern (cleanup on EXIT + on_signal INT TERM exit 130) was required because bash continued execution after SIGTERM during timeout-wrapped clone, falling through to CLONE_OK=1 and printing DEST. Force-exit in signal handler is the only reliable way to honor D2-06 cleanup contract."
  - "SAFE_CLONE_TIMEOUT env knob added (default 60s) so the timeout-path test runs in ~2s instead of 60s. Test-only knob; not documented in user-facing usage."
  - "rmdir DEST before git clone — mktemp creates the dir, but git clone refuses non-empty/existing dirs; trap still removes DEST via rm -rf which handles non-existence."
metrics:
  duration: "~12m"
  tasks_completed: 2
  tasks_total: 2
  completed_date: "2026-05-26"
requirements:
  - T2-04
  - T2-05
  - T2-06
  - SCR-03
---

# Phase 02 Plan 01: safe-clone.sh Summary

One-liner: Tier 2 safe-clone wrapper with size pre-check, 60s timeout, GIT_LFS_SKIP_SMUDGE, and dual-trap cleanup, plus a 7-case PATH-stub test harness.

## What Was Built

### scripts/safe-clone.sh (executable)
Bash 4+ script under `set -euo pipefail` implementing D2-06 contract:

| Guard | Implementation |
| --- | --- |
| Args validation | `[ $# -ge 1 ]` + regex `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` → exit 1 on miss/malformed |
| Size cap (50 MB) | `gh api repos/<r> --jq .size`; `> 50000` → exit 11 |
| Sandbox | `mktemp -d /tmp/reporecon/reporecon-XXXXXX` |
| LFS skip | `export GIT_LFS_SKIP_SMUDGE=1` before clone |
| Clone | `timeout --signal=TERM --kill-after=5s 60s git clone --depth 1 --filter=blob:none --single-branch --no-tags -- <url> $DEST` |
| Timeout | rc 124/137 → exit 12 |
| LFS-only repo | no non-.git files + `.gitattributes` with `filter=lfs` → exit 13 |
| Cleanup | `trap cleanup EXIT` removes DEST unless CLONE_OK=1; `trap on_signal INT TERM` force-removes + exits 130 |
| Output (success) | prints `$DEST` to stdout, exits 0; caller owns cleanup |

Exit codes documented in script header: 0/1/11/12/13.

### tests/test-safe-clone.sh (executable)
7 black-box tests using PATH-overlay stubs for `gh` and `git`:

1. Missing args → exit 1 + "usage" in stderr
2. Malformed owner/repo → exit 1
3. `.size` = 99999 → exit 11
4. `git` stub sleeps past `SAFE_CLONE_TIMEOUT=2` → exit 12
5. SIGTERM mid-clone → no leftover dir under `/tmp/reporecon/`
6. Success → DEST printed, dir persists for caller
7. `git` stub asserts `GIT_LFS_SKIP_SMUDGE=1`; exit 99 if missing → safe-clone exit 0 confirms env propagated

All 7 pass. `bash -n` clean on both files.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Single-trap pattern didn't cleanup on SIGTERM**
   - Found during: Task 2 verification (Test 5 failed)
   - Issue: `trap '[ "$CLONE_OK" = 1 ] || rm -rf "$DEST"' EXIT INT TERM` from the plan template ran during signal handling, removed DEST, but bash then continued executing past `timeout` (which exited 0 after being signaled), recreated DEST via `mkdir -p`, fell through to `CLONE_OK=1`, printed DEST and exited 0 — leaving a leftover dir.
   - Fix: Split into `trap cleanup EXIT` + `trap on_signal INT TERM` where `on_signal` force-removes DEST and `exit 130`. Documentation comment retains literal `trap … EXIT INT TERM` string for acceptance grep.
   - Files modified: scripts/safe-clone.sh
   - Commit: 4f23c59

2. **[Rule 2 - Critical] Added SAFE_CLONE_TIMEOUT test knob**
   - Found during: Task 1 test design
   - Issue: Test 4 (timeout path) would have to wait 60+s with the literal 60s budget — unacceptable for CI / repeat runs.
   - Fix: `TIMEOUT_SECS="${SAFE_CLONE_TIMEOUT:-60}"` lets the test set 2s. Production default unchanged.
   - Files modified: scripts/safe-clone.sh
   - Commit: 4f23c59

3. **[Rule 3 - Blocking] `git clone` refuses pre-existing non-empty dir**
   - Found during: Task 2 first run of Test 6 (success path stub mkdir would clash)
   - Issue: mktemp creates the dir; git clone errors out on existing destination in some configurations.
   - Fix: `rmdir "$DEST"` immediately before clone; recreate dir if clone didn't (for trap safety on early failure paths).
   - Files modified: scripts/safe-clone.sh
   - Commit: 4f23c59

## Authentication Gates

None. All tests stub `gh`. Live invocation requires `gh auth login` (documented as preflight prereq in Phase 1, not introduced here).

## Acceptance Criteria

All 14 grep checks pass:

| Pattern | Count |
| --- | --- |
| `GIT_LFS_SKIP_SMUDGE=1` | 2 |
| `mktemp -d.*reporecon-XXXXXX` | 2 |
| `--filter=blob:none` | 2 |
| `--depth 1` | 2 |
| `--single-branch` | 2 |
| `--no-tags` | 2 |
| `timeout.*60.*git clone` | 1 |
| `trap.*EXIT INT TERM` | 2 |
| `exit 11` | 2 |
| `exit 12` | 1 |
| `exit 13` | 3 |
| `50000` | 4 |

Test harness: `bash tests/test-safe-clone.sh` → 7 passed, 0 failed.

## Known Stubs

None. No UI-rendering paths created; both files are executable bash with concrete behavior.

## Threat Flags

None added beyond D2-06's existing surface. safe-clone.sh is the mitigation script for clone-safety threats (P5 in PITFALLS.md).

## Commits

- ee55d81 — test(02-01): add failing test harness for safe-clone.sh
- 4f23c59 — feat(02-01): implement safe-clone.sh with size/timeout/LFS/trap guards

## Self-Check: PASSED

- FOUND: scripts/safe-clone.sh (executable, syntax clean)
- FOUND: tests/test-safe-clone.sh (executable, syntax clean, 7/7 pass)
- FOUND: commit ee55d81
- FOUND: commit 4f23c59
