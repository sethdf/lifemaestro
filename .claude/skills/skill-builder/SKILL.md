---
name: skill-builder
description: |
  Create and validate skills following the official Anthropic/agentskills.io specification.
  Use when user wants to create a new skill, build a skill, scaffold a skill, validate
  a skill, package a skill, or improve an existing skill. Triggers: create skill, new skill,
  build skill, scaffold skill, validate skill, package skill, improve skill, skill design.
---

# Skill Builder

Create skills following the official Anthropic specification (agentskills.io).

## The 6-Step Process

Follow these steps in order. Skip only when there's a clear reason.

### Step 1: Understand

Gather concrete examples of how the skill will be used.

**Questions to ask:**
- "What problem does this skill solve?"
- "Can you give examples of how it would be used?"
- "What would a user say that should trigger this skill?"
- "What functionality should it support?"

**Exit criteria:** Clear understanding of the skill's purpose and triggers.

### Step 2: Plan

Analyze examples to identify reusable resources:

| Resource | Purpose | Example |
|----------|---------|---------|
| `scripts/` | Deterministic, repeatable code | `rotate_pdf.py` |
| `references/` | Documentation loaded on demand | `api_schema.md` |
| `assets/` | Files used in output | `template.html` |

**Questions:** What code gets rewritten repeatedly? What docs would help? What templates are needed?

### Step 3: Initialize

Create the skill structure:

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

Creates:
- `SKILL.md` template with frontmatter
- Example `scripts/`, `references/`, `assets/` directories

Skip if skill already exists and you're iterating.

### Step 4: Edit

Implement the skill resources and write SKILL.md.

**For patterns and guidance:**
- Multi-step processes: See `references/workflows.md`
- Output formats: See `references/output-patterns.md`
- Design principles: See `references/skill-design.md`

**SKILL.md requirements:**
- `name`: lowercase, hyphens, max 64 chars, matches directory
- `description`: 50-1024 chars, include ALL trigger information
- Body: under 500 lines, route to references for details

**Test scripts:** Run them to verify they work standalone.

### Step 5: Package

Validate and bundle the skill:

```bash
# Quick validation
scripts/quick_validate.py <path/to/skill>

# Full validation (bash, more detailed)
scripts/validate-skill.sh <path/to/skill>

# Package for distribution
scripts/package_skill.py <path/to/skill> [output-dir]
```

Validation checks:
- Frontmatter format and required fields
- Naming conventions
- Description quality
- File organization
- Referenced files exist

Fix any errors before considering the skill complete.

### Step 6: Iterate

Improve based on real usage:

1. Use the skill on real tasks
2. Notice struggles or inefficiencies
3. Identify needed updates to SKILL.md or resources
4. Implement changes
5. Re-validate and test

## Quick Reference

**Create new skill:**
```bash
scripts/init_skill.py my-skill --path .claude/skills/
# Edit files
scripts/validate-skill.sh .claude/skills/my-skill
```

**Validate existing skill:**
```bash
scripts/validate-skill.sh path/to/skill
```

**Key principles:**
- Description triggers the skill - put ALL trigger info there
- Body only loads after triggering - "When to use" sections in body are useless
- Concise is key - only add what Claude doesn't already know
- Progressive disclosure - route to references, don't dump everything

## Examples

- "Create a skill for weather lookups" → Steps 1-5, create weather-lookup skill
- "Validate the ticket-lookup skill" → Run validate-skill.sh, report issues
- "The session skill isn't triggering" → Check description for missing triggers
- "Package the email skill" → Run package_skill.py
