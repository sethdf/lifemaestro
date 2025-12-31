# Skill Design Guide

This guide incorporates official Anthropic skill specifications from github.com/anthropics/skills.

## Core Principles (Official Anthropic)

### 1. Concise is Key

> "The context window is a public good."

Skills share the context window with everything else: system prompt, conversation history, other skills, and the user's request.

**Default assumption: Claude is already very smart.** Only add context Claude doesn't already have.

Challenge each piece of information:
- "Does Claude really need this explanation?"
- "Does this paragraph justify its token cost?"

**Prefer concise examples over verbose explanations.**

### 2. Degrees of Freedom

Match the level of specificity to the task's fragility:

| Freedom Level | When to Use | Example |
|--------------|-------------|---------|
| **High** (text instructions) | Multiple approaches valid, context-dependent | "Summarize this document" |
| **Medium** (pseudocode/scripts with params) | Preferred pattern exists, some variation OK | "Generate report using template X" |
| **Low** (specific scripts, few params) | Operations fragile, consistency critical | "Rotate PDF exactly 90 degrees" |

Think of Claude navigating a path: narrow bridge needs guardrails (low freedom), open field allows many routes (high freedom).

### 3. Progressive Disclosure

Skills use a three-level loading system:

| Level | When Loaded | Size Target |
|-------|-------------|-------------|
| **Metadata** (name + description) | Always in context | ~100 words |
| **SKILL.md body** | When skill triggers | <5k words, ideally <500 lines |
| **Bundled resources** | As needed by Claude | Unlimited (scripts execute without reading) |

## Official Skill Structure

```
skill-name/
├── SKILL.md              # Required - routing and instructions
├── scripts/              # Executable code (Python/Bash/etc.)
│   └── my-script.sh
├── references/           # Documentation loaded as needed
│   └── detailed-guide.md
└── assets/               # Files used in output (templates, images)
    └── template.pptx
```

### SKILL.md Format

```yaml
---
name: skill-name              # Lowercase, hyphens, max 64 chars
description: |
  What this skill does in detail.
  Use when <specific triggers>.
  Triggers: <keyword list>.
---

# Skill Name

## Instructions
Step-by-step guidance...

## Examples
Input/output pairs...

## Version History
- v1.0.0 (date): Initial release
```

### Bundled Resources

#### scripts/
Executable code for tasks requiring deterministic reliability.

**When to include:**
- Same code being rewritten repeatedly
- Deterministic reliability needed
- Complex operations that are error-prone

**Benefits:** Token efficient, deterministic, can execute without loading into context.

#### references/
Documentation loaded as needed to inform Claude's process.

**When to include:**
- Domain-specific knowledge
- API documentation
- Detailed workflow guides
- Company policies or schemas

**Best practices:**
- If files are large (>10k words), include grep patterns in SKILL.md
- Information should live in EITHER SKILL.md OR references, not both
- Keep SKILL.md lean; move details to references

#### assets/
Files used in output, NOT loaded into context.

**When to include:**
- Templates (PowerPoint, HTML)
- Images, icons, fonts
- Boilerplate code
- Sample documents

## Writing Good Descriptions

The description is how Claude discovers your skill. **This is crucial.**

### Good Description
```yaml
description: |
  Analyze Excel spreadsheets, create pivot tables, and generate charts.
  Use when working with Excel files, spreadsheets, or analyzing tabular
  data in .xlsx format. Triggers: excel, spreadsheet, xlsx, pivot table.
```

### Bad Description
```yaml
description: For files
```

### Description Rules
- Include WHAT the skill does
- Include WHEN to use it (triggers)
- Put ALL trigger information in description, NOT in body
- Body only loads AFTER triggering, so "When to Use" sections in body are useless

## What NOT to Include

A skill should only contain essential files. Do NOT create:

- README.md
- INSTALLATION_GUIDE.md
- QUICK_REFERENCE.md
- CHANGELOG.md
- Any auxiliary documentation

The skill is for an AI agent, not human documentation.

## Skill Creation Process (Official Anthropic 6 Steps)

1. **Understand** - Gather concrete examples of how the skill will be used
2. **Plan** - Identify reusable scripts, references, assets needed
3. **Initialize** - Run `init_skill.py` to create directory structure
4. **Edit** - Implement resources and write SKILL.md
5. **Package** - Run `package_skill.py` to validate and bundle
6. **Iterate** - Improve based on real usage

## Skill Validation

Before considering a skill complete, validate it:

```bash
# Quick Python validation
scripts/quick_validate.py path/to/skill

# Detailed bash validation
scripts/validate-skill.sh path/to/skill

# Package for distribution
scripts/package_skill.py path/to/skill
```

### What Validation Checks

- SKILL.md exists with valid frontmatter
- `name` field: lowercase, hyphens, max 64 chars, matches directory
- `description` field: 50-1024 chars, contains trigger info
- Body under 500 lines
- All referenced files exist
- No prohibited files (README.md, CHANGELOG.md, etc.)
