# OpenClaw Skill Editing & Self-Modification: Research, Assessment, and Recommendations

---

## 1. Research Summary (Sub-Agent 1)

### Q1: Can OpenClaw agents edit their own workspace files?

**Yes — depending on session type and sandbox config.** The answer depends entirely on whether the session is sandboxed and the `workspaceAccess` setting:

- **Main session (operator DM via Telegram):** `sandbox.mode: "non-main"` means the main session runs **on host**, not in a sandbox. The agent has the `write`, `edit`, and `apply_patch` tools available. With `tools.fs.workspaceOnly: true`, it can write to any file inside `~/.openclaw/workspace/`, including SOUL.md, skills, AGENTS.md, TOOLS.md, and memory files. **This is the default behavior — the main session CAN self-modify.**
- **Sandboxed sessions (WhatsApp group):** `workspaceAccess: "ro"` mounts the workspace read-only at `/agent`. The `write`, `edit`, and `apply_patch` tools are **disabled** when `workspaceAccess` is `"ro"`. Group sessions cannot modify workspace files.
- **Sandbox with `workspaceAccess: "rw"`:** The workspace is mounted read-write at `/workspace`. The agent can modify files, including skills and SOUL.md. This is the bootstrap mode some users use temporarily.

**Key finding:** OpenClaw's official docs confirm that `workspaceAccess: "ro"` explicitly disables `write/edit/apply_patch` tools. This is a hard enforcement — not soft guidance. The `gateway_config` tool (denied in our setup) is what controls `openclaw.json` modification, separate from workspace file writes.

**Confidence: HIGH** (Official docs at docs.openclaw.ai/gateway/security)

### Q2: Does OpenClaw have a built-in skill editing workflow?

**No dedicated skill editing CLI.** OpenClaw does not have a `openclaw skill edit` or `openclaw skill create` command. Skills are plain directories with SKILL.md files — you create/edit them with any text editor, Claude Code, or by asking the agent itself (if it has write access). The workflows are:

1. **Manual file editing** — SSH in, use `nano`/`vim`, or connect via VS Code Remote SSH / Cursor
2. **Claude Code** — `cd ~/.openclaw/workspace && claude` then ask it to create/modify skills
3. **Agent self-editing** — Ask the agent via Telegram DM to modify its own skill files (main session has write access)
4. **ClawHub install** — `clawhub install <slug>` for community skills

**Hot-reload is supported and enabled by default:**
- `skills.load.watch: true` (default) watches skill folders for changes
- `skills.load.watchDebounceMs: 250` (default) debounces filesystem events
- When a SKILL.md changes, the skills snapshot refreshes on the **next agent turn** (not mid-turn)
- Changes take effect **without restarting the gateway** — this is effectively hot-reload
- If the watcher is disabled, changes take effect on the **next new session**

**Confidence: HIGH** (Official docs at docs.openclaw.ai/tools/skills and skills-config.md)

### Q3: Recommended approach for evolving skills over time?

The community has converged on several patterns:

**Pattern A: "Edit externally, agent picks up automatically"** (Most common)
Use an external editor (VS Code via SSH, Cursor, Claude Code) to edit SKILL.md files. The file watcher detects changes and the agent picks them up on its next turn. This is the workflow recommended by multiple guides and community posts. Key advice: keep a git repo of your workspace so you can `git diff` and `git checkout` to revert bad edits.

**Pattern B: "Agent self-editing via main DM"** (Advanced)
Ask the agent via the trusted operator DM channel to modify its own skills. The agent uses `write`/`edit` tools to update SKILL.md files. This works because the main session runs on host (not sandboxed). Community skills like `agent-config` and `self-improving-agent` formalize this pattern with structured workflows, file-map references, and anti-bloat checks.

**Pattern C: "Agent proposes, human approves, agent writes"** (Hybrid)
No built-in approval gate exists for workspace file writes (unlike exec approvals). However, some users implement a soft approval pattern: the agent drafts changes to a staging file (e.g., `SKILL.md.proposed`), sends the diff to the operator via Telegram, and only writes the final version when the operator confirms. This is entirely prompt-driven — there's no hard enforcement mechanism.

**Rollback:** The primary rollback mechanism is git. The backup infrastructure in our Phase 5 already commits workspace files to GitHub. Reverting a bad skill edit is `git checkout <commit> -- skills/<skill-name>/SKILL.md`.

**Confidence: MEDIUM** (Community patterns, not official best practice docs)

### Q4: Human-in-the-loop vs. autonomous self-modification

**OpenClaw has NO built-in approval gate for workspace writes.** This is a critical finding:

- **Exec has approval gates** — `exec-approvals.json` with `security: "ask"` or `security: "deny"` and binary allowlists
- **Workspace writes have NO approval gates** — if the agent has the `write` tool and the path is within `workspaceOnly` scope, the write succeeds silently
- **`config.apply` and `config.patch` have rate limiting** (3 calls per 60s) but no approval gates — the agent can modify `openclaw.json` via the `gateway` tool if it's not denied
- **GitHub Issue #24237** (2 days ago) documents agents silently mutating `openclaw.json` without user consent — this is a known, active problem
- **GitHub Issue #20245** documents `config.patch` bypassing `commands.restart=false` — the agent can self-restart as a side effect of any config patch

The only hard controls for workspace writes are:
1. `sandbox.workspaceAccess: "ro"` (disables write/edit/apply_patch entirely)
2. `tools.deny: ["write", "edit", "apply_patch"]` (explicitly deny write tools)
3. `tools.fs.workspaceOnly: true` (limits scope to workspace, doesn't prevent writes within it)

**Confidence: HIGH** (Official docs + confirmed GitHub issues)

### Q5: Canvas tool — relevant to our setup?

**No.** Canvas is a visual workspace for HTML/CSS/JS rendering on macOS/iOS/Android nodes. It has nothing to do with workspace file editing. It's a separate tool (`canvas action:present`) that displays HTML content on connected nodes. Our setup already denies `canvas` in `tools.sandbox.tools.deny` and it's irrelevant on a headless Ubuntu VPS.

**Confidence: HIGH** (Official canvas docs + SKILL.md)

### Q6: OpenClaw + Claude Code workflow for skill iteration

**No official documented pattern.** However, the community workflow is:

1. SSH into the Droplet (or use the tmux session from Phase 1.7)
2. `tmux attach -t claude-code` → `cd ~/.openclaw/workspace && claude`
3. Edit skills using Claude Code — it reads `CLAUDE.md` for project context
4. Save the file — OpenClaw's skill watcher picks up the change
5. Test in the next agent turn (send a message via WhatsApp/Telegram)
6. If it breaks, `git checkout -- skills/<skill-name>/SKILL.md` to revert

The key advantage of Claude Code over agent self-editing: Claude Code is completely isolated from the running agent. A bad edit via Claude Code won't affect in-flight sessions (the change only picks up on the next agent turn). A bad edit via the agent itself could corrupt the very file the agent is currently reading.

**Confidence: MEDIUM** (Community patterns + our Phase 1.7 setup)

### Research Gaps

- No official documentation on "best practices for evolving skills over time"
- No official guidance on agent self-modification patterns (safe vs. unsafe)
- No built-in diff/preview mechanism for workspace writes
- No audit log for which tool calls modified which workspace files (session JSONL has the data but no dedicated report)

---

## 2. Current State Assessment (Sub-Agent 2)

Based on our `openclaw-setup-guide.md` and the research findings:

### Can the agent currently modify its own skills?

| Session Type | Can Modify Skills? | Why |
|---|---|---|
| **Telegram DM (operator, main)** | **YES** | Main session runs on host. `write`/`edit` tools available. `workspaceOnly: true` allows writes within `~/.openclaw/workspace/`, which includes `skills/`. |
| **WhatsApp group (customers)** | **NO** | `sandbox.mode: "non-main"` + `workspaceAccess: "ro"` = write/edit/apply_patch disabled. Hard enforcement. |
| **CRON jobs** | **DEPENDS** | CRON session target determines sandbox status. Our guide doesn't specify CRON session scoping. If `sessionTarget: "isolated"`, likely sandboxed. If targeting main, runs on host with write access. |
| **Claude Code** | **YES** | Separate process, writes directly to filesystem. OpenClaw picks up changes via skill watcher. |

**Critical finding:** The operator's Telegram DM session can currently modify SOUL.md, AGENTS.md, TOOLS.md, and all skill files. This is by design — the main session is intended for trusted operator use. But our setup guide never documents this capability or provides a workflow for it.

### Can the agent currently modify SOUL.md, AGENTS.md, TOOLS.md?

**Yes, from the main session.** These are all files within `~/.openclaw/workspace/`. The `workspaceOnly: true` setting restricts the agent to this directory but doesn't prevent writes within it. The `write` and `edit` tools are NOT in `tools.deny`.

**This means:** If the agent hallucinates or if the operator gives a poorly scoped instruction, the agent could accidentally corrupt SOUL.md, AGENTS.md, or TOOLS.md from the Telegram DM session.

### Can the operator modify skills while OpenClaw is running?

**Yes.** `skills.load.watch` defaults to `true`. The operator can:
- Edit files via SSH/nano/vim → picked up on next agent turn
- Edit files via Claude Code → picked up on next agent turn
- Ask the agent via Telegram DM to edit → write happens immediately, watcher triggers refresh

The agent does NOT need to be restarted. However, changes only affect the **next agent turn** (not the current one). If a skill is in the middle of being used in a turn, the old version runs to completion.

### What happens if a skill file is malformed?

**The agent degrades gracefully.** Based on research:
- YAML frontmatter parsing errors → the skill is **excluded** from the eligible list (silent skip)
- Missing `name` or `description` → skill is excluded
- Skill body with bad instructions → the agent may follow them incorrectly but won't crash
- The gateway does NOT crash on a malformed SKILL.md — it's a soft failure

---

## 3. Gap Analysis

### Missing from the setup guide:

| Gap | Impact | Priority |
|---|---|---|
| **No skill editing workflow documented** | Operator doesn't know how to safely iterate on skills post-deployment | 🔴 Must-have |
| **No documentation that main session has write access to workspace** | Operator may not realize the agent can self-modify via Telegram DM | 🔴 Must-have |
| **No version control integration for skill changes** | If a skill edit breaks the agent, there's no rollback path besides the nightly backup | 🟡 Important |
| **No testing workflow** | No documented way to test a skill change before it goes live to customers | 🟡 Important |
| **No protection against accidental workspace corruption from main session** | A poorly scoped Telegram instruction could corrupt SOUL.md | 🟡 Important |
| **`gateway_config` is denied but `gateway` tool is not explicitly denied at global level** | Potential gap — `gateway` tool may allow config reads (need to verify) | 🟡 Important |
| **No skill change audit trail** | No easy way to see what changed, when, and why (beyond git log from nightly backup) | 🟢 Nice-to-have |
| **CRON session sandbox scoping not documented** | CRON jobs may run with more privileges than intended | 🟡 Important |
| **`skills.load.watch` setting not in openclaw.json** | Currently using default (true), but should be explicit | 🟢 Nice-to-have |

---

## 4. Recommended Best Practice

**The recommended workflow is "Edit externally, test via operator DM, commit to git."** Keep agent self-modification disabled for the customer-facing WhatsApp group (already done via `workspaceAccess: "ro"`), and use a deliberate, version-controlled process for the operator to evolve skills:

### Step-by-Step Skill Editing Workflow

1. **SSH into the Droplet** and attach to the Claude Code tmux session: `tmux attach -t claude-code`
2. **Navigate to workspace:** `cd ~/.openclaw/workspace`
3. **Create a git checkpoint before editing:** `git add -A && git commit -m "pre-edit checkpoint: [description]"`
4. **Edit the skill** using Claude Code (`claude`) or a text editor. For new skills, create the directory + SKILL.md. For existing skills, modify the SKILL.md.
5. **OpenClaw picks up the change automatically** via the skill watcher (within 250ms). No restart needed.
6. **Test the change** by sending a test message via the WhatsApp group (for customer-facing skills) or via Telegram DM (for operator skills). Verify the agent uses the updated skill correctly.
7. **If the change breaks something:** Roll back immediately: `git checkout -- skills/<skill-name>/SKILL.md`
8. **If the change works:** Commit: `git add -A && git commit -m "skill update: [description]"` and push: `git push origin main`

### When to use agent self-editing (via Telegram DM):

Use sparingly, for minor adjustments only — e.g., "Update the order-processing skill to include the new 'Express Delivery' item category." The agent will use the `write` or `edit` tool to modify the SKILL.md. Always follow up with a git commit so the change is versioned.

**Do NOT use agent self-editing for:**
- SOUL.md changes (security boundaries)
- AGENTS.md changes (tool policies)
- TOOLS.md changes (tool usage notes)
- Creating entirely new skills (complex structure, easy to get wrong)
- Any change that touches security rules

---

## 5. Proposed Changes to Setup Guide

### Change 1: Add `skills.load.watch` to `openclaw.json`

**What:** Add explicit skill watcher config to the `openclaw.json` in Phase 3.8.

**Where:** `openclaw.json`, inside the top-level config object.

```json5
"skills": {
  "load": {
    "watch": true,
    "watchDebounceMs": 250
  }
}
```

**Why:** Making the default explicit documents the behavior and prevents surprises if OpenClaw changes the default in a future version.

**Security impact:** Neutral — this is already the default behavior.

**Priority:** Nice-to-have.

---

### Change 2: Add CRON session sandbox scoping

**What:** Add `sessionTarget: "isolated"` to the CRON config explanation and ensure CRON jobs run sandboxed.

**Where:** Phase 3.8 `openclaw.json`, CRON section, and the "Key configuration explained" notes.

```json5
"cron": {
  "enabled": true,
  "maxConcurrentRuns": 2,
  "sessionRetention": "24h",
  "defaultSessionTarget": "isolated"
}
```

**Why:** Without this, CRON jobs might inherit the main session's trust level and have write access to workspace files. `sessionTarget: "isolated"` ensures CRON jobs get their own session, which `sandbox.mode: "non-main"` will sandbox.

**Security impact:** Strengthens defense — CRON jobs run sandboxed with read-only workspace access.

**Priority:** Important.

---

### Change 3: Add "Skill Editing Workflow" section to Phase 7

**What:** Add a new subsection to Phase 7 (Ongoing Maintenance) documenting the skill editing workflow.

**Where:** After the existing weekly/monthly/quarterly tasks, before the incident response section.

```markdown
**Skill Editing Workflow:**

When business needs change (new products, updated workflows, seasonal adjustments):

1. SSH into the Droplet and attach to Claude Code: `tmux attach -t claude-code`
2. Navigate to workspace: `cd ~/.openclaw/workspace`
3. Create a checkpoint: `git add -A && git commit -m "pre-edit: [description]"`
4. Edit the skill with Claude Code or a text editor:
   - Existing skill: edit `skills/<skill-name>/SKILL.md`
   - New skill: `mkdir -p skills/<new-skill>` then create `SKILL.md` with proper YAML frontmatter
5. OpenClaw picks up changes automatically (skill watcher, ~250ms). No restart needed.
6. Test via WhatsApp group (customer skills) or Telegram DM (operator skills).
7. If broken: `git checkout -- skills/<skill-name>/SKILL.md`
8. If working: `git add -A && git commit -m "skill update: [description]" && git push`

**What the agent CAN modify from Telegram DM (main session):**
- Skills (`~/.openclaw/workspace/skills/*/SKILL.md`)
- Memory files (`~/.openclaw/workspace/memory/`)
- SYSTEM_LOG.md

**What the agent SHOULD NOT modify (edit manually via Claude Code):**
- SOUL.md (security boundaries — accidental edits could weaken defenses)
- AGENTS.md (tool policies and confirmation gates)
- TOOLS.md (tool usage notes)
- openclaw.json (denied via `gateway_config` tool block)

**What the agent CANNOT modify from WhatsApp group:**
- Any workspace file (sandbox `workspaceAccess: "ro"` — hard enforcement)
```

**Why:** The single most important gap — operators need to know how to evolve their agent's skills safely.

**Security impact:** Neutral — documents existing capabilities, doesn't change permissions.

**Priority:** Must-have.

---

### Change 4: Add SOUL.md rule against unauthorized self-modification

**What:** Add a section to SOUL.md under "Security Boundaries" that explicitly restricts when the agent may modify its own workspace files.

**Where:** Phase 3.1, SOUL.md, after the existing "Disabled Capabilities" section.

```markdown
## Self-Modification Rules
- You may ONLY modify workspace files when EXPLICITLY instructed by the operator via Telegram DM.
- NEVER modify SOUL.md, AGENTS.md, or TOOLS.md without explicit operator instruction.
- NEVER modify skills in response to customer messages (WhatsApp group sessions cannot write — but the rule exists for defense-in-depth).
- When modifying any file, ALWAYS show the proposed change to the operator and wait for confirmation before writing.
- After any workspace file modification, log the change to SYSTEM_LOG.md: what was changed, why, and who requested it.
```

**Why:** Soft guidance that biases the model against unauthorized self-modification. This complements the hard enforcement (`workspaceAccess: "ro"` for sandbox, no write tool deny for main) with explicit behavioral rules. The `self-improving-agent` and `agent-config` community skills both emphasize structured modification workflows — this brings that discipline into SOUL.md.

**Security impact:** Strengthens defense (soft guidance layer). Does not weaken any hard enforcement.

**Priority:** Must-have.

---

### Change 5: Add `write` and `edit` to the Quick Reference table

**What:** Add rows documenting that `write` and `edit` tools are available in main session but blocked in sandbox.

**Where:** Quick Reference table at end of setup guide.

```markdown
| **Workspace write (main session)** | **`write`/`edit` tools + `fs.workspaceOnly: true`** | **Execution** | **Operator DM can modify workspace files (skills, memory) — use deliberately** |
| **Workspace write (sandbox)** | **`sandbox.workspaceAccess: "ro"`** | **Execution** | **WhatsApp group CANNOT modify workspace files (hard enforcement)** |
```

**Why:** Makes the asymmetry between main and sandbox sessions explicit.

**Security impact:** Neutral — documents existing behavior.

**Priority:** Must-have.

---

### Change 6: Consider adding `write` and `edit` to `tools.deny` for maximum lockdown

**What:** Optionally deny the `write` and `edit` tools globally, forcing ALL workspace modifications to go through Claude Code.

```json5
"tools": {
  "deny": [
    "exec",
    "write", "edit", "apply_patch",  // NEW: blocks all workspace writes
    "email_send", "email_read", "email_list", "email_search",
    // ... rest of existing deny list
  ]
}
```

**Why:** This would make it **impossible** for the agent to modify any workspace file, from any session, including the main operator DM. All skill editing would go through Claude Code or manual SSH editing. This is the most secure option.

**Trade-off:** The agent can no longer write to `SYSTEM_LOG.md`, `memory/` files, or perform any file-based memory management. This may break the memory system and operational logging. The `gsheet` tool (API calls) would still work.

**Security impact:** Maximum lockdown, but may break memory/logging functionality.

**Priority:** Decision point — see below.

---

## 6. Decision Points

### Decision 1: Allow agent self-modification from main session?

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| **A. Keep current (write allowed in main)** | Agent can manage memory, log operations, and accept minor skill tweaks via Telegram DM | Operator must trust that SOUL.md rules prevent unauthorized modification; a sophisticated prompt injection via Telegram DM could modify SOUL.md | **Recommended for most users** — add SOUL.md rules (Change 4) as soft guardrail |
| **B. Deny write/edit globally** | Maximum security; all modifications via Claude Code only | Breaks memory system, operational logging, and any file-based workflows | Only for extremely high-security deployments |
| **C. Deny write/edit in sandbox only (current) + add confirmation skill** | Agent proposes changes, operator confirms via Telegram before write executes | No built-in confirmation mechanism for writes; would need a custom skill | Future consideration — depends on OpenClaw adding write approval gates |

### Decision 2: Git commit frequency for workspace changes

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| **A. Manual commits only** | Operator controls exactly what gets committed | Agent-made changes (memory updates) may be lost if server crashes between nightly backups | Good enough for most setups |
| **B. CRON-driven git commit every hour** | Catches memory updates and any agent-made changes frequently | More git history noise; CRON job needs write access to run `git add` | **Recommended** — add a CRON job: `cd ~/.openclaw/workspace && git add -A && git diff --cached --quiet \|\| git commit -m "auto: $(date +%Y-%m-%d-%H%M)"` |
| **C. File-watcher-driven commit** | Immediate versioning of every change | Complex setup; noisy git history; inotifywait dependency | Over-engineered for this use case |

### Decision 3: Enable the `self-improving-agent` or `agent-config` community skill?

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| **A. Don't install** | Simpler setup; fewer moving parts; no risk of unaudited skill code | Operator must manually identify and implement improvements | **Recommended for initial deployment** |
| **B. Install `agent-config`** | Structured workflow for agent to propose/execute workspace file changes; file-map prevents wrong-file edits | Third-party code in the agent's trust boundary; requires audit; adds token overhead | Consider after 30 days of operation, once the operator understands the skill editing workflow |
| **C. Install `self-improving-agent`** | Automatic learning capture; promotes recurring patterns to workspace files | More autonomous than most operators want; writes to `.learnings/` directory continuously | Future consideration only |
