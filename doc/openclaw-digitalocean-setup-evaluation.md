# OpenClaw + DigitalOcean Setup Evaluation

---

## OpenClaw Architecture Summary

OpenClaw is an open-source, self-hosted AI agent framework (MIT licensed) created by Peter Steinberger. It runs as a single persistent Node.js process (the **Gateway**) on your own hardware and connects to LLMs (Claude, GPT, DeepSeek, etc.) to autonomously execute tasks. Users interact via messaging platforms they already use — WhatsApp, Telegram, Slack, Discord, and others. Unlike session-based chatbots, OpenClaw is a persistent daemon: it maintains state between conversations, acts autonomously on schedules, and remembers context across weeks.

The design philosophy that makes OpenClaw powerful — and dangerous if misconfigured — is that every layer of the architecture serves a dual purpose: it both **specializes the agent** (making it useful for a domain) and **constrains the agent** (preventing it from acting outside its boundaries). Understanding this duality is essential to building an agent that is both effective and safe.

### The Core Layers

---

### 1. Gateway (Control Plane)

The Gateway is the single entry/exit point for all messages. It handles channel adapters (one per platform), session management, a serialized queue (one run per session to prevent race conditions), and WebSocket connections for tools and events. It binds to `127.0.0.1:18789` by default and should never be exposed to the public internet.

**For specialization:** The Gateway's channel bindings determine *where* the agent operates. You can route specific WhatsApp groups, Telegram chats, or Discord channels to specific agents — effectively scoping a specialist agent to only the conversations it should participate in.

**For security:** The Gateway is the trust boundary. If a caller passes Gateway auth, they are treated as a trusted operator. DM pairing, channel allowlists, and mention gating (`requireMention: true` for groups) control who can interact with the agent. Without these, anyone who messages the bot can trigger actions.

---

### 2. LLM (The Brain)

Model-agnostic by design. You configure providers in `openclaw.json` and the Gateway routes accordingly with fallback chains and exponential backoff. OpenClaw assembles large prompts — system instructions, conversation history, tool schemas, skills, and memory — so context window size matters.

**For specialization:** Model choice is a specialization lever. Use a frontier model (Claude Opus, GPT-4) as the primary orchestrator for complex reasoning and cheaper/faster models for heartbeats and sub-agent tasks. In multi-agent setups, each agent can use a different model optimized for its domain.

**For security:** The LLM is the component most vulnerable to prompt injection. System prompt guardrails in workspace files are "soft guidance" — the model *might* follow them. Hard enforcement comes from tool policies, sandbox configuration, and execution approvals at the Gateway and OS level. Always design as if the model can be manipulated; limit the blast radius of what a compromised model can do.

---

### 3. Workspace Configuration Files (Identity, Soul, & Behavior)

These Markdown files define *who* the agent is and *how* it behaves. They are loaded into the system prompt every time the agent processes a message. This is where the agent's specialization and security boundaries live side by side.

| File | Specialization Role | Security Role |
|------|---------------------|---------------|
| **`SOUL.md`** | Defines the agent's core purpose, values, and operational philosophy. Sets the "personality DNA" — whether it's a business operations manager, a coding assistant, or a customer service rep. | The agent's "constitution." Contains non-negotiable security rules (NEVER store credentials, NEVER access files outside workspace). Operates at the *reasoning* level — a well-written SOUL.md causes the agent to refuse bad requests before attempting execution. Use absolute language, not hedged suggestions. |
| **`IDENTITY.md`** | Name, role title, communication style, emoji. Makes the agent "feel" like a specialist — a business ops bot that speaks in structured reports vs. a creative assistant that uses casual tone. | Prevents identity confusion in multi-agent setups. A clearly scoped identity reduces the chance the agent strays into tasks outside its domain. |
| **`AGENTS.md`** | Defines operational workflows, delegation patterns, and multi-agent coordination. Specifies what tasks this agent handles vs. what should be escalated or routed elsewhere. | Enforces operational safety — what the agent can do, what requires human confirmation, and what it must never attempt. Defines tool allow/deny lists and access profiles per agent. |
| **`USER.md`** | Provides context about the operator — projects, preferences, business details, timezone. Grounds the agent's responses in the operator's specific situation. | Limits scope by defining who the operator is and what the agent should know. Keeps the agent from making assumptions about contexts it shouldn't have. |
| **`TOOLS.md`** | Declares which tools and integrations are available — this is how you give the agent its "hands." Enable only the tools relevant to its specialty. | The execution-level counterpart to SOUL.md's reasoning-level boundaries. Deny-by-default: explicitly enable only what's needed; deny everything else. |
| **`BOOT.md` / `BOOTSTRAP.md`** | Startup sequences — what the agent should check or initialize when it first comes online. | Can include startup health checks, config verification, and security posture validation. |
| **`HEARTBEAT.md`** | Instructions for proactive scheduled checks. The agent wakes periodically and acts without being prompted — monitoring, reporting, alerting. | Should include monitoring for anomalies (unexpected memory changes, cost spikes, failed backups) and alerting the operator via a trusted channel. |

**The critical insight:** OpenClaw's workspace file architecture is designed for separation of concerns. Dumping all configuration into a single "master prompt" in the dashboard bypasses this layered design. Each file serves a distinct purpose, and the layers reinforce each other — SOUL.md sets reasoning-level intent, TOOLS.md and AGENTS.md enforce execution-level policy, and sandboxing provides OS-level containment. Use all three layers.

---

### 4. Memory (Persistence & Context)

Memory is stored as plain Markdown files on disk — one file per day (`memory/YYYY-MM-DD.md`) plus curated long-term files (`MEMORY.md`). This is the canonical source of truth, human-readable and git-friendly. A derived SQLite index provides hybrid search (vector + BM25 keyword) for recall. The agent decides what's important enough to persist to long-term memory.

**For specialization:** Memory is what makes an agent compound over time. A business operations agent that remembers customer preferences, order history, and seasonal patterns becomes more useful every week. Memory accumulation is the moat — it's what separates a configured agent from a truly specialized one. The retain/recall/reflect cycle (inspired by MemGPT/Letta) lets the agent extract facts from daily logs, track entity-centric knowledge ("tell me about Customer X"), and evolve opinions with confidence scoring.

**For security:** Memory files are treated as trusted local operator state — if someone can edit them, they've already crossed the trust boundary. But memory is also an attack surface: persistent memory poisoning (a malicious message that gets saved to MEMORY.md) can create delayed-execution attacks that evolve across sessions. Never store secrets, credentials, or PII in memory files. Keep business data (CSVs, ledgers) in the workspace but separate from the agent's recall memory.

---

### 5. Skills (Capabilities & Domain Expertise)

Skills are the mechanism that transforms a generic agent into a specialist. Each skill is a directory containing a `SKILL.md` file with YAML frontmatter (metadata) and Markdown instructions (behavior). The agent reads these at runtime — no recompilation needed.

**How skills work:**

- Skills live in `~/.openclaw/workspace/skills/<skill-name>/SKILL.md`.
- OpenClaw injects a compact XML list of eligible skills into the system prompt each session.
- The agent scans skill descriptions to decide which one applies, then reads the full SKILL.md instructions before acting.
- Skills can include supporting files (scripts, templates, reference docs) and even bundled executables in a `bins/` directory that get added to the agent's PATH.
- Skills can be global (shared across all agents via `~/.openclaw/skills/`) or workspace-scoped (per-agent in `<workspace>/skills/`). Workspace skills take highest precedence.

**Anatomy of a well-written SKILL.md:**

```markdown
---
name: order-processing
description: Process incoming WhatsApp orders, validate items against inventory, log to CRM CSV, and confirm with customer.
metadata:
  openclaw:
    emoji: 📦
    requires:
      bins: [git]
---
# Order Processing

## When to use
Customer sends a message containing item names, quantities, or asks to place an order.

## Workflow
1. Parse the customer message for item names and quantities.
2. Validate against known inventory (see ~/workspace/inventory.md).
3. If valid: append to customers_orders.csv with Name, Item, Quantity, Timestamp, Status.
4. Send confirmation message to the customer via the originating channel.
5. If ambiguous: ask for clarification before logging.

## Edge Cases
- Unknown items: respond with "Item not found. Here's what we currently offer: [list]."
- Duplicate orders within 5 minutes: confirm with customer before logging.

## Output Format
CSV row: "CustomerName,ItemName,Quantity,YYYY-MM-DD HH:MM,confirmed"
```

**Key principles for building skills that specialize an agent:**

- **Write skills like runbooks, not marketing copy.** The SKILL.md body should read like a checklist you'd hand to a tired on-call engineer at 3 AM — deterministic steps, stop conditions, clear output format.
- **The `description` field is a trigger phrase, not documentation.** OpenClaw uses it to decide whether to load the full instructions. Use the nouns and verbs users actually type ("process order," "weekly report," "backup workspace"), not abstract descriptions.
- **Skills don't grant permissions.** If your tool policy blocks `exec`, a skill that relies on shell commands will load but fail at execution. Skills are instructions; tool policies are enforcement.
- **Each eligible skill costs tokens.** Even unused skills add ~97 characters + description length to the system prompt per session. Disable skills you don't need. Keep descriptions short. Merge small skills that share the same domain.
- **Prefer custom skills over generic ones for core workflows.** A business operations agent shouldn't rely on generic "file management" skills. Build domain-specific skills (order processing, report generation, backup automation) that encode your exact workflow.
- **Treat skill folders as trusted code.** Skills can inject environment variables, bundle executables, and instruct the agent to run arbitrary commands. Cisco found 26% of audited community skills contained vulnerabilities. Never install community skills without reviewing the source. Prefer workspace-scoped skills you write yourself for production business logic.

**Specialization through skill scoping in multi-agent setups:**

In multi-agent configurations, each agent has its own workspace — and therefore its own skills directory. This enables true specialization:
- A business operations agent gets `order-processing`, `weekly-report`, and `backup` skills.
- A market research agent gets `brave_search` and `competitive-analysis` skills.
- A coding agent gets `github`, `code-review`, and `deployment` skills.
- Global skills (installed with `-g` flag to `~/.openclaw/skills/`) are shared across all agents. Use this for truly universal capabilities.
- Agent-specific skills live in `<workspace>/skills/` and are invisible to other agents.

This scoping is both a specialization mechanism and a security boundary: an agent can only use skills it can see.

---

### 6. Heartbeat (Proactive Scheduling)

A daemon that wakes the agent at configured intervals to check conditions and act autonomously — without a user prompt.

**For specialization:** Heartbeats enable the agent's "always-on" workflows — the things that make it feel like a real employee. A business operations agent can check for unprocessed orders every 15 minutes, run a nightly backup, and send a weekly performance report — all without being asked.

**For security:** Heartbeats are the mechanism most likely to cause runaway behavior. An agent that wakes every 5 minutes with broad permissions and poor instructions is a ticking time bomb. Define heartbeat instructions in `HEARTBEAT.md` with explicit conditions, rate limits, and escalation rules. Include cost and action thresholds.

---

### 7. Multi-Agent Routing (Scaling Specialization)

OpenClaw supports running multiple isolated agents on a single Gateway. Each agent is a "fully scoped brain" with its own workspace, session store, auth profiles, memory, and skills.

**How routing works:** Bindings map inbound messages to agents using a "most-specific-wins" ladder:
1. Peer match (specific DM or group ID) — highest priority
2. Guild/Team ID (specific Discord server or Slack team)
3. Account ID (specific phone number)
4. Channel match (all messages from a platform)
5. Default agent — fallback

**Practical pattern for a business operations team:**
```
Gateway
├── ops-agent (WhatsApp orders group + Telegram reports)
│   ├── Workspace: ~/.openclaw/workspace-ops
│   ├── Skills: order-processing, weekly-report, backup
│   ├── Tools: exec (approved), read, write (workspace only)
│   └── Model: Claude Sonnet (cost-efficient for routine tasks)
│
├── research-agent (Telegram research channel)
│   ├── Workspace: ~/.openclaw/workspace-research
│   ├── Skills: brave_search, competitive-analysis
│   ├── Tools: read, web_search (no exec, no write)
│   └── Model: Claude Opus (deeper reasoning for analysis)
│
└── default-agent (everything else)
    ├── Workspace: ~/.openclaw/workspace-default
    └── Responds: "I'm not the right agent for this. Try the ops channel."
```

Each agent sees only its own skills, memory, and session history. A compromised research agent cannot access order data, and a compromised ops agent cannot browse the web. This isolation is both specialization (each agent does one thing well) and security (blast radius is contained).

**Start with one agent.** OpenClaw's documentation and experienced users agree: most use cases don't require multiple agents. A single well-configured agent with good memory management, proper tool access, and domain-specific skills handles most personal and small business workflows. Add agents only when you hit clear isolation or specialization needs.

---

### How the Layers Work Together: Security + Specialization

OpenClaw's security philosophy is: **Identity first → Scope next → Model last.**

The same framework applies to specialization:

| Layer | Security Function | Specialization Function |
|-------|-------------------|------------------------|
| **Channel bindings + DM policy** | Controls who can talk to the agent | Controls where the agent operates |
| **SOUL.md** *(soft/reasoning)* | Non-negotiable security boundaries | Core purpose, values, operational philosophy |
| **IDENTITY.md** *(soft/reasoning)* | Prevents identity confusion | Agent personality and communication style |
| **AGENTS.md** *(soft/reasoning)* | Tool guidance, confirmation expectations | Workflow definitions, delegation patterns |
| **TOOLS.md** *(soft/reasoning)* | Prose instructions on tool restrictions | Declares available capabilities for the LLM |
| **`openclaw.json` tool policy** *(hard/execution)* | Gateway-enforced deny-list, `fs.workspaceOnly` | Declares which tools the Gateway actually provides |
| **Sandbox (Docker)** *(hard/execution)* | OS-level containment, blast radius reduction | Resource isolation per agent |
| **Compaction** *(hard/execution)* | Prevents session crashes from context overflow | Enables long-running specialist workflows |
| **Skills** | Scoped to workspace; treat as trusted code | Domain-specific playbooks and automations |
| **Memory** | Never store secrets; monitor for poisoning | Compound knowledge that makes the agent better over time |
| **Heartbeat** | Rate limits, cost thresholds, anomaly detection | Always-on proactive workflows |

The key insight is that **these are not separate systems** — they are the same architecture serving both goals simultaneously. A well-specialized agent is inherently more secure (it doesn't have access to things it doesn't need), and a well-secured agent is inherently more focused (it can only act within its defined scope).

**Critical distinction: soft vs. hard enforcement.** Workspace Markdown files (SOUL.md, TOOLS.md, AGENTS.md) are *reasoning-level* guidance — the LLM reads them and *usually* follows them, but a prompt injection can bypass them. The `openclaw.json` tool policies, `fs.workspaceOnly`, sandbox configuration, and compaction settings are *execution-level* enforcement — the Gateway applies them regardless of what the LLM decides. A production setup requires both layers. Never rely on SOUL.md alone for security.

---

## Key Insights for Setting Up an OpenClaw Agent for Success

### Infrastructure & Isolation
- **Run on dedicated, isolated infrastructure.** Never on your primary workstation. A DigitalOcean Droplet, dedicated VM, or separate device with a kill switch you can reach. Microsoft, CrowdStrike, and OpenClaw's own maintainers all recommend this.
- **Bind the Gateway to `127.0.0.1`.** Access it via SSH tunnel or Tailscale. Never expose port 18789 to the public internet. Scanners find exposed instances within hours.
- **Use UFW to lock down the firewall.** Default deny incoming, allow only SSH (rate-limited). Never allow 18789 from the public internet.
- **Plan for recovery.** DigitalOcean snapshots, git-backed workspace, and a documented rebuild procedure. Treat the environment as disposable.

### Credentials & Secrets
- **Use dedicated, scoped credentials.** Create agent-specific tokens with minimum necessary permissions. Assume anything the agent can see might eventually leak. Prefer read-only tokens where possible and rotate regularly.
- **Keep secrets out of the agent's reach.** Store them in `~/.openclaw/secrets/` with `chmod 700/600`. Never in `.env` files the agent can read, never in memory files, never in bash history.
- **Use SSH deploy keys for git operations.** Never use `git credential.helper store` — it writes tokens in plaintext to disk.

### Context & Configuration
- **Give the agent correct, rich context across all workspace files.** Well-written `SOUL.md`, `IDENTITY.md`, `USER.md`, and `AGENTS.md` are 80% of making the agent useful. Be explicit about the agent's role, what it manages, and what it must not touch.
- **Distribute configuration across purpose-built files, not a single prompt.** OpenClaw's architecture is designed for separation of concerns. SOUL.md for identity and boundaries, AGENTS.md for operational rules, TOOLS.md for tool guidance, skills for domain playbooks.
- **Understand the two enforcement layers.** Workspace Markdown files (SOUL.md, TOOLS.md, AGENTS.md) are *reasoning-level* guidance the LLM reads — soft enforcement. The `openclaw.json` tool policies, sandbox config, and `fs.workspaceOnly` are *execution-level* enforcement the Gateway applies — hard enforcement. You need both. A prompt injection can bypass SOUL.md; it cannot bypass a Gateway deny-list.
- **Configure compaction for long-running sessions.** A business operations agent processing orders all day will hit context window limits. Set `compaction.mode: "safeguard"` in `openclaw.json` so OpenClaw automatically summarizes older history and flushes important facts to memory files before compacting. Use `/compact` manually when sessions feel sluggish, and `/new` to start fresh after completing a batch of work.
- **Run `openclaw doctor --fix` after every configuration change.** This built-in diagnostic catches the most common misconfigurations — exposed bindings, missing auth, sandbox issues, risky DM policies.
- **Disable mDNS broadcasting.** On a VPS, OpenClaw's default mDNS announcement leaks filesystem paths, hostnames, and SSH availability to anyone on the network. Set `mdns.enabled: false` in `openclaw.json`.
- **Version-control your workspace.** The `~/.openclaw/workspace/` directory is git-friendly. Commit changes so you can track when skills, memory, or config changed — and roll back if something breaks. Include a `.gitignore` to exclude SQLite index files and credentials.

### Skills & Specialization
- **Build custom skills for your core workflows.** Don't rely on generic community skills for business-critical operations. Write domain-specific SKILL.md files with deterministic steps, clear inputs/outputs, and explicit edge-case handling.
- **Write skill descriptions as trigger phrases.** Use the exact nouns and verbs your users type. A description that doesn't match how people ask for the task will never be activated.
- **Write skill bodies like runbooks.** Checklists, not essays. Deterministic steps, stop conditions, output format. The agent should know exactly what to do without improvising.
- **Use Google Sheets as your structured data backend instead of flat CSV files.** A local CSV works for a prototype, but breaks under concurrent writes, has no relational capability, and can't be viewed by your team in real-time. The `google-sheets` community skill (or the broader `gog` skill for full Google Workspace) lets the agent read, write, append, and query spreadsheets via the Sheets API. Your agent manages data through chat; your team sees it live in Google Sheets. Scope the OAuth token to Sheets only — don't grant Drive/Gmail access unless needed.
- **Disable unnecessary skills.** Every eligible skill costs tokens in the system prompt, even when unused. Keep only what the agent needs for its specialty.
- **Audit community skills before installing.** Cisco found 26% of audited skills contained vulnerabilities. Treat `SKILL.md` files as code — review before trusting. Check VirusTotal reports on ClawHub before installing any community skill.

### Operations & Monitoring
- **Task the agent with repetitive, well-defined operations.** OpenClaw excels at recurring workflows: scheduled reports, order logging, backup scripts, CRM updates, heartbeat monitoring. Define these as skills or CRON jobs with clear inputs and outputs.
- **Use OpenClaw's built-in CRON and heartbeat, not raw system crontab.** The agent shouldn't need direct crontab access. OpenClaw's scheduling integrates with the agent's context and memory.
- **Monitor and audit.** Review memory files for unexpected entries, watch API spending, and set cost alerts in `SOUL.md`. Check `SYSTEM_LOG.md` regularly.
- **Treat prompt injection as inevitable.** The agent processes untrusted content from messages, web pages, and APIs. Sandbox tool execution, use mention gating in groups, and design so manipulation has limited blast radius.
- **Set confirmation gates for high-impact actions.** Messages to customer-facing channels, file deletions, and new CRON job creation should require explicit approval or a review delay.

---

