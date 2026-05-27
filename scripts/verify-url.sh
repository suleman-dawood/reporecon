#!/usr/bin/env bash
# Existence check for non-GitHub web_candidate URLs (SaaS landing pages,
# YC profiles, marketplace listings). Drops hallucinated URLs from
# WebSearch SEO spam before they reach the report.
#
# Usage: verify-url.sh <url>
#
# Exit codes:
#   0  = reachable (HTTP 2xx or 3xx); emits JSON
#        {url, http_code, final_url, checked_at} to stdout
#   20 = HTTP 4xx
#   21 = HTTP 5xx
#   22 = timeout / connection refused / DNS failure
#   23 = invalid URL (must start with http:// or https://)
#   1  = unexpected error
#
# Hard rule: never log the response body. Only URL + status code.
set -euo pipefail

url="${1:?usage: verify-url.sh <url>}"

if [[ ! "$url" =~ ^https?:// ]]; then
  exit 23
fi

tmp_out="$(mktemp)"
trap 'rm -f "$tmp_out"' EXIT

set +e
curl -sS -L \
  --max-time 10 \
  --max-redirs 5 \
  -o /dev/null \
  -w '%{http_code}|%{url_effective}' \
  "$url" >"$tmp_out" 2>/dev/null
curl_rc=$?
set -e

if (( curl_rc != 0 )); then
  case "$curl_rc" in
    6|7|28|35) exit 22 ;;   # DNS, connect refused, timeout, SSL connect
    *) exit 1 ;;
  esac
fi

raw="$(cat "$tmp_out")"
http_code="${raw%%|*}"
final_url="${raw#*|}"

if ! [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
  exit 1
fi

if (( http_code >= 200 && http_code < 400 )); then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -nc \
    --arg url "$url" \
    --argjson http_code "$http_code" \
    --arg final_url "$final_url" \
    --arg checked_at "$ts" \
    '{url: $url, http_code: $http_code, final_url: $final_url, checked_at: $checked_at}'
  exit 0
elif (( http_code >= 400 && http_code < 500 )); then
  exit 20
elif (( http_code >= 500 && http_code < 600 )); then
  exit 21
else
  exit 1
fi
