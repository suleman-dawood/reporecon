# E2E test suite

Script-pipeline end-to-end tests. Each scenario chains multiple `scripts/*.sh`
together using the same `gh` / `curl` / `git` mocks that the unit tests use
under `tests/lib/mock-bin/`.

## What this catches that unit tests don't

- JSON-schema contracts BETWEEN scripts (gh-search output → verify-repo input)
- Retry/backoff behaviour in pipeline context, not just isolation
- Cache roundtrip + TTL across the full first-search flow
- Vapor-check + safe-clone interaction with planted fixture trees
- SaaS verify-url filtering as it runs in the SKILL.md step-3.5 mini-pipeline
- status.sh stdout-clean contract under a realistic event sequence

## What's out of scope

- The actual LLM judge calls — those need `claude` headless mode + API key
  and live in `tests/run-goldens.sh` / `.github/workflows/goldens.yml`.
- The SKILL.md orchestration prompt — that's a model-driven artifact, not a
  bash script.

## Scenarios

| File | Pipeline covered |
|------|------------------|
| `e2e-first-search-flow.sh`    | preflight → gh-search ×7 (parallel) → dedup-rank → verify-repo → staleness → cache |
| `e2e-deep-search-clone.sh`    | safe-clone (mocked git) → vapor-check (real, reads planted tree) |
| `e2e-cache-roundtrip.sh`      | cache.sh: key → put → get → invalidate → TTL expiry → prune |
| `e2e-rate-limit-recovery.sh`  | gh_with_backoff retry + exhaustion in gh-search and verify-repo |
| `e2e-saas-pool.sh`            | SKILL.md step 3.5: verify-url filter over a mixed candidate pool |
| `e2e-status-pipeline.sh`      | status.sh start/tick/done/error sequence; stdout-clean contract |

## Running

```bash
bash tests/e2e/e2e-first-search-flow.sh
bash tests/e2e/e2e-deep-search-clone.sh
# ... etc.
```

Or all at once via the top-level runner: `bash tests/run-all-tests.sh`.
The runner globs both `tests/test-*.sh` (unit) and `tests/e2e/e2e-*.sh` (e2e).
