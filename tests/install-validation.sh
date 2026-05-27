#!/usr/bin/env bash
set -euo pipefail

# install-validation.sh
# Simulates a fresh Claude Code install check for the reporecon plugin.
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
  "skills/reporecon/SKILL.md"
  "skills/reporecon/references/query-patterns.md"
  "skills/reporecon/references/judge-rubric.md"
  "skills/reporecon/references/report-template.md"
  "skills/reporecon/references/deep-protocol.md"
  "scripts/preflight.sh"
  "scripts/gh-search.sh"
  "scripts/verify-repo.sh"
  "scripts/staleness.sh"
  "scripts/safe-clone.sh"
  "scripts/vapor-check.sh"
  "commands/reporecon.md"
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

# ---------- 2. JSON parse validation ----------
# Prefer jq (it's the canonical dep for this plugin), fall back to python3 or
# node if jq isn't installed yet on the validation host.
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
    json_check "$jf"
    rc=$?
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
SKILL_FILE="skills/reporecon/SKILL.md"
if [[ -f "$SKILL_FILE" ]]; then
  # Extract frontmatter (between first two --- lines)
  FM="$(awk '/^---$/{f++; next} f==1{print} f==2{exit}' "$SKILL_FILE")"
  for key in "name" "description" "allowed-tools"; do
    if printf '%s\n' "$FM" | grep -qE "^${key}:"; then
      ok "SKILL.md frontmatter has key: $key"
    else
      fail "SKILL.md frontmatter missing key: $key"
    fi
  done
fi

# ---------- 4. scripts/*.sh executable + shebang + set -euo pipefail ----------
shopt -s nullglob
for s in scripts/*.sh; do
  if [[ -x "$s" ]]; then
    ok "executable: $s"
  else
    fail "not executable: $s"
  fi
  first_line="$(head -n1 "$s" || true)"
  if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
    ok "shebang ok: $s"
  else
    fail "bad/missing shebang ($first_line): $s"
  fi
  if grep -qE '^set -euo pipefail' "$s"; then
    ok "set -euo pipefail: $s"
  else
    fail "missing 'set -euo pipefail': $s"
  fi
done
shopt -u nullglob

# ---------- 5. SKILL.md references each helper script ----------
HELPER_SCRIPTS=(preflight.sh gh-search.sh verify-repo.sh staleness.sh safe-clone.sh vapor-check.sh)
if [[ -f "$SKILL_FILE" ]]; then
  for hs in "${HELPER_SCRIPTS[@]}"; do
    if grep -q "$hs" "$SKILL_FILE"; then
      ok "SKILL.md references script: $hs"
    else
      fail "SKILL.md does not reference script: $hs"
    fi
  done
fi

# ---------- 6. SKILL.md references each references/*.md ----------
REFERENCE_MDS=(query-patterns.md judge-rubric.md report-template.md deep-protocol.md)
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
