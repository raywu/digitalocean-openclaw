# OpenClaw + DigitalOcean Setup Guide

A comprehensive evaluation and rewrite guide for deploying **OpenClaw** (open-source, self-hosted AI agent framework) on **DigitalOcean** infrastructure. This repository contains documentation only — no application code, build system, or test suite.

## Documents

- **`doc/openclaw-digitalocean-setup-evaluation.md`** — OpenClaw architecture reference: seven-layer architecture with dual specialization/security analysis
- **`doc/openclaw-evaluation.md`** — Critical evaluation of a typical setup guide, with issues rated Critical/Moderate/Minor
- **`doc/openclaw-setup-guide.md`** — Production-hardened deployment walkthrough for Ubuntu 24.04 on DigitalOcean
- **`doc/openclaw-claude-code-setup-prompt.md`** — Condensed, interactive prompt for Claude Code to guide a user through the full OpenClaw setup

## Key Concepts

- **OpenClaw Gateway** binds to `127.0.0.1:18789` — never expose publicly; access via SSH tunnel
- **Workspace files** (SOUL.md, IDENTITY.md, AGENTS.md, TOOLS.md, USER.md, HEARTBEAT.md, BOOT.md) define agent identity and behavior — loaded into system prompt each message
- **Dual enforcement model**: soft (LLM reasoning via workspace markdown) + hard (Gateway tool policies, sandbox, OS-level containment)
- **Skills** are `SKILL.md` files with YAML frontmatter in `~/.openclaw/workspace/skills/<name>/`
- **Memory** uses daily markdown files + SQLite hybrid search (vector + BM25)
