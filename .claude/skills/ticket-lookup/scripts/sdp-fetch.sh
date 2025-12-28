#!/usr/bin/env bash
# sdp-fetch.sh - Fetch ticket details from ServiceDesk Plus
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

ticket_num="${1:-}"

if [[ -z "$ticket_num" ]]; then
    echo "Usage: sdp-fetch.sh <ticket-number>" >&2
    exit 1
fi

# Strip "SDP-" prefix if present
ticket_num="${ticket_num#SDP-}"

# Get current zone
zone=$("$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" | grep "^zone:" | cut -d' ' -f2)

# Check if SDP is enabled for this zone
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    sdp_enabled=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.features.sdp" 2>/dev/null || echo "false")
    if [[ "$sdp_enabled" != "true" ]]; then
        echo "Error: SDP is not enabled for zone '$zone'" >&2
        echo "Enable it in config.toml: zones.$zone.features.sdp = true" >&2
        exit 1
    fi

    SDP_BASE_URL=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.sdp.base_url" 2>/dev/null || echo "")
fi

# Check for API key
if [[ -z "${SDP_API_KEY:-}" ]]; then
    echo "Error: Authentication failed - SDP_API_KEY not set" >&2
    echo "" >&2
    echo "Fix: Set your ServiceDesk Plus API token:" >&2
    echo "  export SDP_API_KEY='your-oauth-token'" >&2
    echo "" >&2
    echo "Get token from: ServiceDesk Plus > Admin > API > OAuth Tokens" >&2
    exit 1
fi

if [[ -z "${SDP_BASE_URL:-}" ]]; then
    echo "Error: SDP not configured for zone '$zone'" >&2
    echo "" >&2
    echo "Fix: Add to config.toml:" >&2
    echo "  [zones.$zone.sdp]" >&2
    echo "  base_url = \"https://your-sdp-instance.com/api/v3\"" >&2
    exit 1
fi

# Fetch ticket
response=$(curl -s -X GET \
    "${SDP_BASE_URL}/requests/${ticket_num}" \
    -H "Authorization: Zoho-oauthtoken ${SDP_API_KEY}" \
    -H "Content-Type: application/json" 2>/dev/null)

# Check for errors
if echo "$response" | jq -e '.response_status.status_code' &>/dev/null; then
    status=$(echo "$response" | jq -r '.response_status.status_code')
    if [[ "$status" != "2000" ]]; then
        message=$(echo "$response" | jq -r '.response_status.messages[0].message // "Unknown error"')
        echo "Error: API request failed ($status)" >&2
        echo "" >&2
        case "$status" in
            4000) echo "Ticket not found: SDP-$ticket_num" >&2 ;;
            4001) echo "Authentication failed - check SDP_API_KEY is valid" >&2 ;;
            4003) echo "Permission denied - your token may lack read access" >&2 ;;
            *)    echo "Message: $message" >&2 ;;
        esac
        exit 1
    fi
fi

# Output structured data
cat <<EOF
ticket_id: SDP-${ticket_num}
title: $(echo "$response" | jq -r '.request.subject // "N/A"')
status: $(echo "$response" | jq -r '.request.status.name // "N/A"')
priority: $(echo "$response" | jq -r '.request.priority.name // "N/A"')
assignee: $(echo "$response" | jq -r '.request.technician.name // "Unassigned"')
requester: $(echo "$response" | jq -r '.request.requester.name // "N/A"')
created: $(echo "$response" | jq -r '.request.created_time.display_value // "N/A"')
description: |
$(echo "$response" | jq -r '.request.description // "No description"' | sed 's/^/  /')
EOF
