#!/usr/bin/env bash
# sessions/schema.sh - JSON helpers for .session.json metadata
# Usage: source this file to get session metadata functions

# Session metadata file name
SESSION_METADATA_FILE=".session.json"

# ============================================
# JSON HELPERS
# ============================================

# Initialize a new .session.json file
# Usage: session::metadata_init <session_dir> <session_name> <zone> <type>
session::metadata_init() {
    local session_dir="$1"
    local session_name="$2"
    local zone="${3:-personal}"
    local type="${4:-exploration}"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    local created
    created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$metadata_file" <<EOF
{
  "id": "$session_name",
  "created": "$created",
  "closed": null,
  "status": "active",
  "zone": "$zone",
  "type": "$type",
  "tags": [],
  "category": null,
  "outcome": null,
  "learnings": [],
  "skills_used": [],
  "models_used": [],
  "clients_used": [],
  "primary_model": null,
  "primary_client": null,
  "summary": null
}
EOF
}

# Check if .session.json exists
# Usage: session::metadata_exists <session_dir>
session::metadata_exists() {
    local session_dir="$1"
    [[ -f "$session_dir/$SESSION_METADATA_FILE" ]]
}

# Get a field from .session.json
# Usage: session::metadata_get <session_dir> <field>
# Example: session::metadata_get . status
session::metadata_get() {
    local session_dir="$1"
    local field="$2"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        echo ""
        return 1
    fi

    if command -v jq &>/dev/null; then
        jq -r ".$field // empty" "$metadata_file"
    else
        # Fallback: simple grep (limited to top-level string fields)
        grep -oP "\"$field\":\s*\"?\K[^\",$}]+" "$metadata_file" 2>/dev/null | head -1
    fi
}

# Set a field in .session.json
# Usage: session::metadata_set <session_dir> <field> <value>
# Example: session::metadata_set . status closed
session::metadata_set() {
    local session_dir="$1"
    local field="$2"
    local value="$3"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        echo "Error: $metadata_file not found" >&2
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq required for metadata operations" >&2
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)

    # Detect if value is JSON (array, object, null, boolean, number)
    if [[ "$value" =~ ^(\[|\{|null|true|false|[0-9]) ]]; then
        # Value is JSON, don't quote it
        jq ".$field = $value" "$metadata_file" > "$tmp_file"
    else
        # Value is a string, quote it
        jq ".$field = \"$value\"" "$metadata_file" > "$tmp_file"
    fi

    mv "$tmp_file" "$metadata_file"
}

# Add a tag to .session.json
# Usage: session::metadata_add_tag <session_dir> <tag>
session::metadata_add_tag() {
    local session_dir="$1"
    local tag="$2"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq required" >&2
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)
    jq ".tags += [\"$tag\"] | .tags |= unique" "$metadata_file" > "$tmp_file"
    mv "$tmp_file" "$metadata_file"
}

# Set multiple tags at once
# Usage: session::metadata_set_tags <session_dir> <tag1> <tag2> ...
session::metadata_set_tags() {
    local session_dir="$1"
    shift
    local tags=("$@")
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi

    # Build JSON array
    local json_array="["
    local first=true
    for tag in "${tags[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            json_array+=","
        fi
        json_array+="\"$tag\""
    done
    json_array+="]"

    session::metadata_set "$session_dir" "tags" "$json_array"
}

# Add a learning to .session.json
# Usage: session::metadata_add_learning <session_dir> <learning>
session::metadata_add_learning() {
    local session_dir="$1"
    local learning="$2"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq required" >&2
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)
    # Escape the learning string for JSON
    local escaped_learning
    escaped_learning=$(printf '%s' "$learning" | jq -Rs '.')
    jq ".learnings += [$escaped_learning]" "$metadata_file" > "$tmp_file"
    mv "$tmp_file" "$metadata_file"
}

# Close a session (set status=closed, closed timestamp)
# Usage: session::metadata_close <session_dir> [outcome] [summary]
session::metadata_close() {
    local session_dir="$1"
    local outcome="${2:-completed}"
    local summary="${3:-}"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi

    local closed
    closed=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    session::metadata_set "$session_dir" "status" "closed"
    session::metadata_set "$session_dir" "closed" "$closed"
    session::metadata_set "$session_dir" "outcome" "$outcome"

    if [[ -n "$summary" ]]; then
        session::metadata_set "$session_dir" "summary" "$summary"
    fi
}

# Get all metadata as JSON
# Usage: session::metadata_dump <session_dir>
session::metadata_dump() {
    local session_dir="$1"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ -f "$metadata_file" ]]; then
        cat "$metadata_file"
    fi
}

# Check if session is closed
# Usage: session::is_closed <session_dir>
session::is_closed() {
    local session_dir="$1"
    local status
    status=$(session::metadata_get "$session_dir" "status")
    [[ "$status" == "closed" ]]
}

# Track skill usage in session
# Usage: session::track_skill <session_dir> <skill_name>
session::track_skill() {
    local session_dir="$1"
    local skill_name="$2"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        return 1
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp_file
    tmp_file=$(mktemp)

    # Check if skill already tracked, increment count or add new
    jq --arg skill "$skill_name" --arg now "$now" '
        if (.skills_used | map(.name) | index($skill)) then
            .skills_used |= map(
                if .name == $skill then
                    .invocations += 1 | .last_used = $now
                else
                    .
                end
            )
        else
            .skills_used += [{
                "name": $skill,
                "invocations": 1,
                "first_used": $now,
                "last_used": $now
            }]
        end
    ' "$metadata_file" > "$tmp_file"

    mv "$tmp_file" "$metadata_file"
}

# Get skills used in session
# Usage: session::get_skills <session_dir>
session::get_skills() {
    local session_dir="$1"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ -f "$metadata_file" ]] && command -v jq &>/dev/null; then
        jq -r '.skills_used // []' "$metadata_file"
    else
        echo "[]"
    fi
}

# Track model usage in session
# Usage: session::track_model <session_dir> <model_name>
session::track_model() {
    local session_dir="$1"
    local model_name="$2"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        return 1
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp_file
    tmp_file=$(mktemp)

    # Check if model already tracked, increment count or add new
    # Also update primary_model to the most-used model
    jq --arg model "$model_name" --arg now "$now" '
        # Update or add model
        if (.models_used | map(.model) | index($model)) then
            .models_used |= map(
                if .model == $model then
                    .invocations += 1 | .last_used = $now
                else
                    .
                end
            )
        else
            .models_used += [{
                "model": $model,
                "invocations": 1,
                "first_used": $now,
                "last_used": $now
            }]
        end
        # Set primary_model to most-used
        | .primary_model = (.models_used | max_by(.invocations) | .model)
    ' "$metadata_file" > "$tmp_file"

    mv "$tmp_file" "$metadata_file"
}

# Get models used in session
# Usage: session::get_models <session_dir>
session::get_models() {
    local session_dir="$1"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ -f "$metadata_file" ]] && command -v jq &>/dev/null; then
        jq -r '.models_used // []' "$metadata_file"
    else
        echo "[]"
    fi
}

# Get primary model for session
# Usage: session::get_primary_model <session_dir>
session::get_primary_model() {
    local session_dir="$1"
    session::metadata_get "$session_dir" "primary_model"
}

# Track client usage in session
# Usage: session::track_client <session_dir> <client_name>
session::track_client() {
    local session_dir="$1"
    local client_name="$2"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        return 1
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp_file
    tmp_file=$(mktemp)

    # Check if client already tracked, increment count or add new
    # Also update primary_client to the most-used client
    jq --arg client "$client_name" --arg now "$now" '
        # Ensure clients_used exists
        .clients_used //= []
        # Update or add client
        | if (.clients_used | map(.client) | index($client)) then
            .clients_used |= map(
                if .client == $client then
                    .invocations += 1 | .last_used = $now
                else
                    .
                end
            )
        else
            .clients_used += [{
                "client": $client,
                "invocations": 1,
                "first_used": $now,
                "last_used": $now
            }]
        end
        # Set primary_client to most-used
        | .primary_client = (.clients_used | max_by(.invocations) | .client)
    ' "$metadata_file" > "$tmp_file"

    mv "$tmp_file" "$metadata_file"
}

# Get clients used in session
# Usage: session::get_clients <session_dir>
session::get_clients() {
    local session_dir="$1"
    local metadata_file="$session_dir/$SESSION_METADATA_FILE"

    if [[ -f "$metadata_file" ]] && command -v jq &>/dev/null; then
        jq -r '.clients_used // []' "$metadata_file"
    else
        echo "[]"
    fi
}

# Get primary client for session
# Usage: session::get_primary_client <session_dir>
session::get_primary_client() {
    local session_dir="$1"
    session::metadata_get "$session_dir" "primary_client"
}

# Get session age in days
# Usage: session::age_days <session_dir>
session::age_days() {
    local session_dir="$1"
    local created
    created=$(session::metadata_get "$session_dir" "created")

    if [[ -z "$created" ]]; then
        echo "0"
        return
    fi

    local created_epoch now_epoch
    created_epoch=$(date -d "$created" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" +%s 2>/dev/null || echo "0")
    now_epoch=$(date +%s)

    echo $(( (now_epoch - created_epoch) / 86400 ))
}
