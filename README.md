# OpenClaw + DigitalOcean Setup Guide

Documentation for a **live deployed** OpenClaw instance (open-source, self-hosted AI agent framework) on DigitalOcean infrastructure. This repository contains documentation only — no application code, build system, or test suite.

## Documents

- **`doc/openclaw-setup-guide.md`** — Production deployment walkthrough for Ubuntu 24.04 on DigitalOcean
- **`doc/prompt-claude-code-openclaw-setup.md`** — Interactive Claude Code prompt for guided setup
- **`doc/prompt-multi-agent-openclaw-setup.md`** — Multi-agent orchestration prompt
- **`doc/reference-openclaw-digitalocean-setup-evaluation.md`** — Architecture evaluation: seven-layer architecture with dual specialization/security analysis
- **`doc/reference-openclaw-order-crm-tools-skills.md`** — Order/CRM skill reference
- **`doc/reference-openclaw-shopify-gmail-research-report.md`** — Shopify/Gmail integration research
- **`doc/reference-openclaw-skill-editing-report.md`** — Skill editing patterns
- **`doc/reference-whatsapp-injection-defense-analysis.md`** — WhatsApp injection defense analysis

## Deployed Skills

| Skill | Description |
|-------|-------------|
| `order-checkout` | CRON-triggered batch checkout, sends DMs with Venmo links |
| `payment-confirmation` | Verifies payment screenshots, updates status to `confirmed` |
| `customer-lookup` | Customer info lookup from Google Sheets |
| `order-amendment` | Order modifications before cutoff |
| `daily-summary` | Daily order stats (pending/paid/cancelled) |
| `weekly-report` | Weekly aggregate reporting |
| `weekly-order-blast` | Saturday pickup blast to group chat |
| `backup` | Git-based backup to remote repo |

## Order Status Lifecycle

`pending` (at checkout) → `confirmed` (after payment verification)

## Key Concepts

- **OpenClaw Gateway** binds to `127.0.0.1:18789` — never expose publicly; access via SSH tunnel
- **Workspace files** (SOUL.md, IDENTITY.md, AGENTS.md, TOOLS.md, USER.md, HEARTBEAT.md, BOOT.md) define agent identity and behavior — loaded into system prompt each message
- **Dual enforcement model**: soft (LLM reasoning via workspace markdown) + hard (Gateway tool policies, sandbox, OS-level containment)
- **Skills** are `SKILL.md` files with YAML frontmatter in `~/.openclaw/workspace/skills/<name>/`
- **Memory** uses daily markdown files + SQLite hybrid search (vector + BM25)
