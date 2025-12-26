# Skill Design Guide

This guide combines LifeMaestro patterns with Anthropic's official Claude Code skill specifications.

## Official SKILL.md Format (Anthropic)

```yaml
---
name: skill-name          # Lowercase, hyphens, max 64 characters
description: |
  Detailed description of what the skill does.
  Explain when to use it and what triggers it.
allowed-tools:            # Optional: Restrict tool access
  - Read
  - Bash
  - Glob
---

# Skill Title

## Instructions
Step-by-step guidance for Claude

## Examples
Concrete use cases and sample interactions

## Version History
- v1.0.0 (date): Initial release
```

### Key Points from Official Docs
- **Skills are model-invoked** - Claude autonomously decides when to use them
- **Description is crucial** - It's how Claude discovers and matches skills
- **Multi-line descriptions** - Use `|` for detailed descriptions
- **allowed-tools** - Optional security restriction on what tools the skill can use

## Writing Good Descriptions

The description is how Claude discovers your skill. Be specific and explicit.

### Good Description
```yaml
description: |
  Analyze Excel spreadsheets, create pivot tables, and generate charts.
  Use when working with Excel files, spreadsheets, or analyzing tabular
  data in .xlsx format.
```

### Bad Description
```yaml
description: For files
```

### Description Checklist
- [ ] Explains what the skill does
- [ ] Explains when to use it (triggers)
- [ ] Mentions relevant file types or keywords
- [ ] Is specific enough to avoid false matches
- [ ] Is broad enough to catch valid use cases

## The Planning Phase

**Always begin with the end in mind.** Before writing any code:

1. **Define the Purpose**
   - What problem does this skill solve?
   - Who will use it? (human via CLI, agent, or both)
   - What's the expected output?

2. **Define the Trigger**
   - When should this skill activate?
   - What keywords or patterns indicate this skill?
   - Write clear USE WHEN conditions

3. **Define the Structure**
   - What files will be created?
   - What tools are needed?
   - What documentation goes in the cookbook?

## Skill Architecture

### Directory Structure
```
.claude/skills/<skill-name>/
├── SKILL.md              # Pivot file - routing logic (~500 tokens)
├── cookbook/             # Progressive disclosure docs
│   ├── main-use-case.md
│   └── advanced-use-case.md
└── tools/                # Executable scripts (0 tokens)
    └── <tool>.sh
```

### SKILL.md Template
```markdown
---
name: skill-name
description: One sentence. USE WHEN <specific trigger>.
---

# Skill Name

## Variables
- enable_feature_x: true

## Purpose
What this skill does (2-3 sentences).

## Instructions
If <condition> AND <variable> is true:
1. Read cookbook/<relevant>.md
2. Execute tools/<script>.sh

## Examples
- "User says X" → Do Y
```

### Token Efficiency

| Component | Token Cost | Purpose |
|-----------|------------|---------|
| SKILL.md | ~500 | Routing, always loaded |
| Cookbook | On-demand | Detailed instructions |
| Tools | 0 | Execution scripts |

**Key insight**: Only load cookbook docs when needed. Tools cost zero tokens.

## The Shared Tools Pattern

CLI and agent should share the same underlying scripts:

```
CLI: skill run fetch-data 123
        │
        └──▶ tools/fetch-data.sh ◀──┐
                                     │
Agent: "fetch data for 123"         │
        │                           │
        └──▶ SKILL.md ──▶ cookbook ─┘
```

Benefits:
- Single source of truth
- Test via CLI, use via agent
- Consistent behavior

## Variables Section

Use variables for feature toggles:

```markdown
## Variables
- enable_advanced_mode: false
- default_format: json
- max_results: 10
```

Reference in instructions:
```markdown
If user requests advanced features AND enable_advanced_mode is true:
- Read cookbook/advanced.md
```

## Progressive Disclosure

Don't dump everything into SKILL.md. Instead:

1. **SKILL.md** - Just routing logic
2. **Cookbook** - Detailed instructions per use case
3. **Tools** - Actual implementation

This keeps token usage low while providing depth when needed.

## Naming Conventions

- Skill directories: `kebab-case` (e.g., `ticket-lookup`)
- Tool scripts: `kebab-case.sh` (e.g., `fetch-ticket.sh`)
- Cookbook files: `kebab-case.md` (e.g., `jira-lookup.md`)
- Variables: `snake_case` (e.g., `enable_jira`)

## Testing Checklist

Before considering a skill complete:

- [ ] SKILL.md has clear USE WHEN trigger
- [ ] Tools are executable and work standalone
- [ ] Cookbook provides enough detail
- [ ] CLI invocation works: `skill run <name> <args>`
- [ ] Agent understands when to use it
- [ ] Error handling is graceful
