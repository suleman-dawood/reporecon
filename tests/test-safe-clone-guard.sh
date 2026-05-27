#!/usr/bin/env bash
# test-safe-clone-guard.sh — unit tests for hooks/safe-clone-guard.sh
#
# Verifies the PreToolUse:Bash hook:
#  - rewrites `git clone` with the clone-safety contract
#  - denies oversize repos via gh api size pre-check
#  - honours GITHUBPILL_MAX_SIZE_KB override
#  - passes through non-clone Bash commands and non-Bash tools
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$HERE/lib/assert.sh"
export PATH="$HERE/lib/mock-bin:$PATH"

_log "=== test-safe-clone-guard ==="

HOOK="$ROOT/hooks/safe-clone-guard.sh"

# Case 1: git clone gets rewritten with safety flags
INPUT='{"tool_name":"Bash","tool_input":{"command":"git clone https://github.com/octocat/Hello-World /tmp/test"}}'
export MOCK_GH_FIXTURE='100'
OUT=$(printf '%s' "$INPUT" | bash "$HOOK")
assert_contains "GIT_LFS_SKIP_SMUDGE=1" "$OUT" "lfs skip injected"
assert_contains "--depth 1" "$OUT" "depth 1 injected"
assert_contains "--filter=blob:none" "$OUT" "filter blob:none injected"
assert_contains "--single-branch" "$OUT" "single-branch injected"
assert_contains "--no-tags" "$OUT" "no-tags injected"
assert_contains "timeout 60" "$OUT" "timeout injected"
assert_contains "allow" "$OUT" "decision allow"

# Case 2: oversize repo (> 50000 KB) gets DENIED
INPUT='{"tool_name":"Bash","tool_input":{"command":"git clone https://github.com/torvalds/linux /tmp/big"}}'
export MOCK_GH_FIXTURE='99999'
OUT=$(printf '%s' "$INPUT" | bash "$HOOK")
assert_contains "deny" "$OUT" "oversize denied"
assert_contains "50000KB cap" "$OUT" "size reason emitted"

# Case 3: GITHUBPILL_MAX_SIZE_KB env override raises the cap
INPUT='{"tool_name":"Bash","tool_input":{"command":"git clone https://github.com/torvalds/linux /tmp/big2"}}'
export MOCK_GH_FIXTURE='80000'
export GITHUBPILL_MAX_SIZE_KB=100000
OUT=$(printf '%s' "$INPUT" | bash "$HOOK")
assert_contains "allow" "$OUT" "override allows up to MAX_SIZE_KB"
unset GITHUBPILL_MAX_SIZE_KB

# Case 4: non-git-clone Bash command passes through (empty JSON)
INPUT='{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
OUT=$(printf '%s' "$INPUT" | bash "$HOOK")
assert_eq "{}" "$OUT" "non-clone Bash returns empty object"

# Case 5: non-Bash tool passes through
INPUT='{"tool_name":"Read","tool_input":{"file_path":"/tmp/foo"}}'
OUT=$(printf '%s' "$INPUT" | bash "$HOOK")
assert_eq "{}" "$OUT" "non-Bash tool returns empty"

test_summary
