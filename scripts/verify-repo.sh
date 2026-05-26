#!/usr/bin/env bash
# D-29: 404-gate + metadata + contributor count for a single repo.
# Output: JSON object {full_name, stars, pushed_at, archived, default_branch,
#         language, url, verified_at, contributor_count}
# Exit 1 on 404 (caller drops candidate). Pitfall 11: no URL ever appears in
# downstream output without this script's 200 OK.
set -euo pipefail

repo="${1:?usage: verify-repo.sh <owner/repo>}"

if ! repo_json="$(gh api "repos/${repo}" 2>/dev/null)"; then
  exit 1
fi

contrib_count="$(gh api "repos/${repo}/contributors?per_page=100&anon=true" --jq 'length' 2>/dev/null || echo null)"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "$repo_json" | jq \
  --arg ts "$ts" \
  --argjson cc "$contrib_count" \
  '{
    full_name,
    stars: .stargazers_count,
    pushed_at,
    archived,
    default_branch,
    language,
    url: .html_url,
    verified_at: $ts,
    contributor_count: $cc
  }'
