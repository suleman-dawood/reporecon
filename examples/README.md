# RepoRecon Example Reports

This directory contains three illustrative RepoRecon reports covering the verdict spectrum. Use them to preview the output shape before running the skill against your own idea.

| File | Scenario | Verdict |
| ---- | -------- | ------- |
| [saturated-todo-cli.md](./saturated-todo-cli.md) | A crowded niche (Rust CLI todo manager) where multiple strong matches already exist. | 🔴 "This exists" |
| [novel-obscure-niche.md](./novel-obscure-niche.md) | A genuinely sparse niche (NDIS support-plan compliance auditor) with no close match. | 🟢 "No close match" |
| [ambiguous-llm-eval-dashboard.md](./ambiguous-llm-eval-dashboard.md) | A fragmented niche (side-by-side LLM evaluation dashboard) with partial overlaps and one vapor repo. | 🟡 "Some overlap" |

## About these reports

**These reports are generated from fixture data.** They are realistic templates populated from the judge rubric (`skills/reporecon/references/judge-rubric.md`) and the report template (`skills/reporecon/references/report-template.md`), not from live `gh api` traffic. Repo names, timestamps, axis scores, and file-path evidence are illustrative. Live golden runs are deferred to user-machine validation because RepoRecon depends on the user's authenticated `gh` CLI and rate-limit budget — see the project README for setup and how to run the skill against your own idea.

## Running on your own idea

See the top-level [README](../README.md) for installation, `gh` authentication, and how to invoke the `reporecon` skill from inside Claude Code.
