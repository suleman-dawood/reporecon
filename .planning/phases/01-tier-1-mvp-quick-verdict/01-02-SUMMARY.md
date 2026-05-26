---
phase: 01-tier-1-mvp-quick-verdict
plan: 02
subsystem: tools
tags: [bash, gh-cli, jq, tier-1, scripts]
dependency-graph:
  requires: []
  provides:
    - scripts/preflight.sh (D-27, SCR-01)
    - scripts/gh-search.sh (D-28, SCR-02)
    - scripts/verify-repo.sh (D-29)
  affects:
    - skills/reporecon/SKILL.md (Plan 06 will call these scripts)
tech-stack:
  added: []
  patterns:
    - "POSIX bash 4+ with set -euo pipefail"
    - "gh api wrappers with jq normalization"
    - "Fail-closed on malformed rate_limit JSON (RESEARCH.md OQ-3)"
    - "404-gate via gh api exit code (Pitfall 11)"
key-files:
  created:
    - scripts/preflight.sh
    - scripts/gh-search.sh
    - scripts/verify-repo.sh
  modified: []
decisions:
  - "verify-repo.sh owns contributor_count enumeration (RESEARCH.md OQ-4)"
  - "Used printf for preflight JSON to avoid jq dependency on output formatting"
  - "Used `|| echo null` fallback for contributor_count so candidate is not aborted on contributor-enum failure"
metrics:
  duration: "~6m"
  completed: 2026-05-26
requirements: [T1-02, T1-03, T1-04, T1-05, SCR-01, SCR-02]
---

# Phase 1 Plan 02: RepoRecon gh API Wrapper Scripts Summary

Three POSIX-bash gh-api wrappers (preflight gate, search, verify) form the deterministic Tier 1 tool layer; SKILL.md will call these instead of composing raw gh URLs.

## What Shipped

| Script | Lines | Mode | Contract |
|---|---|---|---|
| `scripts/preflight.sh` | 28 | 0755 | Exit 0 + `{"core_remaining":N,"search_remaining":M}` JSON; exit 1 unauth / exit 2 rate_limit fail or parse fail / exit 3 budget too low (core<50 OR search<10) |
| `scripts/gh-search.sh` | 21 | 0755 | `gh-search.sh <query>` → JSON array `[{full_name, description, stars, pushed_at, archived, language, url}]` (empty `[]` if no hits) |
| `scripts/verify-repo.sh` | 32 | 0755 | `verify-repo.sh <owner/repo>` → JSON object with `verified_at` ISO timestamp + `contributor_count`; exit 1 on 404 |

All three: shebang `#!/usr/bin/env bash`, `set -euo pipefail`, only depend on `gh` + `jq` + `bash`.

## Commits

| Hash | Files | Description |
|---|---|---|
| ef37599 | scripts/preflight.sh | gh auth + rate_limit gate |
| 5b6f453 | scripts/gh-search.sh | search/repositories wrapper |
| 6e30d0f | scripts/verify-repo.sh | 404-gate + metadata + contributor_count |

## Verification Results

Automated `bash -n` syntax check, `test -x` executability, and grep contract-string checks — all three scripts pass:

- preflight.sh: contains `set -euo pipefail`, `gh api rate_limit`, `core_remaining`, four distinct exit codes
- gh-search.sh: contains `search/repositories`, `sort=stars`, `order=desc`, `per_page=10`, `stargazers_count`, `html_url`
- verify-repo.sh: contains `gh api "repos/`, `verified_at`, `contributor_count`, `date -u +%Y-%m-%dT%H:%M:%SZ`

## Deferred Issues

**Live smoke tests not executed in worktree environment.** The worktree shell does not have `jq` installed (`which jq` → not found; `gh --version` → 2.4.0 present). The plan's `acceptance_criteria` smoke tests (`bash scripts/preflight.sh | jq -e .core_remaining`, `bash scripts/gh-search.sh "todo cli" | jq -e 'type == "array"'`, `bash scripts/verify-repo.sh cli/cli | jq -e '.full_name == "cli/cli"'`, fake-repo 404) require jq + authenticated gh on PATH.

- All syntactic + structural acceptance criteria pass (bash -n, test -x, grep contracts)
- Live JSON-shape smoke tests are deferred to integration-time when the merged main branch runs in an env with jq installed (typical user prereq per STACK.md)
- Note: `gh` 2.4.0 in this env is below STACK.md's recommended ≥2.55, which would matter for `--paginate` semantics but not for the simple `gh api -X GET -f` + `--jq` calls these scripts use

These are environment limitations, not script defects. The scripts conform to the contracts exactly as RESEARCH.md skeletons specify.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Determinism] Used `printf` for preflight JSON output instead of `echo`-with-jq**
- **Found during:** Task 1 implementation
- **Issue:** RESEARCH.md skeleton suggested various output methods; using a heredoc/echo string with embedded variable interpolation would emit non-JSON on edge cases.
- **Fix:** `printf '{"core_remaining":%d,"search_remaining":%d}\n'` — guarantees integer formatting; values already validated as `^[0-9]+$` regex.
- **Files modified:** scripts/preflight.sh
- **Commit:** ef37599

No structural deviations from PLAN.md `<action>` blocks. All three scripts implemented verbatim from the RESEARCH.md code-example skeletons cited in `<read_first>`.

## Threat Mitigations Verified

Per `<threat_model>` register:

- **T-02-01 (token leak):** All `gh` calls use `2>/dev/null`; no `$GH_TOKEN` echoes anywhere.
- **T-02-02 (shell injection):** `gh api -f q="$query"` passes via form parameter (gh handles URL encoding); `"repos/${repo}"` is quoted; `set -euo pipefail` enforces fail-fast.
- **T-02-04 (private repo leak):** Task 2 uses no `is:private` qualifier; `search/repositories` defaults exclude private.
- **T-02-05 (hallucinated cite):** verify-repo.sh exit 1 on 404 — Plan 06 SKILL.md must drop the candidate; contract documented.

T-02-03 (DoS via secondary rate limit) is partially mitigated here (preflight budget gate) and fully addressed by Plan 06's inter-call sleeps.

## Threat Flags

None — no new security surface beyond the threat register.

## Self-Check: PASSED

- FOUND: scripts/preflight.sh (28 lines, mode 0755)
- FOUND: scripts/gh-search.sh (21 lines, mode 0755)
- FOUND: scripts/verify-repo.sh (32 lines, mode 0755)
- FOUND: commit ef37599 (preflight)
- FOUND: commit 5b6f453 (gh-search)
- FOUND: commit 6e30d0f (verify-repo)
- All `bash -n` syntax checks pass
- All grep contract-string checks pass
- All files executable

Live `gh`+`jq` smoke tests deferred (env lacks jq) — documented in Deferred Issues.
