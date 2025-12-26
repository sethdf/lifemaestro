---
name: session-manager
description: Manage Claude Code sessions. Use when user wants to create a new session, list sessions, start work on a ticket, or switch to an existing session.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Session Manager

Sessions are git-tracked working directories with CLAUDE.md files for Claude Code projects. Each session belongs to a zone and category (explorations, tickets, learning).

## Variables

- enable_session_create: true
- enable_session_list: true
- enable_session_navigate: true
- enable_ticket_sessions: true
- sessions_base_dir: ~/ai-sessions

## Instructions

### Creating Sessions

If user wants to create a new session or start a new project:
1. Detect current zone using zone-context skill
2. Read references/session-create.md for creation procedure
3. Ask user for: session name, category (exploration/ticket/learning), and objective
4. Run `tools/session-create.sh <zone> <category> <name> [objective]`

If user wants to start work on a ticket:
1. First use ticket-lookup skill to fetch ticket details
2. Read references/ticket-session.md for ticket-specific session setup
3. Run `tools/session-create.sh <zone> tickets <ticket-id>-<slug>` with ticket context

### Listing Sessions

If user wants to list or find sessions:
- Run `tools/session-list.sh [zone] [category]`
- Supports filtering by zone and category

If user wants to search sessions:
- Run `tools/session-search.sh <query>`
- Searches session names and CLAUDE.md content

### Navigating Sessions

If user wants to go to or switch to a session:
- Run `tools/session-go.sh` for interactive selection (requires fzf)
- Or `tools/session-go.sh <partial-name>` for direct navigation

### Session Structure

Each session creates:
```
~/ai-sessions/<zone>/<category-repo>/<date>-<name>/
├── CLAUDE.md    # Session context and rules
└── ...          # Project files
```

Sessions are git-tracked in per-zone, per-category repositories.

## Session Templates

Templates are in `~/.config/lifemaestro/templates/`:
- `exploration.md` - Open-ended investigation
- `ticket.md` - Ticket-based work with issue details
- `learning.md` - Learning and tutorial sessions
- `investigation.md` - Technical deep-dives

## Example Usage

```
User: "Create a new session for exploring Terraform"
-> Create exploration session in current zone

User: "Start work on SDP-12345"
-> Fetch ticket, create ticket session with context

User: "List my recent sessions"
-> Run session-list for current zone

User: "Go to the session about Redis caching"
-> Run session-search "redis caching", then navigate
```
