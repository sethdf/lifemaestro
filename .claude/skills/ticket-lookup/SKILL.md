---
name: ticket-lookup
description: Look up ticket details from issue trackers. Use when user mentions a ticket number, issue, or wants to start work on a ticket (SDP, Jira, Linear, GitHub Issues).
allowed-tools:
  - Bash
  - Read
  - WebFetch
---

# Ticket Lookup

Fetches ticket details from various issue tracking systems based on the current zone's enabled features.

## Variables

- enable_sdp: true
- enable_jira: true
- enable_linear: true
- enable_github_issues: true
- enable_azure_devops: true
- auto_detect_ticket_type: true

## Instructions

### Ticket Detection

When user mentions a ticket:

1. First, detect current zone: run `scripts/zone-detect.sh` (from zone-context skill)
2. Check which ticket features are enabled for the zone
3. Parse the ticket reference to determine type:
   - `SDP-12345` or just `12345` in SDP-enabled zone -> ServiceDesk Plus
   - `ADO-12345` or work item ID in Azure DevOps zone -> Azure DevOps
   - `PROJ-123` pattern -> Jira
   - `LIN-abc123` or Linear URL -> Linear
   - `#123` or `owner/repo#123` -> GitHub Issues

### Fetching Ticket Details

If ticket is SDP type AND zone has `features.sdp = true`:
- Read references/sdp-lookup.md for API details
- Run `scripts/sdp-fetch.sh <ticket-number>`

If ticket is Azure DevOps type AND zone has `features.azure_devops = true`:
- Read references/azuredevops-lookup.md for API details
- Run `scripts/azuredevops-fetch.sh <work-item-id>`

If ticket is Jira type AND zone has `features.jira = true`:
- Read references/jira-lookup.md for API details
- Run `scripts/jira-fetch.sh <ticket-key>`

If ticket is Linear type AND zone has `features.linear = true`:
- Read references/linear-lookup.md for API details
- Run `scripts/linear-fetch.sh <issue-id>`

If ticket is GitHub Issue AND zone has `features.github_issues = true`:
- Read references/github-issues-lookup.md for API details
- Run `scripts/github-fetch.sh <owner> <repo> <issue-number>`

### Creating Sessions from Tickets

If user wants to start work on a ticket:
1. Fetch ticket details using appropriate tool above
2. Use session-manager skill to create a session with ticket context
3. Include ticket details in the session's CLAUDE.md

## Output Format

Ticket lookup returns structured data:
```
ticket_id: <id>
title: <subject/title>
status: <current status>
priority: <priority level>
assignee: <assigned user>
description: |
  <full description>
comments: <comment count>
```

## Error Handling

- If API key missing: Report which environment variable is needed
- If zone doesn't have feature enabled: Suggest enabling in config.toml
- If ticket not found: Report 404 and suggest checking ticket number
