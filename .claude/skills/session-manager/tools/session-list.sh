#!/usr/bin/env bash
# session-list.sh - List Claude Code sessions
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

zone_filter="${1:-all}"
category_filter="${2:-all}"
limit="${3:-20}"

# Get sessions base directory
sessions_base="${HOME}/ai-sessions"
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    sessions_base=$(dasel -f "$MAESTRO_CONFIG" -r toml 'sessions.base_dir' 2>/dev/null || echo "$sessions_base")
    sessions_base="${sessions_base/#\~/$HOME}"
fi

if [[ ! -d "$sessions_base" ]]; then
    echo "No sessions directory found at $sessions_base" >&2
    exit 0
fi

echo "Sessions:"
echo "========="

# Get list of zones to search
zones=()
if [[ "$zone_filter" == "all" ]]; then
    # Get all zone directories
    if [[ -d "$sessions_base" ]]; then
        for zone_dir in "$sessions_base"/*/; do
            [[ -d "$zone_dir" ]] && zones+=("$(basename "$zone_dir")")
        done
    fi
else
    zones=("$zone_filter")
fi

for zone in "${zones[@]}"; do
    zone_path="$sessions_base/$zone"
    [[ -d "$zone_path" ]] || continue

    echo ""
    echo "[$zone]"

    # Find all sessions with CLAUDE.md
    find "$zone_path" -maxdepth 3 -name "CLAUDE.md" -type f 2>/dev/null | \
        while read -r claude_file; do
            session_dir=$(dirname "$claude_file")
            session_name=$(basename "$session_dir")
            category=$(basename "$(dirname "$session_dir")")

            # Apply category filter
            if [[ "$category_filter" != "all" ]] && [[ "$category" != "$category_filter" ]]; then
                continue
            fi

            # Check if session is completed
            completed=""
            if grep -q "Session Completed" "$claude_file" 2>/dev/null; then
                completed=" [done]"
            fi

            echo "  $category/$session_name$completed"
        done | sort -r | head -n "$limit"
done

# Show current zone
echo ""
echo "Current Zone:"
"$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" 2>/dev/null | grep "^zone:" | sed 's/^/  /'
