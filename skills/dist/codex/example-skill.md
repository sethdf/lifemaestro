<!-- SKILL: example-skill -->
## Example Skill

**Purpose**: Demonstrates the universal skill format with progressive disclosure.
**Use when**: User asks for an example or wants to test skill building.
**Triggers**: example, demo, test-skill, sample

# Example Skill

> **Purpose**: Demonstrates the universal skill format with progressive disclosure.
> **Use when**: User asks for an example or wants to test skill building.
> **Triggers**: example, demo, test-skill, sample
> **Freedom**: high
> **Version**: 1.0.0

## Overview

This skill demonstrates the universal format that builds to Claude Code, Codex CLI, and Gemini CLI. It shows how to use reference markers and script markers for progressive disclosure.

## Instructions

1. Understand what the user wants to demonstrate
2. For detailed explanation of the format: 

#### format-guide


Detailed explanation of the universal skill format.

## Metadata Blockquote

Every skill.md starts with a blockquote containing metadata:

```markdown
> **Purpose**: What this skill does.
> **Use when**: Trigger conditions.
> **Triggers**: keyword1, keyword2
> **Freedom**: high | medium | low
> **Version**: 1.0.0
```

## Required Fields

| Field | Description |
|-------|-------------|
| Purpose | One-line description of skill capability |
| Use when | Conditions that should trigger this skill |
| Triggers | Keywords for discovery |

## Optional Fields

| Field | Description |
|-------|-------------|
| Freedom | How much latitude the AI has (high/medium/low) |
| Version | Semantic version for tracking changes |

## Section Structure

1. **Overview** - Brief context (under 100 words)
2. **Instructions** - Step-by-step guidance with @ref and @script markers
3. **Quick Reference** - Essential info always available
4. **Examples** - Input/output pairs
5. **Variables** - Optional feature flags
6. **Anti-patterns** - What to avoid

## Progressive Disclosure Markers

Use these markers to reference external content:

- `@ref:name` - References refs/name.md
- `@script:name.sh` - References scripts/name.sh

The build system transforms these appropriately for each vendor.

3. To generate sample output: `generate.sh`

```bash
#!/usr/bin/env bash
# scripts/generate.sh - Generate sample output for example skill
# Usage: generate.sh [format]

set -euo pipefail

format="${1:-text}"

case "$format" in
    json)
        cat <<EOF
{
  "skill": "example-skill",
  "status": "success",
  "message": "Sample output generated successfully",
  "format": "json"
}
EOF
        ;;
    text|*)
        cat <<EOF
=== Example Skill Output ===

This is sample output from the example skill.

The universal skill format allows:
- Generic markdown source files
- Progressive disclosure via refs/
- Executable scripts in scripts/
- Build to multiple vendors

Vendors supported:
- Claude Code (.claude/skills/)
- Codex CLI (AGENTS.md)
- Gemini CLI (GEMINI.md)

=== End Output ===
EOF
        ;;
esac
```

4. For advanced patterns: 

#### advanced-patterns


Advanced usage patterns for the universal skill format.

## Multi-Source Aggregator

When a skill needs to query multiple data sources:

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

## Conditional Workflows

Route based on user intent:

```markdown
## Instructions

1. Determine the type:
   - **Creating new?** → See @ref:create-workflow
   - **Editing existing?** → See @ref:edit-workflow
```

## Domain-Specific Organization

For skills covering multiple domains:

```
src/analytics/
├── skill.md
└── refs/
    ├── finance.md
    ├── sales.md
    └── product.md
```

The main skill.md routes to the appropriate domain based on user query.

## Variables for Feature Flags

Use variables to enable/disable features:

```markdown
## Variables

- enable_experimental: false
- default_format: json
- max_results: 100
```

Check these in your instructions to conditionally include guidance.


## Quick Reference

- Use `` to reference detailed documentation

#### name


- Use ``name.sh`` to execute scripts

```bash
```

- Keep this section under 500 lines
- Put detailed content in refs/

## Examples

### Example 1: Basic Demo
**Input**: "Show me an example skill"
**Action**: Display this skill's structure and explain the format
**Output**: Explanation of universal skill format

### Example 2: Build Demo
**Input**: "Build this skill for Claude"
**Action**: Run `skills/build.sh --vendor claude example-skill`
**Output**: Generated SKILL.md with YAML frontmatter

## Variables

- demo_mode: true
- verbose_output: false

## Anti-patterns

- Don't put detailed documentation in the main skill.md
- Don't hardcode vendor-specific syntax in source
- Don't skip the metadata blockquote
<!-- END SKILL: example-skill -->
