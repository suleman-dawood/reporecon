# RepoRecon — Marketplace Submission Checklist

Manual checklist for submitting the `reporecon` plugin to the Anthropic
marketplace (`claude-plugins-official`). Not automated — work through this
top-to-bottom before opening the marketplace PR.

## Pre-release notes for v0.2.0

This submission targets **v0.2.0**. See [CHANGELOG.md](./CHANGELOG.md) for the
full diff against v0.1.0 — headline changes are the mandatory Tier 1 WebSearch
cross-check (Step 3.5), two new query archetypes (`CANONICAL-NAMES`,
`TOPIC-TAG`), the Closed-Source / SaaS Competitors report block, and the
saturated-lane verdict rule. Reviewers should read the CHANGELOG before
exercising the smoke test below.

## Pre-flight

- [ ] All Phase 1 + Phase 2 + Phase 3 commits merged to `main`
- [ ] `bash tests/install-validation.sh` exits 0 from a clean checkout of `main`
- [ ] `gh auth status` reports an authenticated user with `repo` + `read:org` scopes
- [ ] `jq`, `gh`, and `git` are installed and on `PATH`
- [ ] Local end-to-end smoke test: run `/reporecon <real idea>` in a fresh
      Claude Code session and confirm a verdict block + Markdown report is
      written to `./reporecon-reports/`. (Must be run manually — headless CLI
      flow varies.)
- [ ] No secrets, tokens, or `gh auth` output anywhere in the repo
- [ ] `LICENSE` present and matches what's declared in `package.json` /
      `plugin.json`
- [ ] `README.md` references the install command and the `/reporecon` trigger

## Marketplace PR

- [ ] Fork https://github.com/anthropics/claude-plugins-official (or whichever
      repo is the current Anthropic marketplace at time of submission)
- [ ] Add a marketplace entry that references this repo's `marketplace.json`
      source URL: `https://github.com/suleman-dawood/reporecon`
- [ ] Open the PR with the title:
      `Add: reporecon — validate project ideas against GitHub before building`
- [ ] PR body MUST include:
  - Link to this repo's `README.md`
  - Links to 3 example runs under `examples/`
  - Screenshot of a Tier 1 verdict block in chat
  - One-line summary of what reporecon does + the Tier 1 / Tier 2 split
- [ ] Wait for marketplace maintainer review; respond to review comments
      within 48h
- [ ] Once approved, confirm the entry merges cleanly into the marketplace
      index

## Post-submission

- [ ] Update this `SUBMISSION.md` with the PR URL (replace this line):
      `Marketplace PR: <URL>`
- [ ] Tag a `v0.2.0` release on this repo:
      `git tag v0.2.0 && git push --tags`
- [ ] Create a GitHub Release for `v0.2.0` with the same body as the
      marketplace PR description
- [ ] Verify install in a fresh Claude Code env: from a clean machine,
      `/plugin install reporecon` from the Anthropic marketplace and confirm
      `/reporecon <idea>` runs end-to-end
- [ ] Announce in repo `README.md` (add an "Installation" line pointing at the
      marketplace once live)

---

This file is intentionally tracked in the public repo as plugin-author
documentation. It is not consumed by Claude Code at runtime.
