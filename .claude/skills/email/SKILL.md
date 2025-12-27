---
name: email
description: |
  Manage email from terminal using himalaya. Use when user wants to read, send,
  search, delete, or compose emails. Supports Gmail and MS365/Outlook.
  Triggers: email, mail, inbox, send email, check mail, compose, reply.
allowed-tools:
  - Bash
  - Read
---

# Email Management

Terminal-based email using [himalaya](https://github.com/pimalaya/himalaya).
Provider-agnostic - works with Gmail and MS365/Outlook.

## Variables

- default_account: (from zone config)
- list_limit: 20
- enable_ai_summary: true

## Prerequisites

Install himalaya:
```bash
# macOS
brew install himalaya

# Linux (cargo)
cargo install himalaya

# Or download binary from releases
```

Configure accounts - see `references/himalaya-setup.md`

## Instructions

### List/Read Emails

List recent emails:
```bash
scripts/mail.sh list [--account <name>] [--folder <folder>] [--limit <n>]
```

Read specific email:
```bash
scripts/mail.sh read <id> [--account <name>]
```

### Search Emails

```bash
scripts/mail.sh search "<query>" [--account <name>] [--folder <folder>]
```

### Compose/Send

Compose new email:
```bash
scripts/mail.sh compose [--account <name>] [--to <email>] [--subject <subj>]
```

Reply to email:
```bash
scripts/mail.sh reply <id> [--account <name>]
```

Forward email:
```bash
scripts/mail.sh forward <id> [--account <name>] [--to <email>]
```

### Manage Emails

Move email:
```bash
scripts/mail.sh move <id> <folder> [--account <name>]
```

Delete email:
```bash
scripts/mail.sh delete <id> [--account <name>]
```

Mark as read/unread:
```bash
scripts/mail.sh mark <id> --read|--unread [--account <name>]
```

### List Folders

```bash
scripts/mail.sh folders [--account <name>]
```

## Safety Rules

**NEVER delete or move emails without explicit user confirmation.**

Before ANY destructive action:
1. Show the user exactly what will be affected
2. Ask "Are you sure you want to [action]? Type 'yes' to confirm."
3. Only proceed if user explicitly confirms

Destructive actions requiring confirmation:
- `delete` - Permanently delete email
- `move` - Move email to folder (could lose it)
- Bulk operations on multiple emails

## AI Features

When user asks about emails:
1. List/search relevant emails
2. Summarize contents if requested
3. Draft replies based on context
4. Suggest actions (archive, reply, delegate)

## Account Selection

If no account specified:
1. Check zone config for default email provider
2. Work zone → MS365 account
3. Personal zone → Gmail account

## Examples

**"Check my inbox"**
→ `scripts/mail.sh list --limit 10`

**"Search for emails from John about the budget"**
→ `scripts/mail.sh search "from:john subject:budget"`

**"Reply to the latest email from Sarah"**
→ Find email, then `scripts/mail.sh reply <id>`

**"Delete all emails from newsletters"**
→ Search, confirm with user, then batch delete

## Setup

For Gmail setup: `references/himalaya-gmail.md`
For MS365 setup: `references/himalaya-ms365.md`
