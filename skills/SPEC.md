# LifeMaestro Skills

Skills follow the [agentskills.io](https://agentskills.io) specification.

## Quick Reference

```yaml
---
name: my-skill                    # Lowercase, hyphens, max 64 chars
description: |                    # CRUCIAL - triggers skill loading
  What this does.
  Use when: <conditions>.
  Triggers: keyword1, keyword2.
allowed-tools:                    # Optional - restrict tool access
  - Read
  - Bash
---

# Skill Title

## Instructions
1. Step one
2. Read `references/topic.md` for details
3. Execute `scripts/action.sh`

## Examples
**Input**: "Do X"
**Action**: Execute workflow
```

## Directory Structure

```
.claude/skills/<name>/
├── SKILL.md          # Required
├── references/       # Detailed docs (loaded on demand)
├── scripts/          # Executable code (zero tokens)
└── assets/           # Templates, images (for output)
```

## LifeMaestro Patterns

### Zone-Aware Skills

Check zone features before executing:
```markdown
If ticket is Jira type AND zone has `features.jira = true`:
  Read references/jira-lookup.md
```

### Variables Section

Enable/disable features per skill:
```markdown
## Variables
- enable_feature_x: true
- default_format: json
```

### Shared Scripts

Skills and CLI share the same scripts:
```
.claude/skills/ticket-lookup/scripts/fetch.sh
bin/ticket  →  calls same script
```

## Vendor Skills

Symlinked from `vendor/` with prefixes:
- `pai-*` from PAI (danielmiessler/Personal_AI_Infrastructure)
- `anthropic-*` from Anthropic (anthropics/skills)

Update with: `vendor/sync.sh update`

## Key Principles

1. **Description is crucial** - Only thing that triggers the skill
2. **Keep SKILL.md < 500 lines** - Route to references/
3. **Scripts = zero tokens** - Execute without reading
4. **No auxiliary files** - Skip README.md, CHANGELOG.md
