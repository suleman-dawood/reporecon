#!/usr/bin/env bash
# D-29: 404-gate + metadata + contributor count for a single repo.
# Output: JSON object {full_name, stars, pushed_at, archived, default_branch,
#         language, url, verified_at, contributor_count}
# Exit 1 on 404 (caller drops candidate). Pitfall 11: no URL ever appears in
# downstream output without this script's 200 OK.
#
# Exit codes:
#   0   success
#   1   repo not found / gh failure
#  78   gh rate limit exhausted after retries
set -euo pipefail

# Retry gh api on secondary rate-limit / 429: backoff 5s, 10s, then fail with 78.
gh_with_backoff() {
  local attempt=0
  local max_attempts=2
  local backoff_secs=5
  local output
  while [ $attempt -lt $max_attempts ]; do
    if output=$(gh api "$@" 2>&1); then
      printf '%s\n' "$output"
      return 0
    fi
    if echo "$output" | grep -qiE 'secondary rate limit|rate limit|HTTP 429'; then
      attempt=$((attempt + 1))
      if [ $attempt -ge $max_attempts ]; then
        echo "ERROR: gh rate-limit hit after $max_attempts attempts" >&2
        echo "$output" >&2
        return 78
      fi
      echo "Rate-limited, sleeping ${backoff_secs}s before retry $attempt/$max_attempts" >&2
      sleep $backoff_secs
      backoff_secs=$((backoff_secs * 2))
    else
      return 1
    fi
  done
}

repo="${1:?usage: verify-repo.sh <owner/repo>}"

rc=0
repo_json="$(gh_with_backoff "repos/${repo}" 2>/dev/null)" || rc=$?
if [ "$rc" -ne 0 ]; then
  [ "$rc" -eq 78 ] && exit 78
  exit 1
fi

rc=0
contrib_count="$(gh_with_backoff "repos/${repo}/contributors?per_page=100&anon=true" --jq 'length' 2>/dev/null)" || rc=$?
if [ "$rc" -ne 0 ]; then
  [ "$rc" -eq 78 ] && exit 78
  contrib_count=null
fi

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
