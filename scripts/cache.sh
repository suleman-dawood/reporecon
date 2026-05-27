#!/usr/bin/env bash
# Idea-hash result cache for RepoRecon. Skips identical runs within 1h TTL.
#
# Usage: cache.sh <verb> [args...]
#
# Verbs:
#   key <sentence>     Print sha1 of normalized sentence (lowercase, collapsed
#                      whitespace, trimmed). Exit 0.
#   get <key>          If ~/.cache/reporecon/<key>.json exists AND mtime within
#                      3600s, print contents. Exit 0 hit, 10 miss.
#   put <key>          Read JSON from stdin, atomic write via tempfile+mv,
#                      mode 600. Exit 0 ok, 1 fail.
#   invalidate <key>   rm -f cache file. Exit 0 always (idempotent).
#   prune              Delete files older than 24h. Exit 0.
#
# Exit codes: 0 ok | 1 write fail | 2 usage | 10 cache miss
set -euo pipefail

CACHE_DIR="${HOME}/.cache/reporecon"
TTL_SECONDS=3600
PRUNE_SECONDS=86400

ensure_dir() {
  mkdir -p "$CACHE_DIR"
  chmod 700 "$CACHE_DIR" 2>/dev/null || true
}

verb="${1:-}"
[[ -n "$verb" ]] || { echo "usage: cache.sh <key|get|put|invalidate|prune> [args]" >&2; exit 2; }
shift || true

case "$verb" in
  key)
    sentence="${1:?usage: cache.sh key <sentence>}"
    printf '%s' "$sentence" \
      | tr '[:upper:]' '[:lower:]' \
      | tr -s '[:space:]' ' ' \
      | sed 's/^ //;s/ $//' \
      | sha1sum \
      | cut -d' ' -f1
    ;;
  get)
    k="${1:?usage: cache.sh get <key>}"
    f="${CACHE_DIR}/${k}.json"
    [[ -f "$f" ]] || exit 10
    mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
    now="$(date +%s)"
    age=$(( now - mtime ))
    (( age < TTL_SECONDS )) || exit 10
    cat "$f"
    ;;
  put)
    k="${1:?usage: cache.sh put <key>}"
    ensure_dir
    tmp="${CACHE_DIR}/.tmp.${k}.$$"
    if ! cat > "$tmp"; then
      rm -f "$tmp"
      exit 1
    fi
    chmod 600 "$tmp" 2>/dev/null || true
    mv "$tmp" "${CACHE_DIR}/${k}.json" || { rm -f "$tmp"; exit 1; }
    ;;
  invalidate)
    k="${1:?usage: cache.sh invalidate <key>}"
    rm -f "${CACHE_DIR}/${k}.json"
    exit 0
    ;;
  prune)
    [[ -d "$CACHE_DIR" ]] || exit 0
    find "$CACHE_DIR" -maxdepth 1 -type f -mmin +$((PRUNE_SECONDS / 60)) -delete 2>/dev/null || true
    exit 0
    ;;
  *)
    echo "unknown verb: $verb" >&2
    exit 2
    ;;
esac
