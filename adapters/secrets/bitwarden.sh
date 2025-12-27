#!/usr/bin/env bash
# lifemaestro/adapters/secrets/bitwarden.sh - Bitwarden secrets adapter
set -uo pipefail

# Folder prefix for maestro-managed secrets (optional)
BW_FOLDER="${BW_FOLDER:-}"

# Session persistence file
BW_SESSION_FILE="${BW_SESSION_FILE:-$HOME/.config/bitwarden/session}"

# ============================================
# SESSION MANAGEMENT
# ============================================

secrets::bw_check_cli() {
    command -v bw &>/dev/null || {
        echo "Error: Bitwarden CLI (bw) not installed" >&2
        return 1
    }
}

secrets::bw_status() {
    bw status 2>/dev/null | jq -r '.status' 2>/dev/null
}

secrets::bw_is_unlocked() {
    [[ "$(secrets::bw_status)" == "unlocked" ]]
}

secrets::bw_save_session() {
    [[ -z "${BW_SESSION:-}" ]] && return 1

    local session_dir=$(dirname "$BW_SESSION_FILE")
    [[ ! -d "$session_dir" ]] && mkdir -p "$session_dir" && chmod 700 "$session_dir"

    echo "$BW_SESSION" > "$BW_SESSION_FILE"
    chmod 600 "$BW_SESSION_FILE"
}

secrets::bw_load_session() {
    [[ -f "$BW_SESSION_FILE" ]] || return 1

    local session=$(cat "$BW_SESSION_FILE" 2>/dev/null)
    [[ -z "$session" ]] && return 1

    export BW_SESSION="$session"

    # Verify session is still valid
    if ! secrets::bw_is_unlocked; then
        rm -f "$BW_SESSION_FILE"
        unset BW_SESSION
        return 1
    fi

    return 0
}

secrets::bw_clear_session() {
    rm -f "$BW_SESSION_FILE"
    unset BW_SESSION
}

secrets::bw_ensure_unlocked() {
    secrets::bw_check_cli || return 1

    # Try loading persisted session first
    if [[ -z "${BW_SESSION:-}" ]]; then
        secrets::bw_load_session 2>/dev/null
    fi

    local status=$(secrets::bw_status)

    case "$status" in
        unlocked)
            return 0
            ;;
        locked)
            echo "Bitwarden vault is locked. Unlocking..." >&2
            BW_SESSION=$(bw unlock --raw 2>/dev/null) || {
                echo "Error: Failed to unlock vault" >&2
                return 1
            }
            export BW_SESSION
            secrets::bw_save_session
            ;;
        unauthenticated)
            echo "Bitwarden not logged in. Please run: bw login" >&2
            return 1
            ;;
        *)
            echo "Error: Unknown Bitwarden status: $status" >&2
            return 1
            ;;
    esac
}

# ============================================
# READ OPERATIONS (Safe)
# ============================================

secrets::get() {
    local key="$1"
    local field="${2:-password}"  # default to password field

    secrets::bw_ensure_unlocked || return 1

    # Search for item by name
    local item_id
    item_id=$(bw get item "$key" 2>/dev/null | jq -r '.id' 2>/dev/null)

    [[ -z "$item_id" || "$item_id" == "null" ]] && {
        echo "Error: Item '$key' not found" >&2
        return 1
    }

    case "$field" in
        password)
            bw get password "$item_id" 2>/dev/null
            ;;
        username)
            bw get username "$item_id" 2>/dev/null
            ;;
        totp)
            bw get totp "$item_id" 2>/dev/null
            ;;
        uri|url)
            bw get item "$item_id" 2>/dev/null | jq -r '.login.uris[0].uri // empty'
            ;;
        notes)
            bw get item "$item_id" 2>/dev/null | jq -r '.notes // empty'
            ;;
        *)
            # Custom field
            bw get item "$item_id" 2>/dev/null | jq -r ".fields[]? | select(.name==\"$field\") | .value // empty"
            ;;
    esac
}

secrets::get_item() {
    local key="$1"

    secrets::bw_ensure_unlocked || return 1
    bw get item "$key" 2>/dev/null
}

secrets::exists() {
    local key="$1"

    secrets::bw_ensure_unlocked || return 1
    bw get item "$key" &>/dev/null
}

secrets::search() {
    local query="$1"

    secrets::bw_ensure_unlocked || return 1
    bw list items --search "$query" 2>/dev/null | jq -r '.[].name'
}

secrets::list() {
    local folder="${1:-$BW_FOLDER}"

    secrets::bw_ensure_unlocked || return 1

    if [[ -n "$folder" ]]; then
        local folder_id
        folder_id=$(bw get folder "$folder" 2>/dev/null | jq -r '.id' 2>/dev/null)
        if [[ -n "$folder_id" && "$folder_id" != "null" ]]; then
            bw list items --folderid "$folder_id" 2>/dev/null | jq -r '.[].name'
        else
            echo "Error: Folder '$folder' not found" >&2
            return 1
        fi
    else
        bw list items 2>/dev/null | jq -r '.[].name'
    fi
}

# ============================================
# WRITE OPERATIONS (Require Confirmation)
# ============================================

# SAFETY: These functions should only be called after user confirmation
# The pre-bash hook will intercept 'bw create' and 'bw edit' commands

secrets::set() {
    local key="$1"
    local value="$2"
    local username="${3:-}"

    secrets::bw_ensure_unlocked || return 1

    # Check if item exists
    if secrets::exists "$key"; then
        echo "Error: Item '$key' already exists. Use secrets::update to modify." >&2
        return 1
    fi

    # Create item JSON
    local item_json
    item_json=$(jq -n \
        --arg name "$key" \
        --arg password "$value" \
        --arg username "$username" \
        '{
            type: 1,
            name: $name,
            login: {
                username: (if $username != "" then $username else null end),
                password: $password
            }
        }')

    # Add to folder if configured
    if [[ -n "$BW_FOLDER" ]]; then
        local folder_id
        folder_id=$(bw get folder "$BW_FOLDER" 2>/dev/null | jq -r '.id' 2>/dev/null)
        if [[ -n "$folder_id" && "$folder_id" != "null" ]]; then
            item_json=$(echo "$item_json" | jq --arg fid "$folder_id" '. + {folderId: $fid}')
        fi
    fi

    echo "$item_json" | bw encode | bw create item
}

secrets::update() {
    local key="$1"
    local value="$2"
    local field="${3:-password}"

    secrets::bw_ensure_unlocked || return 1

    local item
    item=$(bw get item "$key" 2>/dev/null) || {
        echo "Error: Item '$key' not found" >&2
        return 1
    }

    local item_id
    item_id=$(echo "$item" | jq -r '.id')

    case "$field" in
        password)
            item=$(echo "$item" | jq --arg val "$value" '.login.password = $val')
            ;;
        username)
            item=$(echo "$item" | jq --arg val "$value" '.login.username = $val')
            ;;
        notes)
            item=$(echo "$item" | jq --arg val "$value" '.notes = $val')
            ;;
        *)
            echo "Error: Unknown field '$field'" >&2
            return 1
            ;;
    esac

    echo "$item" | bw encode | bw edit item "$item_id"
}

secrets::delete() {
    local key="$1"

    secrets::bw_ensure_unlocked || return 1

    local item_id
    item_id=$(bw get item "$key" 2>/dev/null | jq -r '.id' 2>/dev/null)

    [[ -z "$item_id" || "$item_id" == "null" ]] && {
        echo "Error: Item '$key' not found" >&2
        return 1
    }

    bw delete item "$item_id"
}

# ============================================
# SYNC
# ============================================

secrets::sync() {
    secrets::bw_ensure_unlocked || return 1
    bw sync
}

# ============================================
# GENERATE
# ============================================

secrets::generate_password() {
    local length="${1:-20}"
    bw generate -ulns --length "$length"
}
