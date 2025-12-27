---
name: calendar
description: |
  Manage calendars from terminal. Use when user wants to view, create, edit,
  or delete calendar events. Supports Google Calendar (gcalcli) and MS365 (thallo).
  Triggers: calendar, events, schedule, meeting, appointment, agenda, book time.
allowed-tools:
  - Bash
  - Read
---

# Calendar Management

Terminal-based calendar management.
- **Google Calendar**: [gcalcli](https://github.com/insanum/gcalcli)
- **MS365/Outlook**: [thallo](https://github.com/fjebaker/thallo)

## Variables

- default_account: (from zone config)
- agenda_days: 7
- enable_ai_scheduling: true

## Prerequisites

### Google Calendar (gcalcli)
```bash
pip install gcalcli
gcalcli init  # OAuth setup
```
See `references/gcalcli-setup.md`

### MS365 Calendar (thallo)
```bash
pip install thallo
thallo authorize  # OAuth setup
```
See `references/thallo-setup.md`

## Instructions

### View Events

Show agenda:
```bash
scripts/cal.sh agenda [--days <n>] [--account <name>]
```

List today's events:
```bash
scripts/cal.sh today [--account <name>]
```

Show specific date:
```bash
scripts/cal.sh show <date> [--account <name>]
```

### Create Events

Quick add (natural language):
```bash
scripts/cal.sh add "<description>" [--account <name>]
# e.g., "Meeting with John tomorrow at 2pm for 1 hour"
```

Detailed add:
```bash
scripts/cal.sh create --title "<title>" --start "<datetime>" --end "<datetime>" \
  [--location "<loc>"] [--description "<desc>"] [--account <name>]
```

### Edit/Delete Events

Edit event:
```bash
scripts/cal.sh edit <event-id> [--account <name>]
```

Delete event:
```bash
scripts/cal.sh delete <event-id> [--account <name>]
```

### Search Events

```bash
scripts/cal.sh search "<query>" [--account <name>]
```

## Provider Routing

The `scripts/cal.sh` wrapper detects provider:
1. Check `--account` flag
2. Check zone config for default calendar provider
3. Work zone → MS365 (thallo)
4. Personal zone → Google Calendar (gcalcli)

## Safety Rules

**NEVER delete or modify calendar events without explicit user confirmation.**

Before ANY destructive action:
1. Show the user exactly what event will be affected
2. Ask "Are you sure you want to [action]? Type 'yes' to confirm."
3. Only proceed if user explicitly confirms

Destructive actions requiring confirmation:
- `delete` - Delete calendar event
- `edit` - Modify existing event (show before/after)
- Bulk operations on multiple events

## AI Features

When user asks about calendar:
1. Show relevant events
2. Find free time slots
3. Suggest meeting times
4. Draft event descriptions
5. Check for conflicts

## Examples

**"What's on my calendar today?"**
→ `scripts/cal.sh today`

**"Show my agenda for the next week"**
→ `scripts/cal.sh agenda --days 7`

**"Schedule a meeting with Sarah tomorrow at 3pm"**
→ `scripts/cal.sh add "Meeting with Sarah tomorrow 3pm 1hr"`

**"When am I free this Friday afternoon?"**
→ Fetch Friday events, analyze gaps, report availability

**"Delete my 2pm meeting"**
→ Search for event, confirm, then delete

## Setup

For Google Calendar: `references/gcalcli-setup.md`
For MS365 Calendar: `references/thallo-setup.md`
