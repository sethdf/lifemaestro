# Ticket-Based Sessions

## Overview

Ticket sessions are specialized sessions that include issue tracker context in CLAUDE.md.

## Creation Flow

1. **Fetch ticket details**
   Use ticket-lookup skill to get:
   - Ticket ID and title
   - Status and priority
   - Full description
   - Assignee information

2. **Generate session name**
   Format: `<date>-<ticket-id>-<slug>`
   Example: `2024-12-20-SDP-12345-memory-spike`

   Slug is derived from ticket title:
   - Lowercase
   - Replace spaces with hyphens
   - Remove special characters
   - Truncate to ~30 chars

3. **Use ticket template**
   The `ticket.md` template includes:
   - Ticket reference section
   - API/system context for the ticket's domain
   - Investigation checklist
   - Safety rules for work zone

4. **Include ticket context in CLAUDE.md**
   ```markdown
   ## Ticket Reference

   **Ticket:** SDP-12345
   **Title:** Memory spike on prod-server-01
   **Status:** Open
   **Priority:** High

   ### Description
   <full ticket description>

   ### Investigation Notes
   <!-- Claude will add notes here -->
   ```

## Ticket Template Example

```markdown
# {{NAME}}

**Date:** {{DATE}}
**Zone:** {{CC_CONTEXT}}
**Engineer:** {{CC_ENGINEER}}

## Objective

Investigate and resolve ticket {{TICKET_NUM}}.

## Ticket Details

{{TICKET_DETAILS}}

## Rules

{{RULES}}

## Investigation

<!-- Document your investigation here -->

## Solution

<!-- Document the solution when found -->

## Verification

- [ ] Root cause identified
- [ ] Fix implemented
- [ ] Fix tested
- [ ] Ticket updated with resolution
```

## Automatic AWS Credential Check

For work zones, ticket sessions should verify AWS credentials before starting:

```bash
# Check if AWS creds are valid
aws sts get-caller-identity &>/dev/null || {
    echo "AWS credentials expired. Refreshing..."
    aws sso login
}
```
