# Universal Skill Format Specification

A portable skill format that compiles to vendor-specific versions (Claude Code, Codex CLI, Gemini CLI) while following ALL best practices from Anthropic, PAI, and industry standards.

---

## Part 1: Core Principles

### 1.1 Concise is Key (Anthropic)

> "The context window is a public good."

Skills share context with: system prompt, conversation, other skills, user request.

**Default assumption: The AI is already smart.** Only add context it doesn't already have.

Challenge each piece:
- "Does the AI really need this explanation?"
- "Does this paragraph justify its token cost?"
- **Prefer concise examples over verbose explanations**

### 1.2 Degrees of Freedom (Anthropic)

Match specificity to task fragility:

| Freedom | When | Example |
|---------|------|---------|
| **High** (text) | Multiple approaches valid | "Summarize this document" |
| **Medium** (pseudocode) | Preferred pattern exists | "Generate report using template X" |
| **Low** (specific scripts) | Operations fragile | "Rotate PDF exactly 90 degrees" |

Think: narrow bridge needs guardrails (low freedom), open field allows routes (high freedom).

### 1.3 Progressive Disclosure (Anthropic)

Three-level loading system:

| Level | When Loaded | Size Target |
|-------|-------------|-------------|
| **Metadata** | Always | ~100 words |
| **Main body** | On trigger | <500 lines |
| **References** | On demand | Unlimited |
| **Scripts** | Execute only | 0 tokens |

### 1.4 Description is Crucial (Anthropic)

**The description is the ONLY thing that triggers a skill.**

- Body loads AFTER triggering
- "When to Use" in body is useless
- Put ALL trigger information in description
- Include: WHAT it does, WHEN to use, TRIGGERS keywords

### 1.5 Universal Portability (PAI)

- Plain markdown works with ANY AI
- No vendor lock-in in source files
- Self-contained and standalone
- Clear, predictable structure

### 1.6 Scripts Execute Without Reading (Anthropic)

Scripts provide:
- **Zero token cost** - Execute without loading
- **Deterministic reliability** - Same output every time
- **Composability** - Pipe, chain, integrate

---

## Part 2: Directory Structure

```
skills/
├── SPEC.md                      # This specification
├── build.sh                     # Build script
│
├── src/                         # GENERIC SOURCE (the truth)
│   └── <skill-name>/
│       ├── skill.md             # Main skill file
│       ├── refs/                # Progressive disclosure content
│       │   ├── detailed-topic.md
│       │   └── advanced-usage.md
│       ├── scripts/             # Executable scripts
│       │   └── main.sh
│       └── assets/              # Templates, images (output only)
│           └── template.html
│
└── dist/                        # BUILT VENDOR OUTPUT
    ├── claude/                  # → .claude/skills/
    │   └── <skill-name>/
    │       ├── SKILL.md
    │       ├── references/
    │       └── scripts/
    ├── codex/                   # → AGENTS.md sections
    │   └── <skill-name>.md
    └── gemini/                  # → GEMINI.md sections
        └── <skill-name>.md
```

---

## Part 3: Generic Skill Format (skill.md)

```markdown
# Skill Name

> **Purpose**: One-line description of what this skill does.
> **Use when**: Specific conditions that trigger this skill.
> **Triggers**: keyword1, keyword2, keyword3
> **Freedom**: high | medium | low
> **Version**: 1.0.0

## Overview

Brief context loaded by all vendors. Keep under 100 words.
Enough for AI to decide if skill applies.

## Instructions

Step-by-step guidance. Routes to refs/ for detail.

1. Understand the user's goal
2. For detailed guidance: @ref:detailed-topic
3. Execute if needed: @script:main.sh
4. For advanced cases: @ref:advanced-usage

## Quick Reference

Essential information always available:

- Key point 1
- Key point 2
- Key point 3

## Examples

### Example 1: Basic Usage
**Input**: "Do X with Y"
**Action**: Execute standard workflow
**Output**: Expected result format

### Example 2: Advanced Usage
**Input**: "Do X with Y using Z approach"
**Action**: See @ref:advanced-usage

## Variables

Optional feature flags:

- enable_feature_x: true
- default_format: json

## Anti-patterns

What NOT to do with this skill:

- Don't X when Y
- Avoid Z approach because...
```

---

## Part 4: Progressive Disclosure Markers

### Reference Markers

```markdown
For details: @ref:topic-name
```

| In Source | Claude Build | Codex/Gemini Build |
|-----------|--------------|-------------------|
| `@ref:topic` | `references/topic.md` | Content inlined |

### Script Markers

```markdown
Execute: @script:fetch.sh --arg value
```

| In Source | Claude Build | Codex/Gemini Build |
|-----------|--------------|-------------------|
| `@script:name.sh` | `scripts/name.sh` | Script block inlined |

### Inline Reference (when detail is small)

```markdown
<!-- @inline-ref:small-note -->
This small note will be kept inline for all vendors.
<!-- @end-inline-ref -->
```

---

## Part 5: Reference Files (refs/*.md)

```markdown
# Topic Name

Comprehensive documentation that would bloat main skill.

## Section 1

Detailed explanation...

## Section 2

More details...

## Examples

Specific examples for this topic...
```

**Guidelines:**
- One topic per file
- Can be loaded independently
- Should make sense without main skill.md
- Include examples specific to this topic

---

## Part 6: Script Files (scripts/*.sh)

```bash
#!/usr/bin/env bash
# scripts/fetch.sh - Brief description
# Usage: fetch.sh <arg1> [arg2]

set -euo pipefail

# Validate inputs
[[ $# -lt 1 ]] && { echo "Usage: $0 <arg>" >&2; exit 1; }

# Check dependencies
command -v curl &>/dev/null || { echo "Error: curl required" >&2; exit 1; }

# Main logic
main() {
    local arg="$1"
    # ... implementation
    echo "Result: $arg"
}

main "$@"
```

**Requirements:**
- Shebang line
- Usage comment
- Input validation
- Dependency checks
- Proper exit codes
- Output to stdout
- Errors to stderr

---

## Part 7: Build Targets

### 7.1 Claude Code

**Output Structure:**
```
.claude/skills/<name>/
├── SKILL.md              # YAML frontmatter + concise body
├── references/           # Split from refs/
├── scripts/              # Copied from scripts/
└── assets/               # Copied from assets/
```

**SKILL.md Format:**
```yaml
---
name: skill-name
description: |
  Purpose: One-line description.
  Use when: Specific conditions.
  Triggers: keyword1, keyword2, keyword3.
---

# Skill Name

## Instructions
1. Step one
2. For details, read `references/topic.md`
3. Execute `scripts/main.sh` if needed

## Quick Reference
- Point 1
- Point 2

## Examples
...
```

### 7.2 Codex CLI

**Output:** Single markdown file per skill, everything inlined.

```markdown
<!-- SKILL: skill-name -->
## Skill Name

**Purpose**: One-line description.
**Use when**: Specific conditions.
**Triggers**: keyword1, keyword2, keyword3

### Instructions

1. Step one
2. Detailed guidance:

   [Content from refs/detailed-topic.md inlined here]

3. Execute script:

   ```bash
   [Content from scripts/main.sh inlined here]
   ```

### Quick Reference
- Point 1
- Point 2

### Examples
...
<!-- END SKILL: skill-name -->
```

### 7.3 Gemini CLI

**Output:** Markdown with @import syntax for modularity.

```markdown
## Skill Name

**Purpose**: One-line description.
**Use when**: Specific conditions.

### Instructions

1. Step one
2. Detailed guidance:

@refs/detailed-topic.md

3. Execute scripts as described

### Examples
...
```

---

## Part 8: Skill Patterns

### Pattern 1: API Fetcher

```
src/api-fetcher/
├── skill.md
├── refs/
│   ├── auth-setup.md
│   └── response-handling.md
└── scripts/
    └── fetch.sh
```

### Pattern 2: Code Generator

```
src/code-gen/
├── skill.md
├── refs/
│   └── templates.md
├── scripts/
│   └── generate.sh
└── assets/
    └── template.html
```

### Pattern 3: Multi-Source Aggregator

```
src/multi-source/
├── skill.md
├── refs/
│   ├── source-a.md
│   ├── source-b.md
│   └── source-c.md
└── scripts/
    ├── fetch-a.sh
    ├── fetch-b.sh
    └── fetch-c.sh
```

### Pattern 4: Interactive Workflow

```
src/workflow/
├── skill.md
├── refs/
│   ├── step-1-gather.md
│   ├── step-2-validate.md
│   └── step-3-execute.md
└── scripts/
    └── execute.sh
```

### Pattern 5: Context Switcher

```
src/context-switch/
├── skill.md
├── refs/
│   └── switch-guide.md
└── scripts/
    ├── detect.sh
    ├── list.sh
    └── switch.sh
```

---

## Part 9: Workflow Guidelines

### Sequential Workflows

```markdown
## Process Overview

This task involves these steps:

1. Analyze input (@script:analyze.sh)
2. Transform data (@ref:transform-guide)
3. Validate output (@script:validate.sh)
4. Generate result (@script:generate.sh)
```

### Conditional Workflows

```markdown
## Workflow

1. Determine the type:
   - **Creating new?** → Follow "Creation" below
   - **Editing existing?** → Follow "Editing" below

### Creation
1. Step one
2. Step two

### Editing
1. Step one
2. Step two
```

### Domain-Specific Organization

```
src/bigquery/
├── skill.md           # Routes by domain
└── refs/
    ├── finance.md     # Revenue, billing
    ├── sales.md       # Pipeline, opportunities
    └── product.md     # Usage, features
```

---

## Part 10: Output Patterns

### Template Pattern (strict)

```markdown
## Output Format

ALWAYS use this exact structure:

# [Title]

## Summary
[One paragraph]

## Key Findings
- Finding 1
- Finding 2

## Recommendations
1. Action 1
2. Action 2
```

### Template Pattern (flexible)

```markdown
## Output Format

Sensible default, adjust as needed:

# [Title]

## Summary
[Adapt based on content]

## Details
[Structure based on findings]
```

### Examples Pattern

```markdown
## Format Examples

**Example 1:**
Input: Added authentication
Output:
feat(auth): implement JWT authentication

**Example 2:**
Input: Fixed date bug
Output:
fix(reports): correct timezone handling
```

---

## Part 11: Anti-Patterns

### What NOT to Do

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Monolithic skill.md | Too long, wastes tokens | Use refs/ for details |
| Hardcoded values | Not portable | Use env vars, config |
| No error handling | Silent failures | Check inputs, handle errors |
| Ignoring exit codes | Unreliable | Check codes, report failures |
| Complex routing | Hard to maintain | Simple routing, detail in refs/ |
| "When to use" in body | Useless (loads after trigger) | Put in description |
| README.md, CHANGELOG.md | Unnecessary for AI | Only essential files |

### What NOT to Include

- README.md
- INSTALLATION_GUIDE.md
- QUICK_REFERENCE.md
- CHANGELOG.md
- Any human-focused documentation

The skill is for AI agents, not human readers.

---

## Part 12: Build Process

### Commands

```bash
# Build all skills for all vendors
skills/build.sh

# Build specific skill
skills/build.sh skill-name

# Build for specific vendor
skills/build.sh --vendor claude skill-name
skills/build.sh --vendor codex skill-name
skills/build.sh --vendor gemini skill-name

# List available skills
skills/build.sh --list

# Validate skill format
skills/build.sh --validate skill-name
```

### Build Steps

1. **Parse** - Extract metadata from blockquote
2. **Validate** - Check required fields and structure
3. **Transform** - Apply vendor-specific transformations
4. **Split** - Separate refs/ for Claude, inline for others
5. **Generate** - Write vendor-specific output files
6. **Link** - Symlink to vendor locations

---

## Part 13: Migration Guide

### From Claude Code Skill

1. Copy SKILL.md content to `skills/src/<name>/skill.md`
2. Convert YAML frontmatter to blockquote metadata
3. Move references/ to refs/
4. Update `read references/X` to `@ref:X`
5. Run `skills/build.sh <name>`

### From PAI Pattern

1. Create `skills/src/<name>/skill.md`
2. Add metadata blockquote
3. Main pattern content → Overview + Instructions
4. Run `skills/build.sh <name>`

### From Scratch

1. Create directory: `skills/src/<name>/`
2. Write skill.md following format
3. Add refs/*.md for detailed content
4. Add scripts/*.sh for executable logic
5. Run `skills/build.sh <name>`
6. Test with each vendor

---

## Part 14: Testing Checklist

### Source Validation
- [ ] skill.md has metadata blockquote
- [ ] Purpose, Use when, Triggers all present
- [ ] Overview under 100 words
- [ ] Instructions are clear steps
- [ ] @ref markers point to existing files
- [ ] @script markers point to existing files
- [ ] Scripts are executable and have usage

### Build Validation
- [ ] Claude: SKILL.md has valid YAML frontmatter
- [ ] Claude: references/ directory populated
- [ ] Claude: scripts/ directory populated
- [ ] Codex: All content properly inlined
- [ ] Gemini: All content properly inlined

### Runtime Validation
- [ ] Skill triggers on expected phrases
- [ ] Instructions produce correct behavior
- [ ] Scripts execute successfully
- [ ] Errors handled gracefully

---

## Part 15: Quick Reference

### Minimal Skill

```markdown
# My Skill

> **Purpose**: Does X for the user.
> **Use when**: User asks to do X.
> **Triggers**: x, do-x, perform-x

## Instructions

1. Understand what X the user wants
2. Execute @script:do-x.sh with parameters
3. Return result to user

## Examples

**Input**: "Do X with foo"
**Output**: X performed on foo successfully
```

### Metadata Fields

| Field | Required | Description |
|-------|----------|-------------|
| Purpose | Yes | One-line description |
| Use when | Yes | Trigger conditions |
| Triggers | Yes | Keywords for discovery |
| Freedom | No | high/medium/low |
| Version | No | Semantic version |

### Marker Reference

| Marker | Purpose |
|--------|---------|
| `@ref:name` | Load refs/name.md |
| `@script:name.sh` | Execute scripts/name.sh |
| `<!-- @inline-ref:x -->` | Inline content block |
