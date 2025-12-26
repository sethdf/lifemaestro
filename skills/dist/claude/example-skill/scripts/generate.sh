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
