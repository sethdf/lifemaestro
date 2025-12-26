# Format Guide

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
