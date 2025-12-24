# Creating Sessions

## Overview

Sessions are date-prefixed directories in git-tracked repositories, organized by zone and category.

## Directory Structure

```
~/ai-sessions/
├── personal/
│   ├── explorations/          # Git repo: your-username/explorations
│   │   ├── 2024-12-20-rust-learning/
│   │   │   └── CLAUDE.md
│   │   └── 2024-12-19-home-automation/
│   └── learning/              # Git repo: your-username/learning
│       └── 2024-12-18-kubernetes/
└── acme-corp/
    ├── tickets/               # Git repo: your-org/work-tickets
    │   └── 2024-12-20-SDP-12345-memory-spike/
    └── explorations/          # Git repo: your-org/work-explorations
        └── 2024-12-19-terraform-migration/
```

## Creation Steps

1. **Determine zone and category**
   - Zone from `MAESTRO_ZONE` or detection
   - Category: explorations, tickets, learning, or custom

2. **Generate session name**
   - Format: `YYYY-MM-DD-<name>`
   - Name should be kebab-case, descriptive

3. **Ensure repo exists**
   - Check if category repo is cloned
   - If not, prompt to run repo-setup

4. **Apply zone configuration**
   - Switch git identity for zone
   - Set AWS profile if needed

5. **Create session directory**
   ```bash
   mkdir -p ~/ai-sessions/<zone>/<category>/<date>-<name>
   ```

6. **Generate CLAUDE.md from template**
   - Select template based on category
   - Fill in variables: name, objective, date, zone rules

7. **Git operations**
   ```bash
   cd ~/ai-sessions/<zone>/<category>
   git add <date>-<name>
   git commit -m "feat: create session <date>-<name>"
   git push
   ```

8. **Navigate to session**
   ```bash
   cd ~/ai-sessions/<zone>/<category>/<date>-<name>
   ```

## Template Variables

Templates support these placeholders:
- `{{NAME}}` - Session name
- `{{OBJECTIVE}}` - Session goal/objective
- `{{DATE}}` - Creation date
- `{{RULES}}` - Zone-specific rules
- `{{CC_ENGINEER}}` - User's name
- `{{CC_CONTEXT}}` - Zone name
- `{{TICKET_NUM}}` - Ticket number (ticket sessions)
- `{{TICKET_DETAILS}}` - Full ticket info (ticket sessions)
