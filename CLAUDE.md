# LifeMaestro Development Guide

This file contains principles and guidelines for AI agents working on LifeMaestro.

## Core Philosophy

**Begin with the end in mind.** Before writing any code or prompts:
1. Define the **purpose** - What problem are we solving?
2. Define the **deliverable** - What concrete outputs will exist when done?
3. Define the **structure** - What files/directories will be created?

## Skill Development Principles

### The Core Four
Every skill ultimately boils down to:
- **Context** - What information does the agent need?
- **Model** - Which AI model runs this?
- **Prompt** - What instructions guide the agent?
- **Tools** - What scripts/commands extend capability?

### Skill Directory Structure
```
.claude/skills/<skill-name>/
├── SKILL.md              # Pivot file - central routing and instructions
├── tools/                # Executable scripts (zero tokens until invoked)
│   └── <tool>.sh
├── cookbook/             # Progressive disclosure documentation
│   └── <use-case>.md
└── prompts/              # Reusable prompt templates (optional)
    └── <prompt>.md
```

### SKILL.md Structure (Official Anthropic Format)
```markdown
---
name: skill-name              # Lowercase, hyphens, max 64 chars
description: |
  What this skill does in detail.
  Use when <trigger conditions>.
  Handles <specific use cases>.
allowed-tools:                # Optional: restrict tool access
  - Read
  - Bash
  - Glob
---

# Skill Name

## Variables
- enable_feature_x: true/false

## Instructions
Step-by-step guidance for Claude:
1. First step
2. Second step
3. Execute tools/<script>.sh

## Examples

### Example 1
**User**: "Do X with Y"
**Action**: Execute tool with parameters

## Version History
- v1.0.0 (date): Initial release
```

### Key Official Guidelines
- **Skills are model-invoked** - Claude decides when to use them based on description
- **Description is crucial** - Be specific about what triggers the skill
- **allowed-tools** - Optional security to restrict what the skill can do
- **Version History** - Track changes for team collaboration

### Progressive Disclosure
Don't dump everything into context. Instead:
1. SKILL.md provides **routing logic** (~500 tokens)
2. Cookbook files are read **only when needed**
3. Tools execute **with zero token cost**

### Variables Section
Use variables to enable/disable features:
```markdown
## Variables
- enable_sdp: true
- enable_jira: false
- default_model: sonnet
```

## Development Workflow

### 1. Plan First
Never start by blasting out prompts. Think through:
- What's the purpose/problem/solution?
- What's the file structure?
- What's the simplest working version?

### 2. Start Simple
- Aim for **proof of concept** first
- Get the simplest version working
- Then iterate and improve

### 3. Test In The Loop
- Write the prompt
- Observe the result
- Encode learnings in the skill

### 4. Use Information-Dense Keywords
Specific keywords carry embedded meaning:
- "Astral UV single file script" → implies Python, uv runner, inline deps
- "12-Factor CLI" → implies stdout/stderr, exit codes, composability
- "subprocess" → implies shell execution patterns

### 5. Fresh Context Windows
- Don't be afraid to start fresh
- Focused agents with clean context perform better
- Fork work to parallel agents when appropriate

## Debugging Principles

**Blame yourself first:**
1. Check your prompts and instructions
2. Check your skill routing logic
3. Check your tool scripts
4. Only then consider model limitations

## LifeMaestro-Specific Patterns

### Zones (not Contexts)
LifeMaestro uses **zones** for flexible namespaces:
- `zones.<name>.git` - Git identity
- `zones.<name>.aws` - AWS profile
- `zones.<name>.features` - Enabled features

### Shared Tools Pattern
CLI commands and Claude Code skills share the same underlying scripts:
```
CLI: ticket sdp 12345
        │
        └──▶ tools/sdp-fetch.sh ◀──┐
                                    │
Agent: "fetch that SDP ticket"     │
        │                          │
        └──▶ SKILL.md ──▶ cookbook ─┘
```

### Token Efficiency
- SKILL.md for routing (~500 tokens)
- Cookbook for detailed docs (loaded on demand)
- Tools for execution (0 tokens)

## When Creating New Skills

1. **Define the trigger** - When should this skill activate?
2. **Define the tools** - What scripts need to exist?
3. **Define the cookbook** - What use-case docs are needed?
4. **Write SKILL.md** - Route to the right cookbook/tool
5. **Test iteratively** - Start simple, observe, improve

## References

- `DESIGN.md` - Full architecture documentation
- `vendor/pai/` - PAI patterns and skills for inspiration
- `.claude/skills/` - Existing LifeMaestro skills
