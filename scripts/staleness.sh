#!/usr/bin/env bash
# staleness.sh — mechanical badge emitter for RepoRecon Tier 1.
#
# Reads a metadata JSON string (as produced by verify-repo.sh) and emits
# space-separated badge tags on stdout. Empty string if nothing fires.
#
# Badges:
#   archived          — .archived == true
#   stale-12mo        — pushed_at older than 365 days
#   solo-stale-6mo    — contributor_count == 1 AND pushed_at older than 180 days
#
# Per D-22: badges are surfaced; they never auto-downgrade the verdict.
# Per HEUR-03: no auto-downgrade — script just emits flags.

set -euo pipefail

meta="${1:?usage: staleness.sh <metadata-json>}"

archived=$(echo "$meta" | jq -r '.archived')
pushed_at=$(echo "$meta" | jq -r '.pushed_at')
contributor_count=$(echo "$meta" | jq -r '.contributor_count // "null"')

# Cross-platform epoch conversion: GNU date first, BSD/macOS date fallback.
pushed_s=$(date -u -d "$pushed_at" +%s 2>/dev/null \
  || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$pushed_at" +%s 2>/dev/null) \
  || pushed_s=0
now_s=$(date -u +%s)
age_d=$(( (now_s - pushed_s) / 86400 ))

badges=()
[[ "$archived" == "true" ]] && badges+=("archived")
[[ "$age_d" -gt 365 ]] && badges+=("stale-12mo")
if [[ "$contributor_count" =~ ^[0-9]+$ && "$contributor_count" -eq 1 && "$age_d" -gt 180 ]]; then
  badges+=("solo-stale-6mo")
fi

echo "${badges[*]:-}"
