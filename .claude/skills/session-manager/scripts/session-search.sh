#!/usr/bin/env bash
# session-search.sh - Search sessions by content
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

query="${1:-}"

if [[ -z "$query" ]]; then
    echo "Usage: session-search.sh <query>" >&2
    exit 1
fi

# Get sessions base directory
sessions_base="${HOME}/ai-sessions"
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    sessions_base=$(dasel -f "$MAESTRO_CONFIG" -r toml 'sessions.base_dir' 2>/dev/null || echo "$sessions_base")
    sessions_base="${sessions_base/#\~/$HOME}"
fi

if [[ ! -d "$sessions_base" ]]; then
    echo "No sessions directory found at $sessions_base" >&2
    exit 1
fi

echo "Searching for: $query"
echo "================"

# Search in session names
echo ""
echo "By Name:"
find "$sessions_base" -maxdepth 4 -name "CLAUDE.md" -type f 2>/dev/null | \
    while read -r claude_file; do
        session_dir=$(dirname "$claude_file")
        session_path="${session_dir#$sessions_base/}"

        if echo "$session_path" | grep -qi "$query"; then
            echo "  $session_path"
        fi
    done | head -10

# Search in CLAUDE.md content
echo ""
echo "By Content:"
grep -r -l -i "$query" "$sessions_base"/*/*/CLAUDE.md 2>/dev/null | \
    while read -r claude_file; do
        session_dir=$(dirname "$claude_file")
        session_path="${session_dir#$sessions_base/}"

        # Get matching line for context
        match=$(grep -i -m1 "$query" "$claude_file" 2>/dev/null | head -c 80)

        echo "  $session_path"
        echo "    ...${match}..."
    done | head -20
