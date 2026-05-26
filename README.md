# RepoRecon

Validate whether your project idea already exists on GitHub before you build it. RepoRecon runs a fast metadata-only quick verdict (~90s) with an opt-in deep inspection mode that clones top candidates and judges equivalence with cited evidence.

## Install

```
/plugin marketplace add suleman-dawood/reporecon
/plugin install reporecon@reporecon
```

## Prerequisites

- `gh auth login` (authenticated GitHub CLI session — required for usable rate budget)
- `gh` >= 2.55
- `jq` >= 1.7
- `bash` >= 4 (macOS users: `brew install bash coreutils`)

## Usage

```
/reporecon <one-sentence project idea>
```

Or trigger the skill ambiently with phrases like "does this exist on github", "validate my idea", or "is there already a tool that does X".

## Status

Phase 1 (Tier 1 MVP) — not yet ready for marketplace submission.
