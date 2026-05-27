# RepoRecon

A Claude Code plugin that checks if your project idea already exists on GitHub before you build it.

```
🟢  No close match
🟡  Adjacent prior art — worth a closer look
🔴  Strong overlap — someone has likely shipped this
```

## Install

> ⚠️ Run these **inside the Claude Code chat**, not your shell terminal. Type them with the leading `/` like you would `/help` or `/clear`.

```
/plugin marketplace add suleman-dawood/reporecon
/plugin install reporecon@reporecon
```

Fully quit and reopen Claude Code so the plugin registers (not `/clear` — actually close the app process).

## Prerequisites

- **`gh auth login`** — authenticated GitHub CLI session ([gh CLI docs](https://cli.github.com)). Anonymous rate limits will fail preflight.
- `gh` ≥ 2.55
- `jq` ≥ 1.7
- **`WebSearch` tool must be enabled** in your Claude Code session — RepoRecon aborts the run if it isn't. Silent skips were a 0.1 bug; we'd rather fail loudly.
- macOS: `brew install bash coreutils` (GNU `timeout` + `bash` ≥ 4)

Verify:

```
gh auth status && gh --version && jq --version
```

## Use

```
/reporecon I want to build a CLI that previews diffs as a side-by-side TUI
```

Or just describe an idea naturally in chat:

- *"is there already a tool that does X"*
- *"validate my idea before I start building"*
- *"does this exist on github"*

You get a verdict in ~90 seconds. If it's 🟡 or 🔴, reply `deep search` (or `yes` / `dig deeper`) to clone the top candidates and get file-path-cited evidence (~10 min).

Reports land in `./reporecon-reports/YYYY-MM-DD-<slug>.md`. One file per idea.

### What you'll see

A chat verdict block like this:

```
🟡  Some overlap — worth a closer look

Your idea: "side-by-side TUI diff previewer with syntax highlighting"
Top match: dandavison/delta (28k★, active) — WORTH_INSPECTING

Reply 'deep search' to clone the top candidates and judge
with file-path evidence (~10 min).

Report: ./reporecon-reports/2026-05-27-tui-diff-previewer.md
```

The on-disk report has the full per-candidate breakdown, axis scores, and — after a deep search — cited evidence by `path/file.ext:LINE`.

## Not triggering?

If `/reporecon` doesn't seem to do anything after install:

1. Confirm the plugin shows up: type `/plugin` in chat
2. Try the natural-language trigger ("does this exist on github") — bypasses slash-command routing
3. `/plugin uninstall reporecon` → `/plugin install reporecon@reporecon` → **fully restart Claude Code** (close the app, not `/clear`)

## Limitations

- **GitHub-only.** GitLab, Codeberg, self-hosted forges, and package-registry-only tools are not searched.
- **WebSearch results drift.** Same query on different days can shift the verdict on borderline ideas.
- **Verify before you decide.** RepoRecon narrows the search; it doesn't replace reading the top candidate's README yourself.

## License

MIT — see [LICENSE](./LICENSE).
