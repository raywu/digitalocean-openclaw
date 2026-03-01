# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a documentation repository for a **live deployed** OpenClaw instance (open-source, self-hosted AI agent framework) running on DigitalOcean infrastructure. Docs reflect the actual production configuration after security audit (2026-02-27) and order lifecycle fix (2026-02-28). There is no application code, build system, or test suite.

### Document Structure (`doc/`)

- **`openclaw-setup-guide.md`** — Production deployment walkthrough for Ubuntu 24.04 on DigitalOcean
- **`prompt-claude-code-openclaw-setup.md`** — Interactive Claude Code prompt for guided setup
- **`prompt-multi-agent-openclaw-setup.md`** — Multi-agent orchestration prompt
- **`reference-openclaw-digitalocean-setup-evaluation.md`** — Architecture evaluation: seven-layer architecture with dual specialization/security analysis
- **`reference-openclaw-order-crm-tools-skills.md`** — Order/CRM skill reference
- **`reference-openclaw-shopify-gmail-research-report.md`** — Shopify/Gmail integration research
- **`reference-openclaw-skill-editing-report.md`** — Skill editing patterns
- **`reference-whatsapp-injection-defense-analysis.md`** — WhatsApp injection defense analysis

## Deployed Skills

13 skills in `~/.openclaw/workspace/skills/`:

| Skill | Description |
|-------|-------------|
| `order-checkout` | CRON-triggered batch checkout, sends DMs with Venmo links |
| `payment-confirmation` | Receives screenshots in WhatsApp DM, delegates to main via `sessions_send`, polls for result |
| `payment-verification` | Main-session skill: reads payment screenshot from disk, validates amount, updates Orders sheet |
| `customer-lookup` | Looks up customer info from Google Sheets |
| `order-amendment` | Handles order modifications before cutoff |
| `daily-summary` | Daily order stats (pending/paid/cancelled) |
| `weekly-report` | Weekly aggregate reporting |
| `weekly-order-blast` | Saturday pickup blast to group chat |
| `payment-reminder` | Wednesday 10 AM reminder DM for unpaid pending orders |
| `auto-cancel` | Wednesday 2 PM auto-cancellation of unpaid pending orders |
| `backup` | Git-based backup to `raywu/asianova-bot` |
| `beta-signup-data-normalization` | Daily zip/phone enrichment + operator reminder for Ramen Egg Beta sheet |
| `beta-invite` | Weekly WhatsApp DM with group invite link to approved beta signups |

## Order Status Lifecycle

`pending` (at checkout) → `confirmed` (after payment-confirmation verifies screenshot)
`pending` → `cancelled` (auto-cancel after Wed 2 PM PT, or manual)

- New orders are always `pending`, never `confirmed`
- Venmo URL format: `venmo.com/{handle}` — do NOT use `venmo.com/u/{handle}` (strip `@` from handle)

## Key Config Patterns

- **Env var interpolation**: `${VAR_NAME}` in `openclaw.json` and `exec-approvals.json`; auto-loads `~/.openclaw/.env`
- **Gateway**: `mode: "local"` (not `gateway.bind`); binds to `127.0.0.1:18789`
- **Google Sheets**: `gog sheets` CLI (never `gsheet`)
- **Exec policy**: allowlist mode in `exec-approvals.json` (`security: "allowlist"`, not `"deny"`)
- **CRON**: uses `--cron` and `--message` flags (not `--schedule`/`--command`)
- **CRON exec caveat**: isolated sessions hit approval gates; use `session=main` for CRON jobs needing exec
- **CRON version control**: `jobs.json` is snapshotted into `workspace/cron/` by hourly checkpoint and tracked in git
- **Models**: primary `anthropic/claude-sonnet-4-6`, fallback `google/gemini-2.5-pro`; roster includes `gemini-3-pro-preview` and `claude-sonnet-4-5`
- **Channels**: WhatsApp (`dmPolicy: open`, group `120363404090082823@g.us` with `requireMention`) + Telegram (`dmPolicy: pairing`, operator `5906288273`)
- **Sandbox**: `non-main` mode, `openclaw-sandbox:bookworm-slim`, 512m memory, 128 PIDs, read-only root, workspace read-only in sandbox

## Key Concepts

- **Workspace files** (SOUL.md, IDENTITY.md, AGENTS.md, TOOLS.md, USER.md, HEARTBEAT.md, BOOT.md, CLAUDE.md, MEMORY.md, SYSTEM_LOG.md) define agent identity, behavior, and state — loaded into system prompt each message
- **Dual enforcement model**: soft (LLM reasoning via workspace markdown) + hard (Gateway tool policies, sandbox, OS-level containment)
- **Skills** are `SKILL.md` files with YAML frontmatter in `~/.openclaw/workspace/skills/<name>/`
- **Memory** uses daily markdown files + SQLite hybrid search (vector + BM25)
  - Activated 2026-02-28. `MEMORY.md` (long-term) + `memory/YYYY-MM-DD.md` (daily logs)
  - Auto-indexed via Gemini `gemini-embedding-001` embeddings + BM25 full-text
  - Agent writes daily observations and updates MEMORY.md when durable facts change
  - Boot and heartbeat checks verify memory index is non-empty
  - `memory_search` and `memory_get` must be in `tools.sandbox.tools.allow` — auto-detection provisions the index but sandbox blocks tool use without explicit allow

## CRON Jobs (12 active)

| Job | Schedule | Session | Type |
|-----|----------|---------|------|
| `daily-backup` | 23:59 UTC daily | main | systemEvent — runs `daily_backup.sh` |
| `hourly-checkpoint` | :00 every hour (+5m stagger) | main | systemEvent — runs `hourly_checkpoint.sh` |
| `order-checkout` | Tue 22:15 PT | main | systemEvent — batch checkout skill |
| `payment-reminder` | Wed 10:00 PT | isolated | agentTurn — DM unpaid customers |
| `auto-cancel` | Wed 14:00 PT | isolated | agentTurn — cancel unpaid orders |
| `daily-summary` | 21:00 UTC daily | isolated | agentTurn — Telegram report |
| `weekly-report` | Sun 08:00 UTC | isolated | agentTurn — Telegram report |
| `monday-config-reminder` | Mon 21:00 PT | isolated | agentTurn — Telegram reminder |
| `tuesday-form-blast` | Tue 09:00 PT | isolated | agentTurn — WhatsApp group blast |
| `tuesday-reminder` | Tue 16:00 PT | isolated | agentTurn — WhatsApp group reminder |
| `beta-signup-data-normalization` | 08:00 PT daily | isolated | agentTurn — zip/phone enrichment + operator reminder |
| `beta-invite` | Fri 14:00 PT | isolated | agentTurn — WhatsApp invite DMs to approved signups |

- `systemEvent` jobs target `session=main` (need exec access)
- `agentTurn` jobs use `isolated` sessions with delivery announcements

## Git

- Only `master` branch (no `main`)
- Deploy key isolation via SSH aliases (`github-openclaw`, `github-backup`) — no default key for bare `git@github.com`
- Agent exec restricted to `~/scripts/safe-git.sh` wrapper (blocks `remote` subcommand)

## When Editing

- Maintain the document's evaluation structure (Part 1: architecture context, Part 2: critique, Part 3: rewrite) where applicable
- Preserve severity ratings (Critical/Moderate/Minor) and issue numbering in evaluation docs
- Keep the security-first posture — every recommendation should consider both specialization and constraint
- Infrastructure references target Ubuntu 24.04 + DigitalOcean Premium AMD Droplets
- Use `pending` (not `confirmed`) for new orders at checkout
- Always use `gog sheets` — never `gsheet`
