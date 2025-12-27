---
name: repo-setup
description: Set up GitHub repositories for Claude Code sessions. Use when user wants to create a new project, initialize session repos, or set up GitHub repos.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Repository Setup

Creates and configures GitHub repositories for Claude Code sessions and standalone projects.

## Variables

- enable_repo_create: true
- enable_session_repos: true
- enable_standalone_projects: true
- default_visibility: private

## Instructions

### Creating Session Repositories

If user wants to set up session repositories for a zone:
1. Detect current zone or ask which zone
2. Read references/session-repos.md for the setup procedure
3. Run `scripts/setup-session-repos.sh <zone>`

This creates the category repositories (tickets, explorations, learning) for the zone.

### Creating Standalone Project Repos

If user wants to create a new project (ccnew equivalent):
1. Ask for project name and zone
2. Read references/new-project.md for creation steps
3. Run `scripts/new-project.sh <name> <zone>`

### Repository Configuration

All repos are configured with:
- Correct SSH host from zone config (for multiple GitHub accounts)
- Private visibility by default
- Initial CLAUDE.md with zone rules

## GitHub SSH Configuration

For multiple GitHub accounts, repos use SSH host aliases:
- `github.com-work` for work account
- `github.com-home` for personal account

These must be configured in `~/.ssh/config`.

## Example Usage

```
User: "Set up my session repos for work"
-> Run setup-session-repos.sh acme-corp

User: "Create a new project called api-gateway"
-> Ask zone, run new-project.sh api-gateway acme-corp

User: "I need to create a learning repo for my personal account"
-> Run setup-session-repos.sh personal (creates learning repo if missing)
```
