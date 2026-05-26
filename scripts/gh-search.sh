#!/usr/bin/env bash
# D-28: wrap gh api search/repositories with jq-normalized output.
# Output: JSON array of {full_name, description, stars, pushed_at, archived, language, url}
set -euo pipefail

query="${1:?usage: gh-search.sh <query>}"

gh api -X GET search/repositories \
  -f q="$query" \
  -f sort=stars \
  -f order=desc \
  -f per_page=10 \
  --jq '[.items[] | {
    full_name,
    description,
    stars: .stargazers_count,
    pushed_at,
    archived,
    language,
    url: .html_url
  }]'
