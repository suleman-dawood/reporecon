#!/usr/bin/env bash
set -euo pipefail

# install-validation.sh
# Simulates a fresh Claude Code install check for the githubpill plugin.
# Run from repo root. Exits 0 if all structural checks pass; 1 otherwise.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FAIL=0
fail() { echo "FAIL: $*" >&2; FAIL=1; }
ok()   { echo "ok:   $*"; }

# ---------- 1. Required directory structure ----------
REQUIRED_FILES=(
  ".claude-plugin/plugin.json"
  ".claude-plugin/marketplace.json"
  "package.json"
  "skills/githubpill/SKILL.md"
  "skills/githubpill/references/query-patterns.md"
  "skills/githubpill/references/judge-rubric.md"
  "skills/githubpill/references/report-template.md"
  "skills/githubpill/references/deep-search-protocol.md"
  "hooks/safe-clone-guard.sh"
  "LICENSE"
  "README.md"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    ok "exists: $f"
  else
    fail "missing required file: $f"
  fi
done

# scripts/ directory must NOT exist — logic moved into SKILL.md + hook.
if [[ -d "scripts" ]]; then
  fail "scripts/ directory should not exist; logic lives in SKILL.md + hooks/"
else
  ok "absent: scripts/ (expected)"
fi

# ---------- 2. JSON parse validation ----------
# Prefer jq (canonical dep), fall back to python3 or node if jq is missing.
json_check() {
  local f="$1"
  if command -v jq >/dev/null 2>&1; then
    jq . "$f" >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" >/dev/null 2>&1
  elif command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$f" >/dev/null 2>&1
  else
    return 2
  fi
}

for jf in ".claude-plugin/plugin.json" ".claude-plugin/marketplace.json" "package.json"; do
  if [[ -f "$jf" ]]; then
    set +e
    json_check "$jf"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      ok "valid JSON: $jf"
    elif [[ "$rc" -eq 2 ]]; then
      fail "no JSON validator available (install jq, python3, or node)"
      break
    else
      fail "invalid JSON: $jf"
    fi
  fi
done

# ---------- 3. SKILL.md frontmatter required keys ----------
SKILL_FILE="skills/githubpill/SKILL.md"
if [[ -f "$SKILL_FILE" ]]; then
  FM="$(awk '/^---$/{f++; next} f==1{print} f==2{exit}' "$SKILL_FILE")"
  for key in "name" "description" "allowed-tools"; do
    if printf '%s\n' "$FM" | grep -qE "^${key}:"; then
      ok "SKILL.md frontmatter has key: $key"
    else
      fail "SKILL.md frontmatter missing key: $key"
    fi
  done
fi

# ---------- 4. hooks/safe-clone-guard.sh sanity ----------
HOOK="hooks/safe-clone-guard.sh"
if [[ -f "$HOOK" ]]; then
  if [[ -x "$HOOK" ]]; then
    ok "executable: $HOOK"
  else
    fail "not executable: $HOOK"
  fi
  first_line="$(head -n1 "$HOOK" || true)"
  if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
    ok "shebang ok: $HOOK"
  else
    fail "bad/missing shebang ($first_line): $HOOK"
  fi
  if grep -qE '^set -euo pipefail' "$HOOK"; then
    ok "set -euo pipefail: $HOOK"
  else
    fail "missing 'set -euo pipefail': $HOOK"
  fi
fi

# ---------- 5. plugin.json registers the PreToolUse:Bash hook ----------
if command -v jq >/dev/null 2>&1; then
  HOOK_CMD=$(jq -r '.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command // empty' .claude-plugin/plugin.json 2>/dev/null || true)
  if [[ -n "$HOOK_CMD" ]] && printf '%s' "$HOOK_CMD" | grep -q 'safe-clone-guard.sh'; then
    ok "plugin.json registers safe-clone-guard hook on PreToolUse:Bash"
  else
    fail "plugin.json does not register hooks/safe-clone-guard.sh on PreToolUse:Bash"
  fi
fi

# ---------- 6. SKILL.md references each references/*.md ----------
REFERENCE_MDS=(query-patterns.md judge-rubric.md report-template.md deep-search-protocol.md)
if [[ -f "$SKILL_FILE" ]]; then
  for rm in "${REFERENCE_MDS[@]}"; do
    if grep -q "$rm" "$SKILL_FILE"; then
      ok "SKILL.md references reference doc: $rm"
    else
      fail "SKILL.md does not reference reference doc: $rm"
    fi
  done
fi

# ---------- Result ----------
if [[ "$FAIL" -ne 0 ]]; then
  echo ""
  echo "install-validation: FAILED" >&2
  exit 1
fi
echo ""
echo "install-validation: PASSED"
exit 0
