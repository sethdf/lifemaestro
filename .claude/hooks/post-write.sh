#!/usr/bin/env bash
# Post-Write hook - auto-format or validate written files
# Usage: echo '{"tool_input":{"file_path":"foo.sh"}}' | post-write.sh
# Input: JSON on stdin with tool_input.file_path and tool_output
# Note: Omits -e flag for fault tolerance (jq returns 1 on invalid JSON)

set -uo pipefail

# Read input
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
[[ -z "$file_path" ]] && exit 0

# Auto-format based on extension
case "$file_path" in
    *.sh)
        # Make shell scripts executable
        [[ -f "$file_path" ]] && chmod +x "$file_path" 2>/dev/null
        ;;
    *.json)
        # Validate JSON syntax
        if [[ -f "$file_path" ]]; then
            jq empty "$file_path" 2>/dev/null || echo "Warning: Invalid JSON in $file_path" >&2
        fi
        ;;
    *.md)
        # Could add markdown linting here
        ;;
esac

exit 0
