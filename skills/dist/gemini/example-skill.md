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
2. For detailed explanation of the format: @format-guide.md
3. To generate sample output: 

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

4. For advanced patterns: @advanced-patterns.md

## Quick Reference

- Use `@name.md` to reference detailed documentation
- Use `` to execute scripts

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
