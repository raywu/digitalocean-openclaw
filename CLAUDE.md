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

8 skills in `~/.openclaw/workspace/skills/`:

| Skill | Description |
|-------|-------------|
| `order-checkout` | CRON-triggered batch checkout, sends DMs with Venmo links |
| `payment-confirmation` | Verifies payment screenshots, updates status to `confirmed` |
| `customer-lookup` | Looks up customer info from Google Sheets |
| `order-amendment` | Handles order modifications before cutoff |
| `daily-summary` | Daily order stats (pending/paid/cancelled) |
| `weekly-report` | Weekly aggregate reporting |
| `weekly-order-blast` | Saturday pickup blast to group chat |
| `backup` | Git-based backup to `raywu/asianova-bot` |

## Order Status Lifecycle

`pending` (at checkout) → `confirmed` (after payment-confirmation verifies screenshot)

- New orders are always `pending`, never `confirmed`
- Venmo URL format: `venmo.com/u/{handle}` (strip `@` from handle)

## Key Config Patterns

- **Env var interpolation**: `${VAR_NAME}` in `openclaw.json` and `exec-approvals.json`; auto-loads `~/.openclaw/.env`
- **Gateway**: `mode: "local"` (not `gateway.bind`); binds to `127.0.0.1:18789`
- **Google Sheets**: `gog sheets` CLI (never `gsheet`)
- **Exec policy**: allowlist mode in `exec-approvals.json` (`security: "allowlist"`, not `"deny"`)
- **CRON**: uses `--cron` and `--message` flags (not `--schedule`/`--command`)
- **CRON exec caveat**: isolated sessions hit approval gates; use `session=main` for CRON jobs needing exec

## Key Concepts

- **Workspace files** (SOUL.md, IDENTITY.md, AGENTS.md, TOOLS.md, USER.md, HEARTBEAT.md, BOOT.md) define agent identity and behavior — loaded into system prompt each message
- **Dual enforcement model**: soft (LLM reasoning via workspace markdown) + hard (Gateway tool policies, sandbox, OS-level containment)
- **Skills** are `SKILL.md` files with YAML frontmatter in `~/.openclaw/workspace/skills/<name>/`
- **Memory** uses daily markdown files + SQLite hybrid search (vector + BM25)

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
