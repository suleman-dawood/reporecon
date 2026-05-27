#!/usr/bin/env bash
# Wrap `gh api search/repositories` with jq-normalized output.
#
# Usage:
#   gh-search.sh "<query>"
#   gh-search.sh "<query>" --in {name|description|readme|name,description,readme}
#   gh-search.sh "topic:<tag>"                # auto-detected: hits topic index, no in: qualifier
#   gh-search.sh "<query>" --per-page <N>     # override default recall (default 30)
#
# Output: JSON array of {full_name, description, stars, pushed_at, archived, language, url}
#
# Recall over precision: default per_page=30 — downstream dedup + rank handles noise.
# Topic detection: query consisting solely of `topic:<tag>` tokens bypasses the
# `in:` qualifier and hits GitHub's topic index directly.
#
# Exit codes:
#   0   success
#   1   generic gh failure
#   2   bad flag
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
      echo "$output" >&2
      return 1
    fi
  done
}

query="${1:?usage: gh-search.sh <query> [--in <fields>] [--per-page <N>]}"
shift || true

in_fields="name,description,readme"
per_page=30

while [ $# -gt 0 ]; do
  case "$1" in
    --in)
      in_fields="${2:?--in requires a value}"
      shift 2
      ;;
    --per-page)
      per_page="${2:?--per-page requires a value}"
      shift 2
      ;;
    *)
      echo "gh-search.sh: unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

# Topic-only query: every whitespace-separated token starts with `topic:`.
# Hit GitHub's topic index directly (no in: qualifier — separate search axis).
is_topic_only=1
for tok in $query; do
  case "$tok" in
    topic:*) ;;
    *) is_topic_only=0; break ;;
  esac
done

if [ "$is_topic_only" -eq 1 ]; then
  q="$query"
else
  q="$query in:$in_fields"
fi

gh_with_backoff -X GET search/repositories \
  -f q="$q" \
  -f sort=stars \
  -f order=desc \
  -f per_page="$per_page" \
  --jq '[.items[] | {
    full_name,
    description,
    stars: .stargazers_count,
    pushed_at,
    archived,
    language,
    url: .html_url
  }]'
