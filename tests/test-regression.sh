#!/bin/bash
set -euo pipefail

# OpenClaw Regression Test Suite
# Tests config, workspace, skills, scripts, SSH & git integrity

PASS=0
FAIL=0
TOTAL=0

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }

assert() {
  local desc="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    green "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    red "  FAIL: $desc"
  fi
}

assert_not() {
  local desc="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    red "  FAIL: $desc"
  else
    PASS=$((PASS + 1))
    green "  PASS: $desc"
  fi
}

OC="$HOME/.openclaw"
WS="$OC/workspace"
SCRIPTS="$HOME/scripts"

# ============================================================
bold "=== Config Validity ==="
# ============================================================

assert "openclaw.json is valid JSON" \
  python3 -c "import json; json.load(open('$OC/openclaw.json'))"

assert "gateway.mode == local" \
  python3 -c "import json; d=json.load(open('$OC/openclaw.json')); assert d['gateway']['mode']=='local'"

assert "tools.exec.host == gateway" \
  python3 -c "import json; d=json.load(open('$OC/openclaw.json')); assert d['tools']['exec']['host']=='gateway'"

assert "crossContext.allowAcrossProviders == true" \
  python3 -c "import json; d=json.load(open('$OC/openclaw.json')); assert d['tools']['message']['crossContext']['allowAcrossProviders']==True"

assert "whatsapp groupPolicy == disabled" \
  python3 -c "import json; d=json.load(open('$OC/openclaw.json')); assert d['channels']['whatsapp']['groupPolicy']=='disabled'"

assert "agent id 'main' exists" \
  python3 -c "import json; d=json.load(open('$OC/openclaw.json')); assert any(a['id']=='main' for a in d['agents']['list'])"

assert "exec-approvals.json is valid JSON" \
  python3 -c "import json; json.load(open('$OC/exec-approvals.json'))"

assert "exec-approvals defaults.security == allowlist" \
  python3 -c "import json; d=json.load(open('$OC/exec-approvals.json')); assert d['defaults']['security']=='allowlist'"

assert "exec-approvals has 5 allowlist entries" \
  python3 -c "import json; d=json.load(open('$OC/exec-approvals.json')); assert len(d['agents']['main']['allowlist'])==5, f'got {len(d[\"agents\"][\"main\"][\"allowlist\"])}'"

assert "all allowlist patterns are absolute paths" \
  python3 -c "
import json
d=json.load(open('$OC/exec-approvals.json'))
for e in d['agents']['main']['allowlist']:
    assert e['pattern'].startswith('/'), f'not absolute: {e[\"pattern\"]}'
"

assert ".env exists" \
  test -f "$OC/.env"

assert ".env permissions are 600" \
  test "$(stat -c '%a' "$OC/.env")" = "600"

REQUIRED_KEYS="GOOGLE_API_KEY ANTHROPIC_API_KEY TELEGRAM_BOT_TOKEN GATEWAY_AUTH_TOKEN EXEC_APPROVALS_SOCKET_TOKEN GOG_ACCOUNT GOG_KEYRING_PASSWORD"
for key in $REQUIRED_KEYS; do
  assert ".env has $key" \
    grep -q "^${key}=" "$OC/.env"
done

# ============================================================
bold "=== Workspace Markdown ==="
# ============================================================

for f in SOUL.md AGENTS.md TOOLS.md IDENTITY.md USER.md HEARTBEAT.md; do
  assert "$f exists" test -f "$WS/$f"
done

assert "SOUL.md has 'Core Purpose' heading" \
  grep -q "^## Core Purpose" "$WS/SOUL.md"

assert "SOUL.md has 'Security & Constraints' heading" \
  grep -q "^## Security & Constraints" "$WS/SOUL.md"

assert "AGENTS.md has 'Tool Access' heading" \
  grep -q "^## Tool Access" "$WS/AGENTS.md"

assert "TOOLS.md has 'Available Tools' heading" \
  grep -q "^## Available Tools" "$WS/TOOLS.md"

# Google Sheets IDs consistency: Orders sheet ID appears in both SOUL.md and AGENTS.md
ORDERS_ID="10Nr4psWeqBTRxMOgTyFNcGz9C3zJ9hRlmyPybRKVIhY"
assert "Orders sheet ID in SOUL.md" \
  grep -q "$ORDERS_ID" "$WS/SOUL.md"
assert "Orders sheet ID in AGENTS.md" \
  grep -q "$ORDERS_ID" "$WS/AGENTS.md"

# ============================================================
bold "=== Skills ==="
# ============================================================

SKILLS="backup customer-lookup daily-summary order-amendment order-checkout payment-confirmation weekly-order-blast weekly-report"
for skill in $SKILLS; do
  SKILL_DIR="$WS/skills/$skill"
  SKILL_FILE="$SKILL_DIR/SKILL.md"

  assert "skill dir $skill exists" test -d "$SKILL_DIR"
  assert "skill $skill has SKILL.md" test -f "$SKILL_FILE"

  assert "skill $skill has YAML frontmatter" \
    python3 -c "
lines = open('$SKILL_FILE').readlines()
assert lines[0].strip() == '---', 'no opening ---'
close_idx = None
for i, l in enumerate(lines[1:], 1):
    if l.strip() == '---':
        close_idx = i
        break
assert close_idx is not None, 'no closing ---'
"

  assert "skill $skill name matches directory" \
    python3 -c "
lines = open('$SKILL_FILE').readlines()
for l in lines[1:]:
    if l.strip() == '---': break
    if l.startswith('name:'):
        assert l.split(':', 1)[1].strip() == '$skill', f'name mismatch: {l.strip()}'
        break
"

  assert "skill $skill has bins declared" \
    grep -q "bins:" "$SKILL_FILE"
done

assert "zero gsheet references in skills" \
  python3 -c "
import os, sys
hits = []
for skill in '$SKILLS'.split():
    path = '$WS/skills/' + skill + '/SKILL.md'
    content = open(path).read()
    if 'gsheet' in content.lower():
        hits.append(skill)
assert not hits, f'gsheet found in: {hits}'
"

# ============================================================
bold "=== Scripts ==="
# ============================================================

SCRIPT_FILES="safe-git.sh daily_backup.sh hourly_checkpoint.sh"
for script in $SCRIPT_FILES; do
  SPATH="$SCRIPTS/$script"
  assert "script $script exists" test -f "$SPATH"
  assert "script $script is executable" test -x "$SPATH"
  assert "script $script has bash shebang" \
    bash -c "head -1 '$SPATH' | grep -q '^#!/bin/bash'"
  assert "script $script has set -euo pipefail" \
    grep -q "^set -euo pipefail" "$SPATH"
done

assert "safe-git.sh allows add|commit|push|status|log|diff|rev-parse|show" \
  grep -q 'add|commit|push|status|log|diff|rev-parse|show' "$SCRIPTS/safe-git.sh"

assert_not "safe-git.sh does NOT allow remote" \
  bash -c "grep 'ALLOWED_COMMANDS=' '$SCRIPTS/safe-git.sh' | grep -qE '\bremote\b'"

assert_not "safe-git.sh blocks 'remote -v' (exits non-zero)" \
  "$SCRIPTS/safe-git.sh" remote -v

# ============================================================
bold "=== SSH & Git ==="
# ============================================================

assert "openclaw deploy key exists" \
  test -f "$HOME/.ssh/openclaw_deploy_key"

assert "backup deploy key exists" \
  test -f "$HOME/.ssh/backup_deploy_key"

assert "openclaw deploy key permissions 600" \
  test "$(stat -c '%a' "$HOME/.ssh/openclaw_deploy_key")" = "600"

assert "backup deploy key permissions 600" \
  test "$(stat -c '%a' "$HOME/.ssh/backup_deploy_key")" = "600"

assert "SSH config has github-openclaw host" \
  grep -q "^Host github-openclaw" "$HOME/.ssh/config"

assert "SSH config has github-backup host" \
  grep -q "^Host github-backup" "$HOME/.ssh/config"

assert "SSH config uses IdentitiesOnly yes" \
  python3 -c "
content = open('$HOME/.ssh/config').read()
blocks = content.split('Host ')
for b in blocks[1:]:
    assert 'IdentitiesOnly yes' in b, f'missing IdentitiesOnly in: {b.splitlines()[0]}'
"

assert "workspace repo branch is main" \
  test "$(cd "$WS" && git branch --show-current)" = "main"

assert "workspace repo remote points to asianova-bot" \
  bash -c "cd '$WS' && git remote -v | grep -q 'asianova-bot'"

# ============================================================
# Summary
# ============================================================
echo
bold "=== Results ==="
echo "Total: $TOTAL  |  $(green "Pass: $PASS")  |  $(red "Fail: $FAIL")"

if [[ $FAIL -gt 0 ]]; then
  echo
  red "REGRESSION FAILURES DETECTED"
  exit 1
else
  echo
  green "ALL TESTS PASSED"
  exit 0
fi
