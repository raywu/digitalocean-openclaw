# OpenClaw Setup Evaluation

---

## Evaluation of the Provided Setup Instructions & Configuration Prompt

Below is a detailed critique organized by category. Issues are rated as **🔴 Critical**, **🟡 Moderate**, or **🟢 Minor/Stylistic**.

### A. Infrastructure & Access Setup

| # | Issue | Rating | Detail |
|---|-------|--------|--------|
| 1 | No firewall (UFW) configuration mentioned | 🔴 | The guide tells users to bind Gateway to `127.0.0.1` (good) but never sets up `ufw`. Without a firewall, other services or misconfigurations could expose the Droplet. Add: `sudo ufw default deny incoming && sudo ufw allow OpenSSH && sudo ufw enable`. |
| 2 | Root SSH login not disabled | 🔴 | The guide creates `clawuser` but never disables root SSH login or password authentication. Add: edit `/etc/ssh/sshd_config` to set `PermitRootLogin no` and `PasswordAuthentication no`, then restart sshd. |
| 3 | No mention of `fail2ban` or SSH rate limiting | 🟡 | SSH key auth is good, but `fail2ban` or `ufw limit 22/tcp` adds defense-in-depth against brute force. |
| 4 | `curl | bash` install pattern | 🟡 | Piping a remote script directly to bash is a known supply chain risk. The guide should mention verifying the script hash or at least reviewing before executing. Malicious typosquat domains for OpenClaw have been documented (Malwarebytes reported cloned repos and impersonation domains). |
| 5 | No mention of Tailscale as an alternative to SSH tunnels | 🟢 | SSH tunnels work but Tailscale is recommended by both DigitalOcean and OpenClaw docs for always-on private access. Worth mentioning as an option. |

### B. The Master Prompt — Structural & Specialization Issues

| # | Issue | Rating | Detail |
|---|-------|--------|--------|
| 6 | Prompt conflates *configuration context* with *executable instructions* | 🔴 | The prompt asks the agent to "Act as a Systems & Operations Architect" and gives it a mix of personality instructions, CRON setup, business logic, and security rules — all in one flat block. OpenClaw's architecture is designed to separate these into distinct workspace files (`SOUL.md`, `AGENTS.md`, `IDENTITY.md`, `TOOLS.md`, `HEARTBEAT.md`). Dumping everything into a single dashboard prompt bypasses the layered guardrail architecture and prevents the agent from being properly specialized. |
| 7 | No `SOUL.md` with explicit security boundaries | 🔴 | The prompt says "Safety & Memory" but the rules are soft suggestions inside a task prompt, not hard boundaries in `SOUL.md`. Security researchers are unanimous: `SOUL.md` with absolute, non-negotiable rules is the first line of defense. This is also the file that defines the agent's core specialization — without it, the agent has no grounded identity. |
| 8 | Agent is told to run `crontab -e` and write shell scripts | 🔴 | Giving the agent direct crontab and shell script creation authority without sandbox, approval gates, or tool policy restrictions is the "AI with sudo" pattern that security teams warn against. The guide should use OpenClaw's built-in CRON scheduling and execution approval workflows instead of raw system crontab. |
| 9 | No custom skills defined for business workflows | 🔴 | The prompt describes complex workflows (order form posting, CRM logging, weekly reports, backup automation) but implements none of them as proper skills. Each of these should be a `SKILL.md` in `~/.openclaw/workspace/skills/` with structured instructions, trigger descriptions, edge cases, and output formats. Without skills, the agent improvises every time — inconsistent results, token waste, and higher hallucination risk. |
| 10 | "Strict Disable: Disable all email-related skills" — mechanism unclear | 🟡 | How? This needs to be an explicit `TOOLS.md` deny-list or `openclaw.json` tool policy entry, not a prose instruction the LLM might ignore under prompt injection. |
| 11 | `MEMORY.md` update instruction is vague | 🟡 | "Ensure MEMORY.md is updated after every successful order" — the agent already manages memory through its built-in retain/recall/reflect cycle. Manually directing it to write to `MEMORY.md` may conflict with the memory architecture. Better to let the memory system handle contextual recall and use the workspace directory for structured business data (`customers_orders.csv`). |
| 12 | No `HEARTBEAT.md` for proactive monitoring | 🟡 | The prompt describes scheduled tasks (backups, reports) but doesn't leverage OpenClaw's heartbeat architecture for proactive monitoring — uptime checks, backup verification, anomaly detection. |

### C. Backup & Data Persistence

| # | Issue | Rating | Detail |
|---|-------|--------|--------|
| 13 | `git config --global credential.helper store` stores credentials in plaintext | 🔴 | This writes GitHub tokens to `~/.git-credentials` in plain text on disk — exactly what security guidance says never to do. The agent can read this file. Use SSH deploy keys for git operations or a credential helper that integrates with a secret manager. |
| 14 | Backup script pushes to GitHub without explicit access scoping | 🟡 | The prompt says "Verify you have Write access to the backup repo and Read-Only access to our project repos" but doesn't explain how to create a scoped GitHub fine-grained PAT or deploy key. Without this, a leaked token could compromise all repos. |
| 15 | `~/.openclaw` contains sensitive data beyond business files | 🟡 | Backing up the entire `~/.openclaw` directory includes API keys, LLM tokens, and channel credentials. The guide should distinguish between backing up the *workspace* (safe and recommended) and the full config directory (sensitive, requires encryption). |
| 16 | No mention of encrypting backups | 🟡 | Customer order data (names, items, timestamps) is being pushed to a GitHub repo. Even if the repo is private, this is PII in a third-party cloud service. Consider encrypted backups or at minimum a private repo with branch protection. |

### D. Business Logic & Channel Configuration

| # | Issue | Rating | Detail |
|---|-------|--------|--------|
| 17 | WhatsApp group posting without confirmation gates | 🟡 | "You are authorized to compose and post 'Order Forms' to our WhatsApp group" — no mention of requiring human approval before posting, or rate limits. A prompt injection or hallucination could spam the group. Add a confirmation workflow or review delay. |
| 18 | No DM policy or group mention gating configured | 🟡 | The channel setup (`openclaw channels add whatsapp/telegram`) doesn't configure `dmPolicy: "pairing"` or `requireMention: true` for groups. Without these, anyone who messages the bot or mentions it in a group could trigger actions. |
| 19 | CSV as a "CRM Ledger" has no validation or locking strategy | 🟢 | A single CSV for order tracking is fragile. The daily git backup helps, but there's no mention of file locking if the agent processes concurrent orders, or validation of CSV integrity. |

### E. Missing Elements

| # | Issue | Rating |
|---|-------|--------|
| 20 | No cost controls or API spending limits | 🟡 |
| 21 | No heartbeat configuration for uptime monitoring | 🟡 |
| 22 | No incident response plan (what to do if the agent goes rogue) | 🟡 |
| 23 | No agent specialization strategy (skills, scoped tools, focused identity) | 🟡 |
| 24 | No `openclaw.json` tool policy (hard enforcement layer) — all restrictions are soft LLM guidance only | 🔴 |
| 25 | No sandbox configuration — all exec runs directly on host OS | 🔴 |
| 26 | No compaction/context window management — long sessions will crash | 🟡 |
| 27 | No `openclaw doctor` validation step | 🟡 |
| 28 | mDNS broadcasting not disabled — leaks infrastructure details on network | 🟡 |
| 29 | No model selection or cost management in config | 🟡 |
| 30 | No file permissions set on `~/.openclaw/` (contains API keys) | 🟡 |
| 31 | No `.gitignore` in workspace git repo — risk of committing secrets or SQLite index | 🟢 |
| 32 | `TOOLS.md` written as YAML config syntax instead of prose — invalid for a workspace file | 🟢 |
| 33 | No log rotation or monitoring for the agent's activity | 🟢 |
| 34 | No mention of DigitalOcean monitoring/alerts for Droplet health | 🟢 |
| 35 | No ongoing maintenance schedule (credential rotation, security audits) | 🟡 |

---

