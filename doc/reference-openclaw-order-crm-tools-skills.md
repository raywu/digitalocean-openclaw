# OpenClaw Tools & Skills for Order Management and CRM

> Companion to `openclaw-setup-guide.md`. This covers what to provision — community skills, MCP integrations, and custom skills — to support a working order and CRM workflow on OpenClaw beyond the Tier 1 Google Sheets setup in the main guide.

---

## The Decision Framework

Before listing tools, the important architectural question is: **where does your data live?**

OpenClaw isn't a CRM. It's an agent that *operates* on your data wherever it's stored. The tools and skills you provision depend on whether you're using:

| Data Store | Best For | OpenClaw Integration Path |
|------------|----------|--------------------------|
| **CSV in workspace** | Solo operators, <50 orders/week | Built-in `fs` tools (read/write). No extra skills needed. Custom skill handles parsing/validation. |
| **Google Sheets** | Small teams, shared visibility, no-code dashboards | `google-sheets` skill (ClawHub) — OAuth, read/write cells, formulas |
| **Airtable** | Structured CRM with views, filters, automations | `airtable-automation` skill (Composio/Rube MCP) — CRUD on records, tables, views |
| **Notion** | CRM + docs + wiki in one workspace | `better-notion` or built-in `notion` skill — full CRUD on pages and databases |
| **Supabase (Postgres)** | Developers, SQL, structured queries, scalability | `supabase` skill — SQL queries, table management, vector search |
| **Odoo** | Full ERP (orders + invoicing + inventory + accounting) | `odoo-openclaw-skill` — read-only RPC queries, reports, WhatsApp cards |
| **Dedicated CRM (HubSpot, Salesforce, etc.)** | Sales teams, pipeline management | Via Composio MCP or Zapier MCP bridge |

**The setup guide currently uses CSV in workspace.** This is the simplest and most appropriate starting point for a solo or small operation — no external dependencies, no API costs, fully version-controlled in git. The recommendations below are organized in tiers: what to start with (CSV), what to graduate to (structured data store), and what to add as the operation grows.

---

## Tier 1: Starting Configuration (CSV-Based, Day One)

These are the custom skills and built-in tools already covered in the setup guide. No community skills needed — just the agent's native `fs` tools (read, write, edit) and your custom skill logic.

### Custom Skills to Write (Already in Setup Guide)

| Skill | Trigger | Data Store |
|-------|---------|------------|
| `order-processing` | Customer sends items/quantities via WhatsApp | Appends to `customers_orders.csv` |
| `weekly-report` | CRON Sunday 8 AM, or operator request | Reads `customers_orders.csv`, sends Telegram summary |
| `backup` | CRON nightly 11:59 PM | Git push workspace to private repo |

### Custom Skills to Add (Not Yet in Setup Guide)

These fill gaps in the current order/CRM workflow:

**1. Customer Lookup Skill**

```markdown
---
name: customer-lookup
description: Look up a customer by name, find their order history, last order date, total spending, and preferred items.
metadata:
  openclaw:
    emoji: 🔍
---
# Customer Lookup

## When to Use
Operator or agent needs customer history — repeat customer placing a new order,
customer inquiry about past orders, or preparing a follow-up.

## Workflow
1. Search customers_orders.csv for rows matching the customer name (fuzzy match).
2. Aggregate: total orders, total items, most recent order date, most frequently
   ordered items, total spend (if price column exists).
3. Return structured summary.

## Output Format
🔍 Customer: [Name]
- Orders: [count] since [first order date]
- Last Order: [date] — [items]
- Top Items: [ranked by frequency]
- Notes: [from MEMORY.md if any]

## Edge Cases
- No match → "No customer found matching '[name]'. Check spelling?"
- Multiple partial matches → List top 3 matches, ask for clarification.
```

**2. Inventory Check / Low Stock Alert Skill**

```markdown
---
name: inventory-check
description: Check current inventory levels, identify low stock items, and alert operator when items need restocking.
metadata:
  openclaw:
    emoji: 📦
---
# Inventory Check

## When to Use
- During order processing (validate items exist and are in stock)
- Heartbeat check (scheduled inventory review)
- Operator asks "what's running low?" or "inventory status"

## Workflow
1. Read inventory.md for current stock levels.
2. Cross-reference with recent orders in customers_orders.csv to calculate
   items sold since last restock.
3. Flag items below restock threshold (defined in inventory.md header).
4. If triggered by heartbeat: only alert if low-stock items found.
5. If triggered by operator: always return full inventory summary.

## Output Format
📦 Inventory Status
- [Item]: [quantity] remaining [⚠️ LOW if below threshold]
- ...
- Last updated: [date from inventory.md]

## Edge Cases
- inventory.md missing → Alert operator immediately.
- Item in order not in inventory → Flag as "unknown item" during order processing.
```

**3. Order Form Generator Skill**

```markdown
---
name: order-form
description: Generate and post a formatted order form to the WhatsApp group showing available items, prices, and how to order.
metadata:
  openclaw:
    emoji: 📋
---
# Order Form Generator

## When to Use
Operator requests "post the order form" or scheduled posting (e.g., weekly).

## Workflow
1. Read inventory.md for available items, prices, and descriptions.
2. Format as a clean WhatsApp message with emoji, item names, prices.
3. **REQUIRE OPERATOR CONFIRMATION before posting to group.**
4. Post to designated WhatsApp group.
5. Log posting to SYSTEM_LOG.md.

## Output Format
📋 [Business Name] — Order Form
━━━━━━━━━━━━━━━━━
[emoji] [Item] — $[price]
   [brief description]
...
━━━━━━━━━━━━━━━━━
📩 To order: Send item name + quantity
📞 Questions? Message us directly

## NEVER
- Post without operator confirmation.
- Post more than once per day to the same group.
```

**4. Daily Sales Summary Skill**

```markdown
---
name: daily-summary
description: Generate end-of-day sales summary from today's orders and send to operator Telegram.
metadata:
  openclaw:
    emoji: 📈
---
# Daily Sales Summary

## When to Use
CRON at 9:00 PM daily, or when operator asks "how was today?"

## Workflow
1. Read customers_orders.csv, filter to today's date.
2. Calculate: order count, unique customers, items sold, top item.
3. Compare to yesterday and same day last week (if data exists).
4. Send concise summary to operator Telegram.

## Output Format
📈 Daily Summary — [date]
- Orders: [count] ([+/-] vs yesterday)
- Revenue: $[amount] (if price data available)
- Customers: [count] ([new] new)
- Top Item: [item] ([quantity] sold)

## Edge Cases
- No orders today → "📈 Quiet day — no orders recorded."
- CSV error → Alert instead of summary.
```

### Built-In Tools to Enable

These are OpenClaw's native tools (controlled in `openclaw.json`). No skill installation needed:

| Tool | Purpose | Config |
|------|---------|--------|
| `fs.read` / `fs.write` / `fs.edit` | Read/write CSV, inventory.md, logs | `tools.fs.workspaceOnly: true` |
| `exec` / `bash` | Run backup script, git operations | `tools.exec.approvals: true` |
| `brave_search` | Market research, competitor pricing | Enable in tool allow-list |
| `github` | Backup push, workspace sync | Scoped to backup repo only |

---

## Tier 2: Graduating to a Structured Data Store

When you outgrow CSV — more than ~100 orders/week, need for querying/filtering, multiple people accessing data, or you want dashboards — move to a structured backend. Here are the best-supported options in the OpenClaw ecosystem:

### Option A: Google Sheets (Lowest Friction)

**Why:** Your team already uses it. Shared visibility. No server to manage. Free.

**Skill:** `google-sheets` (ClawHub)
```bash
openclaw skill install google-sheets
```

**What it gives you:**
- Read/write cells, rows, ranges
- Create spreadsheets, manage worksheets
- Formula generation via natural language
- Cron-driven report generation from live data

**CRM pattern:** Create a Sheets workbook with tabs for Customers, Orders, Inventory. The agent reads and writes directly. Operator sees updates in real time from any device.

**Security note:** Requires Google Cloud OAuth credentials. Store the credentials JSON in `~/.openclaw/secrets/`, not in the workspace. The agent gets read/write access to shared sheets — scope this to specific spreadsheets, not your entire Drive.

**Recommended custom skill modification:** Rewrite `order-processing` to write to Google Sheets instead of CSV. Keep a local CSV as a backup/cache.

---

### Option B: Notion (CRM + Docs Unified)

**Why:** Combines CRM database with docs, notes, and wiki. Good if you already use Notion for business operations.

**Skill:** Built-in `notion` skill or `better-notion` (ClawHub)
```bash
openclaw skill install notion
# or for full CRUD:
openclaw skill install better-notion
```

**What it gives you:**
- Full CRUD on Notion databases (create/read/update/delete rows)
- Page creation and search
- Database queries with filters

**CRM pattern:** Create Notion databases for Customers (name, contact, notes, last order) and Orders (linked to customer, items, date, status). Agent creates rows on new orders and updates status. Operator manages the database in Notion's UI.

**Security note:** Internal integrations in Notion have NO access by default — you must explicitly share each database/page with the integration. Scope narrowly.

---

### Option C: Airtable (Structured + Visual)

**Why:** Spreadsheet simplicity with relational database power. Views, filters, automations built in.

**Skill:** `airtable-automation` (via Composio/Rube MCP)
```bash
openclaw skill install airtable-automation
```

**What it gives you:**
- Record CRUD on Airtable bases
- Table and field management
- View filtering

**CRM pattern:** Airtable base with linked tables (Customers ↔ Orders ↔ Inventory). Agent creates order records linked to customer records. Airtable's built-in views give you Kanban boards, calendars, and charts without extra work.

---

### Option D: Supabase (Developer-Grade)

**Why:** Real Postgres database. SQL queries. Scales to millions of rows. Free tier is generous.

**Skill:** `supabase` (ClawHub)

**What it gives you:**
- SQL queries directly from the agent
- Table creation and schema management
- Vector search (for semantic customer lookup)
- Edge functions for webhooks

**CRM pattern:** Postgres tables for customers, orders, inventory with proper foreign keys and constraints. Agent writes SQL to insert orders, query history, generate reports. Most powerful option, but requires database design upfront.

**Real-world usage:** One user in the OpenClaw showcase described using Supabase + the mail-reader tool with a daily cron — the agent reads unread emails, summarizes on WhatsApp, and auto-creates todos in the database synced to their team CRM.

---

## Tier 3: Specialized Integrations (As You Scale)

Add these when specific business needs emerge:

### Payments & Invoicing

| Skill | What It Does | When to Add |
|-------|-------------|-------------|
| `stripe` (CreditClaw) | Agent wallet, payment links, purchase processing, spending guardrails | When you need to accept payments or generate invoices via the agent |
| `paperless` | Document management with OCR — search invoices, receipts by content | When paper/PDF invoices pile up and you need searchable archives |

The Stripe skill (CreditClaw) is particularly interesting for order management: it lets the agent generate Stripe payment links and send them to customers via WhatsApp. The owner sets spending limits and category blocks, and the agent operates within those guardrails.

**Security warning:** Any skill that touches money needs the strictest controls. Add to SOUL.md: *"NEVER process payments without explicit operator confirmation. NEVER modify payment amounts. Log every payment action to SYSTEM_LOG.md."* And enforce via `openclaw.json` confirmation gates.

### Marketing & Customer Communication

| Skill | What It Does | When to Add |
|-------|-------------|-------------|
| `activecampaign` | CRM integration for lead management, deal tracking, automated email sequences | When you need email marketing tied to customer segments |
| `apify-lead-generation` | Scrape Google Maps, directories for B2B/B2C leads | When you're prospecting for new customers |

### ERP (If You're Running a Real Operation)

| Skill | What It Does | When to Add |
|-------|-------------|-------------|
| `odoo-openclaw-skill` | Read-only queries into Odoo ERP: sales, invoicing, CRM, inventory, accounting. Generates WhatsApp cards, PDFs, Excel. | When you're running Odoo and want the agent to pull reports/data |

The Odoo skill is notably well-built: it's read-only by design (all mutating methods are blocked), generates reports locally, and outputs WhatsApp-formatted cards. If your business already runs on Odoo, this is a high-value integration.

### Catch-All: Zapier MCP Bridge

If your CRM or tool isn't directly supported by an OpenClaw skill, the Zapier MCP bridge connects to 8,000+ apps:

```
Composio MCP → Zapier → [HubSpot, Salesforce, Clio, Monday.com, Shopify, etc.]
```

This is the escape hatch, but it adds latency and a dependency on Zapier's infrastructure. Prefer direct skills when available.

---

## Recommended Provisioning by Business Stage

### Solo Operator, Just Starting
```
Custom Skills:
  ✅ order-processing (CSV)
  ✅ customer-lookup (CSV)
  ✅ inventory-check (inventory.md)
  ✅ order-form (WhatsApp posting)
  ✅ daily-summary (Telegram)
  ✅ weekly-report (Telegram)
  ✅ backup (git)

Community Skills:
  ✅ brave_search (market research)
  ❌ Everything else — keep it minimal

Tools (openclaw.json):
  ✅ fs (workspaceOnly: true)
  ✅ exec (approvals: true)
  ❌ browser, email, ssh, gateway_config
```

### Growing Operation (50+ orders/week, small team)
```
Everything from Solo, plus:

Data Store Migration:
  → Google Sheets OR Airtable (shared visibility)

Community Skills:
  ✅ google-sheets OR airtable-automation
  ✅ stripe (payment links, if accepting online payments)

Custom Skills:
  + Rewrite order-processing to write to Sheets/Airtable
  + Keep CSV as local backup/cache
  + Add customer-follow-up skill (re-engagement for dormant customers)
```

### Established Business (CRM, invoicing, team)
```
Everything from Growing, plus:

Data Store:
  → Supabase (full SQL) OR Odoo (if running ERP)

Community Skills:
  ✅ supabase OR odoo-openclaw-skill
  ✅ paperless (invoice/receipt management)
  ✅ activecampaign (email marketing)
  Consider: Zapier MCP bridge for unsupported tools

Multi-Agent Consideration:
  → ops-agent: orders, CRM, inventory (WhatsApp)
  → reports-agent: analytics, dashboards (Telegram)
  → research-agent: market intel, competitor monitoring (Telegram)
```

---

## Security Checklist for CRM/Order Tools

Every tool that touches customer data or financial operations needs these controls:

1. **Scoped credentials.** Google Sheets OAuth limited to specific spreadsheets. Notion integration shared with specific databases only. Stripe keys with restricted permissions.

2. **Read-before-write.** Start every new integration in read-only mode. Let the agent query data for a week before enabling writes. Watch for unexpected behavior.

3. **Confirmation gates.** Any action that modifies customer records, sends customer-facing messages, or touches payments should require operator confirmation. Configure in `AGENTS.md` and enforce in `openclaw.json`.

4. **Audit trail.** Every CRM write should be logged to `SYSTEM_LOG.md` with timestamp, action, and data changed. This is your undo mechanism.

5. **No PII in memory files.** Customer names in `customers_orders.csv` (workspace, git-backed) is fine. Customer data in `MEMORY.md` or `memory/*.md` is risky — these files are harder to audit and clean. Use memory for *preferences* ("Sarah prefers bulk orders"), not *records* ("Sarah's phone number is...").

6. **Audit community skills before installing.** The research found that 26% of audited community skills had vulnerabilities. Review the SKILL.md source, check the VirusTotal report on ClawHub, and verify the skill doesn't exfiltrate data or contain embedded prompt injections.

---

## What NOT to Install

The ClawHub registry has 5,700+ skills. Most are irrelevant to order/CRM. Resist the temptation to install broadly. Every skill costs tokens in the system prompt (even when unused) and increases attack surface.

**Skip these unless you have a specific need:**
- `browser_*` / `agent-browser` — Web browsing is a huge attack surface. The ops agent doesn't need it.
- `email_*` — The setup guide explicitly disables email. Keep it that way unless email becomes a business channel.
- `ssh_*` / `gateway_config` — Infrastructure tools. Never give these to a business operations agent.
- `food-order` — The bundled food ordering skill was removed from core in v2026.2.22. It's a consumer convenience, not a business tool.
- Any skill that requires `exec` without sandbox — If a community skill needs shell access, it should run inside the sandbox. Check `requires.bins` in the SKILL.md frontmatter.
