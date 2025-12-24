#!/usr/bin/env bash
# lifemaestro/core/utils.sh - Shared utilities
#
# NOTE: For CLI I/O (stdout/stderr, colors, exit codes), see cli.sh
# This file contains general-purpose utilities.

# ============================================
# STRING UTILITIES
# ============================================

utils::trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

utils::slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-_'
}

utils::timestamp() {
    date '+%Y-%m-%d_%H-%M-%S'
}

utils::date_iso() {
    date '+%Y-%m-%d'
}

# ============================================
# PATH UTILITIES
# ============================================

utils::ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

utils::realpath() {
    local path="$1"
    if command -v realpath &>/dev/null; then
        realpath "$path"
    else
        cd "$(dirname "$path")" && echo "$(pwd)/$(basename "$path")"
    fi
}

# ============================================
# JSON UTILITIES
# ============================================

utils::json_get() {
    local json="$1"
    local key="$2"
    echo "$json" | jq -r ".$key // empty"
}

utils::json_array() {
    local json="$1"
    echo "$json" | jq -r '.[]'
}

# ============================================
# VALIDATION
# ============================================

utils::require_command() {
    local cmd="$1"
    local msg="${2:-Command '$cmd' is required but not installed}"

    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $msg" >&2
        return 1
    fi
}

utils::require_env() {
    local var="$1"
    local msg="${2:-Environment variable '$var' is required but not set}"

    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: $msg" >&2
        return 1
    fi
}

utils::require_file() {
    local file="$1"
    local msg="${2:-File '$file' is required but not found}"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: $msg" >&2
        return 1
    fi
}

# ============================================
# NOTIFICATIONS
# ============================================

utils::notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"  # low, normal, critical

    # Linux (notify-send)
    if command -v notify-send &>/dev/null; then
        notify-send -u "$urgency" "$title" "$message"
        return
    fi

    # macOS (osascript)
    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\""
        return
    fi

    # Termux
    if command -v termux-notification &>/dev/null; then
        termux-notification --title "$title" --content "$message"
        return
    fi

    # Fallback: just echo
    echo "[$title] $message"
}

# ============================================
# DURATION FORMATTING
# ============================================

utils::format_duration() {
    local seconds="$1"

    if [[ "$seconds" -lt 0 ]]; then
        echo "expired"
    elif [[ "$seconds" -lt 60 ]]; then
        echo "${seconds}s"
    elif [[ "$seconds" -lt 3600 ]]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
    elif [[ "$seconds" -lt 86400 ]]; then
        echo "$((seconds / 3600))h $((seconds % 3600 / 60))m"
    else
        echo "$((seconds / 86400))d $((seconds % 86400 / 3600))h"
    fi
}

utils::parse_duration() {
    local input="$1"
    local seconds=0

    # Handle formats like "1h", "30m", "1h30m", "90s", "1d"
    while [[ -n "$input" ]]; do
        if [[ "$input" =~ ^([0-9]+)d ]]; then
            seconds=$((seconds + ${BASH_REMATCH[1]} * 86400))
            input="${input#*d}"
        elif [[ "$input" =~ ^([0-9]+)h ]]; then
            seconds=$((seconds + ${BASH_REMATCH[1]} * 3600))
            input="${input#*h}"
        elif [[ "$input" =~ ^([0-9]+)m ]]; then
            seconds=$((seconds + ${BASH_REMATCH[1]} * 60))
            input="${input#*m}"
        elif [[ "$input" =~ ^([0-9]+)s? ]]; then
            seconds=$((seconds + ${BASH_REMATCH[1]}))
            input="${input#*[0-9]}"
            input="${input#s}"
        else
            break
        fi
    done

    echo "$seconds"
}

# ============================================
# USER INTERACTION
# ============================================

utils::confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"

    local yn
    if [[ "$default" == "y" ]]; then
        read -p "$prompt [Y/n] " -n 1 -r yn
    else
        read -p "$prompt [y/N] " -n 1 -r yn
    fi
    echo

    case "$yn" in
        [Yy]) return 0 ;;
        [Nn]) return 1 ;;
        "") [[ "$default" == "y" ]] && return 0 || return 1 ;;
        *) return 1 ;;
    esac
}

utils::select_option() {
    local prompt="$1"
    shift
    local options=("$@")

    echo "$prompt"
    local i=1
    for opt in "${options[@]}"; do
        echo "  $i) $opt"
        ((i++))
    done

    local selection
    read -p "Selection: " selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#options[@]} ]]; then
        echo "${options[$((selection-1))]}"
        return 0
    fi

    return 1
}

# ============================================
# OUTPUT FUNCTIONS (delegate to cli.sh)
# ============================================
# These are wrappers for backward compatibility.
# cli.sh handles colors and TTY detection.

utils::success() {
    cli::success "$@"
}

utils::error() {
    cli::error "$@"
}

utils::warn() {
    cli::warn "$@"
}

utils::info() {
    cli::info "$@"
}
