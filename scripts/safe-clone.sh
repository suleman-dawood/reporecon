#!/usr/bin/env bash
# D2-06 / SCR-03: Safe shallow clone wrapper for deep-search inspection.
#
# Usage: safe-clone.sh <owner/repo>
#
# Guards:
#   - Pre-checks size via `gh api repos/<owner/repo> --jq .size` (KB).
#     Reject if size > 50000 KB (50 MB) → exit 11.
#   - Destination always under `mktemp -d /tmp/reporecon/reporecon-XXXXXX`.
#   - Exports GIT_LFS_SKIP_SMUDGE=1 before clone (no LFS payload fetch).
#   - Wraps with `timeout --signal=TERM --kill-after=5s 60s git clone --depth 1
#     --filter=blob:none --single-branch --no-tags` (GNU coreutils required).
#   - `trap '[ "$CLONE_OK" = 1 ] || rm -rf "$DEST"' EXIT INT TERM` ensures the
#     partial clone is cleaned on any failure/signal. On success the caller
#     owns cleanup of $DEST (it is printed to stdout).
#   - Post-clone LFS-only detection: if no non-.git files exist and a
#     .gitattributes declares `filter=lfs`, exit 13.
#
# Exit codes:
#   0   success — $DEST printed to stdout
#   1   bad args / malformed owner-repo / gh api failure / clone error
#   11  oversize (>50000 KB)
#   12  timeout (git clone exceeded 60s)
#   13  LFS-only repo (no source files after clone)
#
# Test-only knob: SAFE_CLONE_TIMEOUT overrides the 60s budget (used by
# tests/test-safe-clone.sh to keep the timeout test fast).
set -euo pipefail

usage() {
  echo "usage: safe-clone.sh <owner/repo>" >&2
  exit 1
}

[ $# -ge 1 ] || usage
OWNER_REPO="$1"

if ! [[ "$OWNER_REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
  echo "invalid owner/repo: $OWNER_REPO" >&2
  exit 1
fi

mkdir -p /tmp/reporecon
DEST="$(mktemp -d "/tmp/reporecon/reporecon-XXXXXX")"
CLONE_OK=0
cleanup() {
  [ "$CLONE_OK" = 1 ] || rm -rf "$DEST"
}
on_signal() {
  CLONE_OK=0
  rm -rf "$DEST"
  exit 130
}
# Single trap line covers EXIT INT TERM per D2-06 contract; INT/TERM also
# force-exit via on_signal so signals received mid-clone don't fall through.
trap cleanup EXIT; trap on_signal INT TERM

# Size pre-check (KB).
if ! size_kb="$(gh api "repos/${OWNER_REPO}" --jq .size 2>/dev/null)"; then
  echo "gh api failed for ${OWNER_REPO}" >&2
  exit 1
fi
if ! [[ "$size_kb" =~ ^[0-9]+$ ]]; then
  echo "unexpected size from gh api: '$size_kb'" >&2
  exit 1
fi
if [ "$size_kb" -gt 50000 ]; then
  echo "oversize: ${OWNER_REPO} is ${size_kb}KB (>50000)" >&2
  exit 11
fi

export GIT_LFS_SKIP_SMUDGE=1

TIMEOUT_SECS="${SAFE_CLONE_TIMEOUT:-60}"

# mktemp already created $DEST; git clone refuses non-empty existing dirs,
# so remove the empty placeholder before cloning.
rmdir "$DEST"

set +e
timeout --signal=TERM --kill-after=5s "${TIMEOUT_SECS}s" \
  git clone --depth 1 --filter=blob:none --single-branch --no-tags -- \
  "https://github.com/${OWNER_REPO}.git" "$DEST"
rc=$?
set -e

# Recreate $DEST if the stub/clone didn't (so trap rm -rf is always safe).
[ -d "$DEST" ] || mkdir -p "$DEST"

if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
  echo "timeout cloning ${OWNER_REPO} (>${TIMEOUT_SECS}s)" >&2
  exit 12
fi
if [ "$rc" -ne 0 ]; then
  echo "clone failed rc=$rc for ${OWNER_REPO}" >&2
  exit 1
fi

# LFS-only detection: no non-.git files AND .gitattributes uses filter=lfs.
non_lfs_files="$(find "$DEST" -type f -not -path '*/.git/*' 2>/dev/null | head -1 || true)"
if [ -z "$non_lfs_files" ] \
   && [ -f "$DEST/.gitattributes" ] \
   && grep -q 'filter=lfs' "$DEST/.gitattributes" 2>/dev/null; then
  echo "LFS-only repo: ${OWNER_REPO}" >&2
  exit 13
fi

CLONE_OK=1
echo "$DEST"
