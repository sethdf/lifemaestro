---
name: skill-selector
description: Find and select the best skill for a task from 38,000+ indexed skills. Use when you need capabilities beyond currently loaded skills, or when user asks to find a skill for something.
allowed-tools:
  - Bash
  - Read
---

# Skill Selector

Intelligent skill discovery and selection from the SkillsMP.com ecosystem.

## When to Use

Use this skill when:
1. User asks for capabilities you don't have a skill for
2. User explicitly asks to "find a skill for X"
3. You need specialized functionality (PDF, Excel, API testing, etc.)
4. User wants to see skill options before proceeding

## How It Works

The skill selector searches a local index of 38,000+ skills from SkillsMP.com, ranked by:
1. **Pinned skills** - User's preferred skills for categories
2. **Installed skills** - Already available locally
3. **Star count** - Community popularity/quality signal

## Selection Modes

Check current mode:
```bash
skills-index mode
```

- **auto** - Automatically pick the best match
- **interactive** - Show top 3 options for user to choose

## Usage

### Search for Skills
```bash
skills-index search "pdf processing"
skills-index search "api testing" --limit 5
```

### AI-Assisted Selection
```bash
skills-index select "extract tables from pdf"
```

This will:
1. Check pinned skills first
2. Search index for matches
3. Return best skill (auto) or show options (interactive)

### After Selection

If the skill isn't installed:
```bash
skills install <repo>/<path>
```

Then use the skill's instructions.

## Pinning Preferences

Users can pin preferred skills:
```bash
skills-index pin pdf anthropic:pdf
skills-index pin research pai-research
skills-index pins  # List all pins
```

When you search for "pdf", the pinned skill is returned first.

## Index Management

Update the index periodically:
```bash
skills-index update       # Quick update from known repos
skills-index update-full  # Full GitHub search (needs GITHUB_TOKEN)
skills-index stats        # Show index statistics
```

## Example Workflow

User: "I need to process a PDF and extract the tables"

You:
1. Search for relevant skills:
   ```bash
   skills-index select "pdf extract tables"
   ```

2. If not installed, install it:
   ```bash
   skills install anthropics/skills/skills/document-skills
   ```

3. Read the installed skill's SKILL.md for instructions

4. Execute the task using the skill

## Output Format

The select command returns:
```
skill: pdf
repo: anthropics/skills
path: skills/document-skills
install: skills install anthropics/skills/skills/document-skills
source: auto|interactive|pinned
```

Use this to determine next steps.
