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
    local input="$1"
    local max_len="${2:-50}"  # Default max 50 chars

    local slug
    slug=$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-_')

    # Truncate if too long
    if [[ ${#slug} -gt $max_len ]]; then
        slug="${slug:0:$max_len}"
        # Don't end with a dash
        slug="${slug%-}"
    fi

    echo "$slug"
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
    local install_hint="${2:-}"

    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' not found" >&2
        echo "" >&2
        if [[ -n "$install_hint" ]]; then
            echo "Install: $install_hint" >&2
        else
            # Provide common install hints
            case "$cmd" in
                dasel)  echo "Install: go install github.com/TomWright/dasel/v2/cmd/dasel@master" >&2 ;;
                jq)     echo "Install: sudo apt install jq  OR  brew install jq" >&2 ;;
                fzf)    echo "Install: sudo apt install fzf  OR  brew install fzf" >&2 ;;
                gh)     echo "Install: sudo apt install gh  OR  brew install gh" >&2 ;;
                yq)     echo "Install: go install github.com/mikefarah/yq/v4@latest" >&2 ;;
                *)      echo "Install: Check your package manager for '$cmd'" >&2 ;;
            esac
        fi
        return 1
    fi
}

utils::require_env() {
    local var="$1"
    local hint="${2:-}"

    if [[ -z "${!var:-}" ]]; then
        echo "Error: Environment variable '$var' not set" >&2
        echo "" >&2
        if [[ -n "$hint" ]]; then
            echo "Fix: $hint" >&2
        else
            echo "Fix: export $var='your-value'" >&2
        fi
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
