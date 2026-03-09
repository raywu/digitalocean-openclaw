# DEV/PROD Workspace Architecture — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update the setup guide and prompt doc to reflect a DEV/PROD workspace split where the DEV workspace is the git-tracked source of truth and workspace is the deployed production artifact.

**Architecture:** All workspace editing happens in `~/.openclaw-dev/workspace/` (git repo, Claude Code root). A `promote.sh` script rsyncs committed changes to `~/.openclaw/workspace/` (PROD). A separate DEV state directory (`~/.openclaw-dev/`) with its own `openclaw.json` enables temporary DEV Gateway on port 18790 with no channels for CRON/sandbox testing. Start DEV with `openclaw start --dev`.

**Tech Stack:** Markdown docs, bash (promote.sh)

---

### Task 1: Add DEV/PROD architecture overview to Phase 3 preamble

**Files:**
- Modify: `docs/openclaw-setup-guide.md:262-266`

**Step 1: Edit the Phase 3 preamble**

Replace lines 262-266 (the Phase 3 heading and intro) with the DEV/PROD architecture overview. Insert after the bootstrap callout (line 264) and before the placeholder values table (line 268).

New content to insert between line 264 and line 266:

```markdown
#### DEV/PROD Workspace Architecture

All workspace files are authored and version-controlled in a **development workspace** (`~/.openclaw-dev/workspace/`). The **production workspace** (`~/.openclaw/workspace/`) contains deployed artifacts synced from dev via a `promote.sh` script. Never edit production workspace files directly.

```
~/.openclaw/                           # PROD state dir
├── openclaw.json                      #   PROD config (port 18789, channels enabled)
├── .env                               #   Shared secrets
└── workspace/                         #   PRODUCTION — Gateway reads from here
    ├── SOUL.md                        #     deployed artifact, not edited directly
    ├── IDENTITY.md, AGENTS.md, TOOLS.md, USER.md
    ├── HEARTBEAT.md, BOOT.md
    ├── MEMORY.md                      #     PROD-owned (agent writes)
    ├── memory/                        #     PROD-owned
    ├── SYSTEM_LOG.md                  #     PROD-owned
    └── skills/

~/.openclaw-dev/                       # DEV state dir (--dev flag)
├── openclaw.json                      #   DEV config (port 18790, no channels)
├── .env -> ~/.openclaw/.env           #   symlink to shared secrets
└── workspace/                         #   DEV — git repo + Claude Code root
    ├── .git/
    ├── .claude/settings.json
    ├── CLAUDE.md                      #     dev-only, never promoted
    ├── SOUL.md                        #     source of truth — edit here
    ├── IDENTITY.md, AGENTS.md, TOOLS.md, USER.md
    ├── HEARTBEAT.md, BOOT.md
    ├── skills/
    ├── tests/
    └── scripts/
        └── promote.sh                 #     rsync dev → prod
```

> **PROD-owned files** (MEMORY.md, `memory/`, SYSTEM_LOG.md) are never overwritten by promote — they contain live agent state. CLAUDE.md is dev-only (Claude Code never runs in the PROD workspace).
```

And change line 266 from:

```markdown
Instead of one monolithic prompt, distribute configuration across OpenClaw's purpose-built workspace files in `~/.openclaw/workspace/`:
```

to:

```markdown
Instead of one monolithic prompt, distribute configuration across OpenClaw's purpose-built workspace files. Create all files in `~/.openclaw-dev/workspace/` — the dev workspace is the source of truth:
```

**Step 2: Verify edit**

Read lines 262-300 and confirm the architecture diagram is present and the workspace path reference now says `~/.openclaw-dev/workspace/`.

**Step 3: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Add DEV/PROD workspace architecture to Phase 3 preamble"
```

---

### Task 2: Update Phase 3 file creation paths from workspace/ to DEV workspace

**Files:**
- Modify: `docs/openclaw-setup-guide.md` (lines 289-554)

**Step 1: Replace workspace paths in Phase 3 file creation instructions**

Throughout Phase 3 (lines 289-554), change all `~/.openclaw/workspace/` paths to `~/.openclaw-dev/workspace/` in file creation instructions. Specifically:

- Line 266 area: already handled in Task 1
- All `Create ~/.openclaw/workspace/SOUL.md` → `Create ~/.openclaw-dev/workspace/SOUL.md`
- All `Create ~/.openclaw/workspace/IDENTITY.md` → `Create ~/.openclaw-dev/workspace/IDENTITY.md`
- All `Create ~/.openclaw/workspace/AGENTS.md` → `Create ~/.openclaw-dev/workspace/AGENTS.md`
- All `Create ~/.openclaw/workspace/TOOLS.md` → `Create ~/.openclaw-dev/workspace/TOOLS.md`
- All `Create ~/.openclaw/workspace/USER.md` → `Create ~/.openclaw-dev/workspace/USER.md`
- All `Create ~/.openclaw/workspace/HEARTBEAT.md` → `Create ~/.openclaw-dev/workspace/HEARTBEAT.md`
- All `Create ~/.openclaw/workspace/BOOT.md` → `Create ~/.openclaw-dev/workspace/BOOT.md`
- All `Create ~/.openclaw/workspace/SYSTEM_LOG.md` → `Create ~/.openclaw-dev/workspace/SYSTEM_LOG.md`

**Important:** Do NOT change paths inside file content (e.g., inside SOUL.md's text that references `~/.openclaw/workspace/SYSTEM_LOG.md` as a runtime path — that's the PROD path the agent actually uses). Only change the "Create this file at..." instructions.

Also do NOT change `~/.openclaw/workspace` in `openclaw.json` config blocks — that's the PROD workspace path the Gateway uses.

**Step 2: Verify edit**

Grep for remaining `Create ~/.openclaw/workspace/` (without `openclaw-dev`) to confirm none are left in Phase 3.

```bash
grep -n "Create.*~/.openclaw/workspace/" docs/openclaw-setup-guide.md | grep -v openclaw-dev
```

Expected: only hits in openclaw.json config blocks or runtime path references, not file creation instructions.

**Step 3: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Update Phase 3 file creation paths to DEV workspace"
```

---

### Task 3: Update Phase 3.13 (Claude Code config) for DEV workspace

**Files:**
- Modify: `docs/openclaw-setup-guide.md:944-995`

**Step 1: Update Claude Code section**

Change the section to reflect that Claude Code runs from `~/.openclaw-dev/workspace/`:

1. Line 946: Change "Configure its permission rules for the OpenClaw workspace" → "Configure its permission rules for the development workspace"

2. Line 948: Change `Create ~/.openclaw/workspace/.claude/settings.json` → `Create ~/.openclaw-dev/workspace/.claude/settings.json`

3. Line 974: Change `Create ~/.openclaw/workspace/CLAUDE.md` → `Create ~/.openclaw-dev/workspace/CLAUDE.md`

4. Line 995: Change the tip from:
   ```
   > **Claude Code users:** To use Claude Code for skill development, `tmux attach -t claude-code`, then `cd ~/.openclaw/workspace && claude`.
   ```
   to:
   ```
   > **Claude Code users:** To use Claude Code for skill development, `tmux attach -t claude-code`, then `cd ~/.openclaw-dev/workspace && claude`. Claude Code reads `CLAUDE.md` automatically for project context. Use `./scripts/promote.sh` to deploy changes to production.
   ```

**Step 2: Verify edit**

Read lines 944-996 and confirm all paths point to `~/.openclaw-dev/workspace/`.

**Step 3: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Update Phase 3.13 Claude Code config for DEV workspace"
```

---

### Task 4: Add new step for DEV workspace git init and promote.sh

**Files:**
- Modify: `docs/openclaw-setup-guide.md` (insert after line 995, before Phase 4)

**Step 1: Insert new section 3.14**

Insert a new section between 3.13 and Phase 4 (before line 997 `---`):

```markdown
**3.14 — Initialize DEV Workspace as a Git Repository**

```bash
cd ~/.openclaw-dev/workspace
git init
git add -A
git commit -m "Initial DEV workspace setup"
```

Create the test and scripts directories:

```bash
mkdir -p ~/.openclaw-dev/workspace/tests
mkdir -p ~/.openclaw-dev/workspace/scripts
```

Create `~/.openclaw-dev/workspace/scripts/promote.sh`:
```bash
#!/bin/bash
set -euo pipefail

DEV="$HOME/.openclaw-dev/workspace"
PROD="$HOME/.openclaw/workspace"

# Refuse if uncommitted changes exist
if ! git -C "$DEV" diff --quiet || ! git -C "$DEV" diff --cached --quiet; then
  echo "ERROR: DEV workspace has uncommitted changes. Commit first."
  exit 1
fi

# Files to sync
SYNC_FILES=(
  SOUL.md
  IDENTITY.md
  AGENTS.md
  TOOLS.md
  USER.md
  HEARTBEAT.md
  BOOT.md
)

echo "=== Promote: DEV → PROD ==="
echo ""

# Diff preview
CHANGES=0
for f in "${SYNC_FILES[@]}"; do
  if [ -f "$DEV/$f" ]; then
    if [ ! -f "$PROD/$f" ] || ! diff -q "$DEV/$f" "$PROD/$f" > /dev/null 2>&1; then
      echo "--- CHANGED: $f ---"
      diff -u "$PROD/$f" "$DEV/$f" 2>/dev/null || echo "  (new file)"
      echo ""
      CHANGES=1
    fi
  fi
done

# Skills diff (directory-level)
if [ -d "$DEV/skills" ]; then
  diff -rq "$DEV/skills" "$PROD/skills" 2>/dev/null | while read -r line; do
    echo "  $line"
    CHANGES=1
  done
fi

if [ "$CHANGES" -eq 0 ]; then
  echo "No changes to promote."
  exit 0
fi

echo ""
read -rp "Promote these changes to production? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

# Sync workspace files
for f in "${SYNC_FILES[@]}"; do
  if [ -f "$DEV/$f" ]; then
    cp "$DEV/$f" "$PROD/$f"
  fi
done

# Sync skills directory
rsync -a --delete "$DEV/skills/" "$PROD/skills/"

echo "Promoted to production. Changes take effect on next agent turn (hot-reload)."
```

```bash
chmod +x ~/.openclaw-dev/workspace/scripts/promote.sh
```

> **What promote.sh does:** Checks for uncommitted changes (refuses if any), shows a diff of what would change in the production workspace, asks for confirmation, then copies workspace files and skills. PROD-owned files (MEMORY.md, `memory/`, SYSTEM_LOG.md) are never touched. The Gateway hot-reloads on the next message — no restart needed.
```

**Step 2: Verify edit**

Read the new section and confirm promote.sh script is complete and the section flows correctly before Phase 4.

**Step 3: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Add Phase 3.14: DEV workspace git init and promote.sh"
```

---

### Task 5: Add DEV state directory config to Phase 3b

**Files:**
- Modify: `docs/openclaw-setup-guide.md` (insert after the openclaw.json section, around line 760)

**Step 1: Find the right insertion point**

Look for the end of the openclaw.json config block in Phase 3b. Insert the new section after the security verification commands but within Phase 3b, before Phase 3.9 (.env file).

**Step 2: Insert DEV config section**

```markdown
**3.8b — Create the DEV State Directory**

Create the DEV state directory and config:

```bash
mkdir -p ~/.openclaw-dev/workspace
cp ~/.openclaw/openclaw.json ~/.openclaw-dev/openclaw.json
ln -s ~/.openclaw/.env ~/.openclaw-dev/.env
```

Edit `~/.openclaw-dev/openclaw.json` — change these three settings:

1. **Workspace path:** `"workspace": "~/.openclaw-dev/workspace"`
2. **Gateway port:** `"port": 18790`
3. **Remove all channel config:** Delete the entire `channels` and `plugins` sections (Telegram, WhatsApp)

> **Why a separate state dir?** DEV needs a temporary Gateway for testing CRON jobs and sandbox behavior. Using a different port (18790) prevents conflicts with the always-on PROD Gateway, and removing channels prevents DEV from accidentally responding to real users. Start DEV with: `openclaw start --dev`. Stop when done testing.
>
> **SSH tunnel for DEV dashboard:** `ssh -L 18790:localhost:18790 clawuser@YOUR_DROPLET_IP` → open `http://localhost:18790`.
```

**Step 3: Verify edit**

Read the section and confirm it fits within Phase 3b.

**Step 4: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Add DEV state directory config to Phase 3b"
```

---

### Task 6: Update Phase 4 skill creation paths to DEV workspace

**Files:**
- Modify: `docs/openclaw-setup-guide.md:999-1143`

**Step 1: Update skill paths**

Change all skill creation paths from `~/.openclaw/workspace/skills/` to `~/.openclaw-dev/workspace/skills/`:

- Line 1001: `Create custom skills in ~/.openclaw/workspace/skills/` → `~/.openclaw-dev/workspace/skills/`
- Line 1028: `mkdir -p ~/.openclaw/workspace/skills/daily-greeting` → `~/.openclaw-dev/workspace/skills/daily-greeting`
- Line 1031: `Create ~/.openclaw/workspace/skills/daily-greeting/SKILL.md` → `~/.openclaw-dev/workspace/skills/daily-greeting/SKILL.md`
- All other `mkdir` and `Create` lines for skills in this section

Add a note after the skill creation:

```markdown
> **Deploy skills to production:** After creating and testing skills, commit them in the DEV workspace and run `./scripts/promote.sh` to sync to the production workspace.
```

**Step 2: Verify edit**

```bash
grep -n "workspace/skills" docs/openclaw-setup-guide.md | grep -v openclaw-dev | grep -v "openclaw.json"
```

Expected: no hits in Phase 4 file creation instructions.

**Step 3: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Update Phase 4 skill creation paths to DEV workspace"
```

---

### Task 7: Update Phase 5 backup to back up DEV workspace

**Files:**
- Modify: `docs/openclaw-setup-guide.md:1147-1210`

**Step 1: Update backup paths**

The backup infrastructure in Phase 5 currently backs up `~/.openclaw/workspace/`. Since the DEV workspace is now the git-tracked source of truth, update:

- Line 1156: `cd ~/.openclaw/workspace` → `cd ~/.openclaw-dev/workspace`
- Line 1184-1189: The git init section — the DEV workspace is already a git repo (from 3.14), so change this to add the remote:

```markdown
Add the backup remote to the DEV workspace (already initialized as a git repo in Phase 3.14):
```bash
cd ~/.openclaw-dev/workspace
git remote add origin git@github-backup:[BACKUP_REPO].git
```
```

- Line 1191: `.gitignore` should be in the DEV workspace. Update path.

Also add a note that PROD workspace state (MEMORY.md, memory/, SYSTEM_LOG.md) should be backed up separately — either via a second backup script or by copying PROD-owned files into the backup.

**Step 2: Verify edit**

Read the updated Phase 5 section.

**Step 3: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Update Phase 5 backup infrastructure for DEV workspace"
```

---

### Task 8: Update Phase 7 skill editing workflow

**Files:**
- Modify: `docs/openclaw-setup-guide.md:1513-1528`

**Step 1: Replace the skill editing workflow**

Replace the current workflow (lines 1513-1528) with the DEV/PROD workflow:

```markdown
**Skill Editing Workflow (when needs change):**

When you need to update skills — new data schemas, changed workflows, seasonal adjustments — follow this workflow:

1. SSH into the Droplet and attach to Claude Code: `tmux attach -t claude-code`
2. Navigate to dev workspace: `cd ~/.openclaw-dev/workspace`
3. Edit the skill using Claude Code (`claude`) or a text editor:
   - Existing skill: modify `skills/<skill-name>/SKILL.md`
   - New skill: `mkdir -p skills/<new-skill>` → create `SKILL.md` with YAML frontmatter (see Phase 4 examples)
4. (Optional) Test with DEV Gateway: `openclaw start --dev` — send test messages via the DEV dashboard (`http://localhost:18790` via SSH tunnel). Stop when done.
5. Commit: `git add -A && git commit -m "skill update: [description]"`
6. Promote to production: `./scripts/promote.sh` — review the diff, confirm deployment.
7. Verify: send a test message via WhatsApp group or Telegram DM. The PROD Gateway hot-reloads on next turn.
8. If the change breaks something: `./scripts/promote.sh` after reverting in dev (`git checkout HEAD~1 -- skills/<skill-name>/SKILL.md && git commit -m "revert: [reason]"`)
9. Push to backup: `git push`
```

**Step 2: Verify edit**

Read the updated workflow.

**Step 3: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Update Phase 7 skill editing workflow for DEV/PROD"
```

---

### Task 9: Update Quick Reference table

**Files:**
- Modify: `docs/openclaw-setup-guide.md:1562-1618`

**Step 1: Update relevant rows in the Quick Reference table**

Change these rows:

| Old | New |
|-----|-----|
| `~/.openclaw/workspace/.claude/settings.json` | `~/.openclaw-dev/workspace/.claude/settings.json` |
| `~/.openclaw/workspace/CLAUDE.md` | `~/.openclaw-dev/workspace/CLAUDE.md` |

Add new rows:

| Concern | File / Config | Layer | Why |
|---------|---------------|-------|-----|
| **DEV Gateway config** | **`~/.openclaw-dev/openclaw.json`** | **Execution** | **Temporary Gateway on port 18790, no channels, `--dev` flag** |
| **DEV → PROD promotion** | **`~/.openclaw-dev/workspace/scripts/promote.sh`** | **Workflow** | **Git-aware rsync with diff preview and confirmation** |
| **Workspace source of truth** | **`~/.openclaw-dev/workspace/`** | **Workflow** | **Git repo — all edits happen here, promoted to workspace/** |

**Step 2: Verify edit**

Read the Quick Reference table.

**Step 3: Commit**

```bash
git add docs/openclaw-setup-guide.md
git commit -m "Update Quick Reference table for DEV/PROD architecture"
```

---

### Task 10: Update the prompt doc (prompt-claude-code-openclaw-setup.md)

**Files:**
- Modify: `docs/prompt-claude-code-openclaw-setup.md`

**Step 1: Read the full prompt doc**

Read the complete file to understand all workspace path references.

**Step 2: Update workspace paths in the prompt**

Apply the same pattern as the setup guide:
- File creation instructions: `~/.openclaw/workspace/` → `~/.openclaw-dev/workspace/`
- Runtime paths inside file content (e.g., SOUL.md referencing SYSTEM_LOG.md): keep as `~/.openclaw/workspace/`
- openclaw.json workspace config: keep as `~/.openclaw/workspace/`
- Add the DEV/PROD architecture note and promote.sh creation to the prompt
- Add DEV state directory (`~/.openclaw-dev/`) creation step

**Step 3: Verify edit**

```bash
grep -n "workspace/" docs/prompt-claude-code-openclaw-setup.md | head -30
```

Confirm file creation paths use `~/.openclaw-dev/workspace/`, runtime paths use `~/.openclaw/workspace/`.

**Step 4: Commit**

```bash
git add docs/prompt-claude-code-openclaw-setup.md
git commit -m "Update prompt doc for DEV/PROD workspace architecture"
```

---

### Task 11: Update CLAUDE.md project instructions

**Files:**
- Modify: `CLAUDE.md` (project root)

**Step 1: Add DEV/PROD architecture note**

Add to the "Key Config Patterns" or "Key Concepts" section:

```markdown
- **DEV/PROD split**: `~/.openclaw-dev/` is the isolated DEV state dir (`--dev` flag); `~/.openclaw/` is PROD. DEV workspace (`~/.openclaw-dev/workspace/`) is the git repo and Claude Code root. `promote.sh` syncs dev → prod with git-aware safety checks.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Add DEV/PROD workspace note to CLAUDE.md"
```

---

### Task 12: Final review pass

**Step 1: Search for stale workspace references**

```bash
grep -rn "cd ~/.openclaw/workspace\b" docs/
grep -rn "~/.openclaw/workspace/" docs/ | grep -v openclaw-dev | grep -v "\.json" | head -30
```

Review each hit — should only be runtime paths (inside file content the agent reads at runtime) or openclaw.json config. Any file creation instruction should say `~/.openclaw-dev/workspace/`.

**Step 2: Read key sections end-to-end**

Read Phase 3 preamble, 3.13, 3.14, Phase 4 intro, Phase 5 backup, Phase 7 skill workflow, and Quick Reference. Confirm coherent narrative.

**Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "Final review fixes for DEV/PROD workspace architecture"
```
