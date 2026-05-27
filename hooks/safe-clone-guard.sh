#!/usr/bin/env bash
# safe-clone-guard.sh — PreToolUse:Bash hook.
# Intercepts `git clone` commands and enforces RepoRecon's clone-safety contract:
#  - size pre-check via gh api (rejects > 50MB)
#  - --depth 1 --filter=blob:none --single-branch --no-tags
#  - GIT_LFS_SKIP_SMUDGE=1
#  - 60s timeout
#
# Reads the Bash tool input on stdin (JSON), parses the `command` field.
# If it's a `git clone ...` invocation, rewrites the command with safety flags.
# If size pre-check fails, blocks the call with a clear reason.
# All other Bash commands pass through untouched.

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Bash" ] || { printf '{}\n'; exit 0; }

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

# Only intercept `git clone` (with possible leading env vars / flags); allow everything else.
if ! printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+clone([[:space:]]|$)'; then
  printf '{}\n'
  exit 0
fi

# Extract a GitHub repo URL if present.
REPO_URL=$(printf '%s' "$CMD" | grep -oE 'https?://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+(\.git)?|git@github\.com:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+(\.git)?' | head -1 || true)

# Size pre-check: only for github.com URLs
if [ -n "${REPO_URL:-}" ] && printf '%s' "$REPO_URL" | grep -q 'github.com'; then
  OWNER_REPO=$(printf '%s' "$REPO_URL" | sed -E 's|^https?://github\.com/||; s|^git@github\.com:||; s|\.git$||')
  SIZE_KB=$(gh api "repos/$OWNER_REPO" --jq '.size' 2>/dev/null || echo 0)
  MAX_KB=${REPORECON_MAX_SIZE_KB:-50000}
  if [ "${SIZE_KB:-0}" -gt "$MAX_KB" ] 2>/dev/null; then
    jq -nc --arg reason "safe-clone-guard: repo $OWNER_REPO is ${SIZE_KB}KB (>${MAX_KB}KB cap). RepoRecon refuses to clone large repos; use remote-inspection or raise REPORECON_MAX_SIZE_KB." '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
fi

# Rewrite the command to enforce safety flags.
NEW_CMD=$(printf '%s' "$CMD" | sed -E 's#(^|[;&|[:space:]])git[[:space:]]+clone[[:space:]]+#\1GIT_LFS_SKIP_SMUDGE=1 timeout 60 git clone --depth 1 --filter=blob:none --single-branch --no-tags #')

jq -nc --arg new_cmd "$NEW_CMD" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    updatedInput: {
      command: $new_cmd
    }
  }
}'
