#!/usr/bin/env bash
# D-27: gh auth status + gh api rate_limit gate. Emits budget JSON on success.
set -euo pipefail

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login" >&2
  exit 1
fi

if ! rate_json="$(gh api rate_limit 2>/dev/null)"; then
  echo "ERROR: gh api rate_limit failed (network? auth?)" >&2
  exit 2
fi

core_rem="$(printf '%s' "$rate_json" | jq -er '.resources.core.remaining' 2>/dev/null)" || {
  echo "ERROR: malformed rate_limit JSON (core.remaining missing). Run \`gh api rate_limit\` manually." >&2
  exit 2
}
search_rem="$(printf '%s' "$rate_json" | jq -er '.resources.search.remaining' 2>/dev/null)" || {
  echo "ERROR: malformed rate_limit JSON (search.remaining missing). Run \`gh api rate_limit\` manually." >&2
  exit 2
}

if ! [[ "$core_rem" =~ ^[0-9]+$ ]] || ! [[ "$search_rem" =~ ^[0-9]+$ ]]; then
  echo "ERROR: could not parse rate_limit JSON. Run \`gh api rate_limit\` manually." >&2
  exit 2
fi

if (( core_rem < 50 )) || (( search_rem < 10 )); then
  echo "ERROR: gh rate budget too low (core=$core_rem search=$search_rem). Wait for reset." >&2
  exit 3
fi

printf '{"core_remaining":%d,"search_remaining":%d}\n' "$core_rem" "$search_rem"
