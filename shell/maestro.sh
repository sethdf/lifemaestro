#!/usr/bin/env bash
# Shell functions for LifeMaestro
# Source this file in your .bashrc or .zshrc:
#   source ~/.config/lifemaestro/shell/maestro.sh

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"

# Validate zone name (alphanumeric, dash, underscore only)
_maestro_validate_zone() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid zone name '$name'. Use only letters, numbers, dash, underscore." >&2
        return 1
    fi
    return 0
}

# Zone apply - actually switches zone in current shell
zone() {
    local cmd="${1:-current}"

    case "$cmd" in
        apply|a)
            shift
            local zone_name="${1:-}"
            if [[ -z "$zone_name" ]]; then
                echo "Usage: zone apply <zone-name>" >&2
                return 1
            fi
            # Validate zone name before eval (security)
            _maestro_validate_zone "$zone_name" || return 1
            # Eval the output directly in current shell
            eval "$("$MAESTRO_ROOT/.claude/skills/zone-context/scripts/zone-switch.sh" "$zone_name")"
            echo "Switched to zone: $zone_name"
            ;;
        *)
            # Delegate to bin/zone for other commands
            "$MAESTRO_ROOT/bin/zone" "$@"
            ;;
    esac
}

# Session go - cd to selected session (needs to be a function to change directory)
session() {
    local cmd="${1:-status}"

    case "$cmd" in
        go|g)
            shift
            local zone="${1:-}"
            local base="${SESSIONS_BASE:-$HOME/ai-sessions}"

            if ! command -v fzf &>/dev/null; then
                echo "Error: fzf required for session picker" >&2
                return 1
            fi

            local sessions
            if [[ -n "$zone" ]]; then
                sessions=$(find "$base/$zone" -maxdepth 2 -type d -name ".git" 2>/dev/null | \
                    xargs -I{} dirname {} | \
                    sed "s|$base/||")
            else
                sessions=$(find "$base" -maxdepth 3 -type d -name ".git" 2>/dev/null | \
                    xargs -I{} dirname {} | \
                    sed "s|$base/||")
            fi

            local selected
            selected=$(echo "$sessions" | fzf --prompt="Session: ")

            if [[ -n "$selected" ]]; then
                local selected_zone
                selected_zone=$(echo "$selected" | cut -d'/' -f1)
                zone apply "$selected_zone"
                cd "$base/$selected"
                echo "Switched to: $selected"
            fi
            ;;
        *)
            # Delegate to bin/session for other commands
            "$MAESTRO_ROOT/bin/session" "$@"
            ;;
    esac
}
