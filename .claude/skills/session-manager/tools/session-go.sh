#!/usr/bin/env bash
# session-go.sh - Navigate to a session
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

search_term="${1:-}"

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

# Find all sessions
all_sessions=$(find "$sessions_base" -maxdepth 4 -name "CLAUDE.md" -type f 2>/dev/null | \
    sed "s|${sessions_base}/||" | sed 's|/CLAUDE.md||' | sort -r)

if [[ -z "$all_sessions" ]]; then
    echo "No sessions found" >&2
    exit 1
fi

session=""

if [[ -z "$search_term" ]]; then
    # Interactive selection with fzf
    if command -v fzf &>/dev/null; then
        session=$(echo "$all_sessions" | \
            fzf --preview "head -50 ${sessions_base}/{}/CLAUDE.md 2>/dev/null" \
                --preview-window=right:50% \
                --prompt="Select session: ")
    else
        echo "Sessions (use fzf for interactive selection):" >&2
        echo "$all_sessions" | head -20 >&2
        echo "" >&2
        echo "Usage: session-go.sh <partial-name>" >&2
        exit 1
    fi
else
    # Search for matching session
    session=$(echo "$all_sessions" | grep -i "$search_term" | head -1)

    if [[ -z "$session" ]]; then
        echo "No session matching '$search_term'" >&2
        echo "Available sessions:" >&2
        echo "$all_sessions" | head -10 >&2
        exit 1
    fi
fi

if [[ -n "$session" ]]; then
    session_path="${sessions_base}/${session}"

    # Detect zone from session path
    zone=$(echo "$session" | cut -d'/' -f1)

    # Switch zone context
    eval "$("$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-switch.sh" "$zone" 2>/dev/null)" || true

    echo "path: $session_path"
    echo "zone: $zone"
    echo "# Run: cd $session_path"
fi
