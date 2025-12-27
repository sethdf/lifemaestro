#!/usr/bin/env bash
# Email management wrapper using himalaya
# Usage: mail.sh <command> [options]
# Commands: list, read, search, compose, reply, forward, move, delete, mark, folders

set -uo pipefail

# Defaults
ACCOUNT="${MAESTRO_EMAIL_ACCOUNT:-}"
FOLDER="INBOX"
LIMIT=20

# Parse global options
while [[ $# -gt 0 ]]; do
    case $1 in
        --account) ACCOUNT="$2"; shift 2 ;;
        --folder) FOLDER="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) break ;;
    esac
done

COMMAND="${1:-list}"
shift || true

# Detect account from zone if not specified
detect_account() {
    if [[ -n "$ACCOUNT" ]]; then
        echo "$ACCOUNT"
        return
    fi

    # Check zone config
    local zone="${MAESTRO_ZONE:-personal}"
    case "$zone" in
        work*|corp*|office*) echo "ms365" ;;
        *) echo "gmail" ;;
    esac
}

ACCOUNT=$(detect_account)

# Commands
case "$COMMAND" in
    list)
        himalaya envelope list --account "$ACCOUNT" --folder "$FOLDER" --page-size "$LIMIT" "$@"
        ;;

    read)
        local id="$1"; shift || { echo "Usage: mail.sh read <id>"; exit 1; }
        himalaya message read --account "$ACCOUNT" "$id" "$@"
        ;;

    search)
        local query="$1"; shift || { echo "Usage: mail.sh search <query>"; exit 1; }
        himalaya envelope list --account "$ACCOUNT" --folder "$FOLDER" --query "$query" "$@"
        ;;

    compose)
        himalaya message write --account "$ACCOUNT" "$@"
        ;;

    reply)
        local id="$1"; shift || { echo "Usage: mail.sh reply <id>"; exit 1; }
        himalaya message reply --account "$ACCOUNT" "$id" "$@"
        ;;

    forward)
        local id="$1"; shift || { echo "Usage: mail.sh forward <id>"; exit 1; }
        himalaya message forward --account "$ACCOUNT" "$id" "$@"
        ;;

    move)
        local id="$1"; shift || { echo "Usage: mail.sh move <id> <folder>"; exit 1; }
        local target="$1"; shift || { echo "Usage: mail.sh move <id> <folder>"; exit 1; }
        himalaya message move --account "$ACCOUNT" "$id" "$target" "$@"
        ;;

    delete)
        local id="$1"; shift || { echo "Usage: mail.sh delete <id>"; exit 1; }
        himalaya message delete --account "$ACCOUNT" "$id" "$@"
        ;;

    mark)
        local id="$1"; shift || { echo "Usage: mail.sh mark <id> --read|--unread"; exit 1; }
        local flag="$1"; shift || { echo "Usage: mail.sh mark <id> --read|--unread"; exit 1; }
        case "$flag" in
            --read) himalaya flag add --account "$ACCOUNT" "$id" seen ;;
            --unread) himalaya flag remove --account "$ACCOUNT" "$id" seen ;;
            *) echo "Unknown flag: $flag"; exit 1 ;;
        esac
        ;;

    folders)
        himalaya folder list --account "$ACCOUNT" "$@"
        ;;

    *)
        echo "Unknown command: $COMMAND"
        echo "Usage: mail.sh <command> [options]"
        echo "Commands: list, read, search, compose, reply, forward, move, delete, mark, folders"
        exit 1
        ;;
esac
