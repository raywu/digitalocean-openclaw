# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a documentation repository containing a comprehensive evaluation and rewrite guide for deploying **OpenClaw** (open-source, self-hosted AI agent framework) on **DigitalOcean** infrastructure. There is no application code, build system, or test suite.

### Document Structure (`doc/`)

- **`openclaw-digitalocean-setup-evaluation.md`** (~240 lines) — OpenClaw architecture reference: seven-layer architecture (Gateway, LLM, Workspace files, Memory, Skills, Heartbeat, Multi-agent routing) with dual specialization/security analysis
- **`openclaw-evaluation.md`** (~70 lines) — Critical evaluation of a typical setup guide, with issues rated Critical/Moderate/Minor
- **`openclaw-setup-guide.md`** (~1440 lines) — Production-hardened deployment walkthrough for Ubuntu 24.04 on DigitalOcean
- **`openclaw-claude-code-setup-prompt.md`** (~1190 lines) — Condensed, interactive prompt for Claude Code to guide a user through the full OpenClaw setup. Derived from the setup guide with all file contents, security guardrails, and verification checks preserved; rationale and redundancy removed

## Key Concepts

- **OpenClaw Gateway** binds to `127.0.0.1:18789` — never expose publicly; access via SSH tunnel
- **Workspace files** (SOUL.md, IDENTITY.md, AGENTS.md, TOOLS.md, USER.md, HEARTBEAT.md, BOOT.md) define agent identity and behavior — loaded into system prompt each message
- **Dual enforcement model**: soft (LLM reasoning via workspace markdown) + hard (Gateway tool policies, sandbox, OS-level containment)
- **Skills** are `SKILL.md` files with YAML frontmatter in `~/.openclaw/workspace/skills/<name>/`
- **Memory** uses daily markdown files + SQLite hybrid search (vector + BM25)

## When Editing

- Maintain the document's evaluation structure (Part 1: architecture context, Part 2: critique, Part 3: rewrite)
- Preserve severity ratings (Critical/Moderate/Minor) and issue numbering in Part 2
- Keep the security-first posture — every recommendation should consider both specialization and constraint
- Infrastructure references target Ubuntu 24.04 + DigitalOcean Premium AMD Droplets
