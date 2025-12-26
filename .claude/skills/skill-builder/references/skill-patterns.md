# Common Skill Patterns

## Pattern 1: API Fetcher

For skills that fetch data from external APIs.

### Structure
```
.claude/skills/api-fetcher/
├── SKILL.md
├── cookbook/
│   ├── auth-setup.md
│   └── response-handling.md
└── tools/
    └── fetch.sh
```

### SKILL.md Pattern
```markdown
## Instructions
If user requests data from <API>:
1. Check credentials (read cookbook/auth-setup.md if needed)
2. Execute tools/fetch.sh with parameters
3. Format response per cookbook/response-handling.md
```

### Tool Pattern
```bash
#!/usr/bin/env bash
set -euo pipefail

# Check for required env vars
[[ -z "${API_KEY:-}" ]] && { echo "Error: API_KEY not set" >&2; exit 1; }

# Make request
curl -s -H "Authorization: Bearer $API_KEY" \
    "https://api.example.com/endpoint/$1"
```

---

## Pattern 2: Code Generator

For skills that generate code or files.

### Structure
```
.claude/skills/code-generator/
├── SKILL.md
├── cookbook/
│   └── templates.md
└── tools/
    └── generate.sh
```

### Key Principles
- Templates in cookbook, not hardcoded
- Output to stdout for piping flexibility
- Support dry-run mode

---

## Pattern 3: Multi-Source Aggregator

For skills that query multiple sources (like ticket-lookup).

### Structure
```
.claude/skills/multi-source/
├── SKILL.md
├── cookbook/
│   ├── source-a.md
│   ├── source-b.md
│   └── source-c.md
└── tools/
    ├── fetch-a.sh
    ├── fetch-b.sh
    └── fetch-c.sh
```

### SKILL.md Pattern
```markdown
## Variables
- enable_source_a: true
- enable_source_b: true
- enable_source_c: false

## Instructions
Determine which source to use based on input format:
- If matches pattern A AND enable_source_a: read cookbook/source-a.md
- If matches pattern B AND enable_source_b: read cookbook/source-b.md
```

---

## Pattern 4: Interactive Workflow

For skills that involve multi-step user interaction.

### Structure
```
.claude/skills/workflow/
├── SKILL.md
├── cookbook/
│   ├── step-1-gather.md
│   ├── step-2-validate.md
│   └── step-3-execute.md
└── tools/
    └── execute.sh
```

### Key Principles
- Each step has its own cookbook file
- Tools only execute after validation
- Clear state progression

---

## Pattern 5: Context Switcher

For skills that change environment/context (like zone-context).

### Structure
```
.claude/skills/context-switch/
├── SKILL.md
├── cookbook/
│   └── switch-guide.md
└── tools/
    ├── detect.sh
    ├── list.sh
    └── switch.sh
```

### Key Principles
- Detection tool for current state
- List tool for available options
- Switch tool outputs shell commands (eval-able)

---

## Anti-Patterns to Avoid

### 1. Monolithic SKILL.md
**Bad**: Putting all documentation in SKILL.md
**Good**: Use cookbook for details, SKILL.md for routing

### 2. Hardcoded Values
**Bad**: Hardcoding URLs, credentials, paths
**Good**: Use environment variables, config files

### 3. No Error Handling
**Bad**: Assuming everything works
**Good**: Check inputs, handle failures gracefully

### 4. Ignoring Exit Codes
**Bad**: `tool.sh || true`
**Good**: Check exit codes, report failures

### 5. Overly Complex Routing
**Bad**: 10+ conditions in SKILL.md
**Good**: Simple routing, complexity in cookbook

---

## Quick Reference

### Minimal Viable Skill
```markdown
---
name: my-skill
description: Does X. USE WHEN user asks for X.
---

# My Skill

## Instructions
Execute tools/my-skill.sh with user's input.
Return the output to the user.
```

### Tool Script Boilerplate
```bash
#!/usr/bin/env bash
set -euo pipefail

[[ $# -lt 1 ]] && { echo "Usage: $0 <arg>" >&2; exit 1; }

# Your logic here
echo "Result: $1"
```
