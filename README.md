# RepoRecon

A Claude Code plugin that checks if your project idea already exists on GitHub before you build it.

```
🟢  No close match
🟡  Adjacent prior art — worth a closer look
🔴  Strong overlap — someone has likely shipped this
```

## Install

In Claude Code:

```
/plugin marketplace add suleman-dawood/reporecon
/plugin install reporecon@reporecon
```

Restart Claude Code so the plugin registers.

## Prerequisites

- `gh auth login` — authenticated GitHub CLI session (anonymous rate limits will fail)
- `gh` ≥ 2.55
- `jq` ≥ 1.7
- macOS: `brew install bash coreutils` (GNU `timeout` + bash ≥ 4)

Check your environment:

```
gh auth status && gh --version && jq --version
```

## Use

```
/reporecon I want to build a CLI that previews diff output as a side-by-side TUI
```

Or just ask in chat: *"does this already exist on github"*, *"validate my idea"*, *"is there a tool that does X"*.

You get a verdict in ~90 seconds. If the verdict is 🟡 or 🔴, reply `deep search` (or `yes` / `dig deeper`) to clone the top candidates and get file-path-cited evidence (~10 min).

Reports land in `./reporecon-reports/YYYY-MM-DD-<slug>.md`. One file per idea.

## Limitations

- **GitHub-only.** GitLab, Codeberg, self-hosted forges, and package-registry-only tools are not searched.
- **WebSearch results drift.** Same query on different days can shift the verdict on borderline ideas.
- **Verify before you decide.** RepoRecon narrows the search; it doesn't replace reading the top candidate's README yourself.

## License

MIT — see [LICENSE](./LICENSE).
