# DEV/PROD Workspace Architecture

## Problem

All workspace editing happens directly in the live `~/.openclaw/workspace/` directory. No staging, no version control, no way to test CRON/sandbox changes before they hit production.

## Architecture

```
~/.openclaw/
├── openclaw.json              # PROD config (port 18789, channels enabled)
├── openclaw-dev.json          # DEV config (port 18790, no channels)
├── .env                       # Shared secrets
├── workspace/                 # PRODUCTION — Gateway reads from here
│   ├── SOUL.md                #   deployed artifact, not edited directly
│   ├── IDENTITY.md
│   ├── AGENTS.md
│   ├── TOOLS.md
│   ├── USER.md
│   ├── HEARTBEAT.md
│   ├── BOOT.md
│   ├── MEMORY.md              #   PROD-owned (agent writes)
│   ├── memory/                #   PROD-owned
│   ├── SYSTEM_LOG.md          #   PROD-owned
│   └── skills/
└── workspace-dev/             # DEV — git repo + Claude Code root
    ├── .git/
    ├── .claude/settings.json
    ├── CLAUDE.md              #   dev-only, never promoted
    ├── SOUL.md                #   source of truth — edit here
    ├── IDENTITY.md
    ├── AGENTS.md
    ├── TOOLS.md
    ├── USER.md
    ├── HEARTBEAT.md
    ├── BOOT.md
    ├── skills/
    ├── tests/
    └── scripts/
        └── promote.sh
```

## Key Decisions

### Single PROD Gateway, temporary DEV Gateway

- PROD Gateway runs always, pointing at `workspace/` on port 18789 with channels enabled.
- DEV Gateway started on-demand for CRON/sandbox testing via `openclaw start --config ~/.openclaw/openclaw-dev.json`, then stopped when done.

### Two config files

| | `openclaw.json` (PROD) | `openclaw-dev.json` (DEV) |
|---|---|---|
| workspace | `~/.openclaw/workspace` | `~/.openclaw/workspace-dev` |
| port | 18789 | 18790 |
| channels | Telegram + WhatsApp | none |
| everything else | identical | identical |

DEV has no channels to prevent accidentally responding to real users.

### promote.sh behavior

1. Refuse to run if `workspace-dev/` has uncommitted git changes
2. Show diff of what would change in `workspace/`
3. Require y/n confirmation
4. rsync the approved files

### Sync boundary

| Synced (dev → prod) | Excluded (never synced) |
|---|---|
| SOUL.md | .git/ |
| IDENTITY.md | .claude/ |
| AGENTS.md | CLAUDE.md |
| TOOLS.md | tests/ |
| USER.md | scripts/ |
| HEARTBEAT.md | MEMORY.md |
| BOOT.md | memory/ |
| skills/ | SYSTEM_LOG.md |

PROD-owned files (MEMORY.md, memory/, SYSTEM_LOG.md) are never overwritten — they contain live agent state. CLAUDE.md is dev-only (Claude Code never runs in PROD workspace).

### No Gateway restart after promote

OpenClaw hot-reloads workspace files on next message. Since promote.sh only syncs workspace files (not openclaw.json), no restart is needed.

### Claude Code root

Operator runs Claude Code from `~/.openclaw/workspace-dev/`. The `CLAUDE.md` and `.claude/settings.json` there provide project context and permission rules for skill development.

## Workflow

```
1. ssh claw
2. tmux attach -t claude-code
3. cd ~/.openclaw/workspace-dev
4. claude                          # edit SOUL.md, skills, etc.
5. git add && git commit           # commit changes
6. ./scripts/promote.sh            # review diff, confirm, deploy
7. (optional) openclaw start --config ~/.openclaw/openclaw-dev.json  # test CRON/sandbox
```
