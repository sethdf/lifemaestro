#!/usr/bin/env bash
# session-list.sh - List Claude Code sessions with metadata filtering
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

# Parse arguments
zone_filter="all"
category_filter="all"
tag_filter=""
status_filter="all"
limit=20
output_format="text"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --zone=*) zone_filter="${1#*=}"; shift ;;
        --category=*) category_filter="${1#*=}"; shift ;;
        --tags=*) tag_filter="${1#*=}"; shift ;;
        --status=*) status_filter="${1#*=}"; shift ;;
        --limit=*) limit="${1#*=}"; shift ;;
        --json) output_format="json"; shift ;;
        -h|--help)
            echo "Usage: session-list.sh [options]"
            echo ""
            echo "Options:"
            echo "  --zone=ZONE        Filter by zone (work, personal, all)"
            echo "  --category=CAT     Filter by AI category (bugs, features, learning, etc.)"
            echo "  --tags=TAG,TAG     Filter by tags (comma-separated)"
            echo "  --status=STATUS    Filter by status (active, closed, all)"
            echo "  --limit=N          Limit results (default: 20)"
            echo "  --json             Output as JSON"
            exit 0
            ;;
        *)
            # Legacy positional args: zone category limit
            if [[ -z "$zone_filter" ]] || [[ "$zone_filter" == "all" ]]; then
                zone_filter="$1"
            elif [[ -z "$category_filter" ]] || [[ "$category_filter" == "all" ]]; then
                category_filter="$1"
            else
                limit="$1"
            fi
            shift
            ;;
    esac
done

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

# Helper: read field from .session.json
get_metadata() {
    local session_dir="$1"
    local field="$2"
    local metadata_file="$session_dir/.session.json"

    if [[ -f "$metadata_file" ]] && command -v jq &>/dev/null; then
        jq -r ".$field // empty" "$metadata_file" 2>/dev/null
    fi
}

# Helper: check if session has tag
has_tag() {
    local session_dir="$1"
    local search_tag="$2"
    local metadata_file="$session_dir/.session.json"

    if [[ -f "$metadata_file" ]] && command -v jq &>/dev/null; then
        jq -e ".tags | index(\"$search_tag\")" "$metadata_file" &>/dev/null
        return $?
    fi
    return 1
}

# Helper: check if session matches tag filter (any tag matches)
matches_tags() {
    local session_dir="$1"
    local filter="$2"

    [[ -z "$filter" ]] && return 0

    IFS=',' read -ra tags <<< "$filter"
    for tag in "${tags[@]}"; do
        if has_tag "$session_dir" "$tag"; then
            return 0
        fi
    done
    return 1
}

# Get list of zones to search
zones=()
if [[ "$zone_filter" == "all" ]]; then
    if [[ -d "$sessions_base" ]]; then
        for zone_dir in "$sessions_base"/*/; do
            [[ -d "$zone_dir" ]] && zones+=("$(basename "$zone_dir")")
        done
    fi
else
    zones=("$zone_filter")
fi

# JSON output mode
if [[ "$output_format" == "json" ]]; then
    echo "["
    first=true
fi

# Text header
if [[ "$output_format" == "text" ]]; then
    echo "Sessions:"
    echo "========="
fi

count=0
for zone in "${zones[@]}"; do
    zone_path="$sessions_base/$zone"
    [[ -d "$zone_path" ]] || continue

    if [[ "$output_format" == "text" ]]; then
        echo ""
        echo "[$zone]"
    fi

    # Find all sessions with CLAUDE.md
    find "$zone_path" -maxdepth 3 -name "CLAUDE.md" -type f 2>/dev/null | sort -r | \
        while read -r claude_file; do
            [[ $count -ge $limit ]] && break

            session_dir=$(dirname "$claude_file")
            session_name=$(basename "$session_dir")
            dir_category=$(basename "$(dirname "$session_dir")")

            # Get metadata from .session.json
            meta_status=$(get_metadata "$session_dir" "status")
            meta_category=$(get_metadata "$session_dir" "category")
            meta_tags=$(get_metadata "$session_dir" "tags")
            meta_outcome=$(get_metadata "$session_dir" "outcome")
            meta_summary=$(get_metadata "$session_dir" "summary")

            # Use metadata category if available, otherwise directory category
            display_category="${meta_category:-$dir_category}"

            # Apply status filter
            if [[ "$status_filter" != "all" ]]; then
                actual_status="${meta_status:-active}"
                [[ "$actual_status" != "$status_filter" ]] && continue
            fi

            # Apply category filter (check both directory and metadata category)
            if [[ "$category_filter" != "all" ]]; then
                if [[ "$dir_category" != "$category_filter" ]] && [[ "$meta_category" != "$category_filter" ]]; then
                    continue
                fi
            fi

            # Apply tag filter
            if [[ -n "$tag_filter" ]] && ! matches_tags "$session_dir" "$tag_filter"; then
                continue
            fi

            # Check for legacy completion marker
            completed=""
            if [[ "$meta_status" == "closed" ]]; then
                completed=" [closed]"
            elif grep -q "Session Completed" "$claude_file" 2>/dev/null; then
                completed=" [done]"
            fi

            # Format output
            if [[ "$output_format" == "json" ]]; then
                [[ "$first" == "true" ]] && first=false || echo ","
                cat <<EOF
  {
    "zone": "$zone",
    "directory_category": "$dir_category",
    "category": "${meta_category:-null}",
    "name": "$session_name",
    "path": "$session_dir",
    "status": "${meta_status:-active}",
    "outcome": "${meta_outcome:-null}",
    "tags": $([[ -n "$meta_tags" ]] && echo "$meta_tags" || echo "[]"),
    "summary": $(jq -n --arg s "${meta_summary:-}" '$s')
  }
EOF
            else
                # Build display line
                tag_display=""
                if [[ -n "$meta_tags" ]] && [[ "$meta_tags" != "[]" ]]; then
                    tag_display=" [$(echo "$meta_tags" | jq -r 'join(", ")' 2>/dev/null)]"
                fi

                echo "  $dir_category/$session_name$completed$tag_display"
            fi

            ((count++))
        done
done

if [[ "$output_format" == "json" ]]; then
    echo ""
    echo "]"
else
    # Show current zone
    echo ""
    echo "Current Zone:"
    "$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" 2>/dev/null | grep "^zone:" | sed 's/^/  /' || echo "  (unknown)"
fi
