#!/usr/bin/env bash
# Calendar management wrapper
# Routes to gcalcli (Google) or thallo (MS365) based on account/zone
# Usage: cal.sh <command> [options]
# Commands: agenda, today, show, add, create, edit, delete, search

set -uo pipefail

# Defaults
ACCOUNT="${MAESTRO_CALENDAR_ACCOUNT:-}"
DAYS=7

# Parse global options
while [[ $# -gt 0 ]]; do
    case $1 in
        --account) ACCOUNT="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        *) break ;;
    esac
done

COMMAND="${1:-agenda}"
shift || true

# Detect provider from zone if not specified
detect_provider() {
    if [[ -n "$ACCOUNT" ]]; then
        case "$ACCOUNT" in
            google|gmail|gcal) echo "google" ;;
            ms365|outlook|work) echo "ms365" ;;
            *) echo "google" ;;  # default
        esac
        return
    fi

    # Check zone config
    local zone="${MAESTRO_ZONE:-personal}"
    case "$zone" in
        work*|corp*|office*) echo "ms365" ;;
        *) echo "google" ;;
    esac
}

PROVIDER=$(detect_provider)

# Google Calendar (gcalcli)
google_cmd() {
    local cmd="$1"; shift
    case "$cmd" in
        agenda)
            gcalcli agenda --nostarted "$@"
            ;;
        today)
            gcalcli agenda "today" "tomorrow" --nostarted "$@"
            ;;
        show)
            local date="$1"; shift || { echo "Usage: cal.sh show <date>"; exit 1; }
            gcalcli agenda "$date" "$date + 1 day" "$@"
            ;;
        add)
            local desc="$1"; shift || { echo "Usage: cal.sh add <description>"; exit 1; }
            gcalcli quick "$desc" "$@"
            ;;
        create)
            gcalcli add "$@"
            ;;
        edit)
            local query="$1"; shift || { echo "Usage: cal.sh edit <event>"; exit 1; }
            gcalcli edit "$query" "$@"
            ;;
        delete)
            local query="$1"; shift || { echo "Usage: cal.sh delete <event>"; exit 1; }
            gcalcli delete "$query" "$@"
            ;;
        search)
            local query="$1"; shift || { echo "Usage: cal.sh search <query>"; exit 1; }
            gcalcli search "$query" "$@"
            ;;
        *)
            echo "Unknown command for gcalcli: $cmd"
            exit 1
            ;;
    esac
}

# MS365 Calendar (thallo)
ms365_cmd() {
    local cmd="$1"; shift
    case "$cmd" in
        agenda|today|show)
            thallo fetch "$@"
            ;;
        add)
            local desc="$1"; shift || { echo "Usage: cal.sh add <description>"; exit 1; }
            echo "Note: thallo doesn't support natural language. Use 'cal.sh create' with explicit times."
            echo "Description: $desc"
            ;;
        create)
            thallo add "$@"
            ;;
        edit)
            echo "Note: thallo edit support is limited. Use Outlook web for complex edits."
            thallo info "$@"
            ;;
        delete)
            echo "Note: thallo delete requires event ID. Use 'thallo fetch' to find ID."
            thallo info "$@"
            ;;
        search)
            # thallo doesn't have native search, fetch and filter
            thallo fetch "$@"
            ;;
        *)
            echo "Unknown command for thallo: $cmd"
            exit 1
            ;;
    esac
}

# Route to provider
case "$PROVIDER" in
    google)
        google_cmd "$COMMAND" "$@"
        ;;
    ms365)
        ms365_cmd "$COMMAND" "$@"
        ;;
    *)
        echo "Unknown provider: $PROVIDER"
        exit 1
        ;;
esac
