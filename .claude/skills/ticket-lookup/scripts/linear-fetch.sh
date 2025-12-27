#!/usr/bin/env bash
# linear-fetch.sh - Fetch issue details from Linear
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

issue_id="${1:-}"

if [[ -z "$issue_id" ]]; then
    echo "Usage: linear-fetch.sh <issue-id-or-identifier>" >&2
    echo "Example: linear-fetch.sh ENG-456" >&2
    exit 1
fi

# Get current zone
zone=$("$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" | grep "^zone:" | cut -d' ' -f2)

# Check if Linear is enabled for this zone
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    linear_enabled=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.features.linear" 2>/dev/null || echo "false")
    if [[ "$linear_enabled" != "true" ]]; then
        echo "Error: Linear is not enabled for zone '$zone'" >&2
        echo "Enable it in config.toml: zones.$zone.features.linear = true" >&2
        exit 1
    fi
fi

# Check for API key
if [[ -z "${LINEAR_API_KEY:-}" ]]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 1
fi

# Determine if this is an ID or identifier (identifiers have letters followed by dash and numbers)
if [[ "$issue_id" =~ ^[A-Z]+-[0-9]+$ ]]; then
    # This is a human-readable identifier, search for it
    query='query { issueSearch(query: "'"$issue_id"'", first: 1) { nodes { id identifier title description state { name } priority priorityLabel assignee { name email } createdAt } } }'
    response=$(curl -s -X POST https://api.linear.app/graphql \
        -H "Authorization: $LINEAR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$query\"}" 2>/dev/null)

    # Extract from search results
    issue=$(echo "$response" | jq '.data.issueSearch.nodes[0]')
else
    # This is a UUID, fetch directly
    query='query { issue(id: "'"$issue_id"'") { id identifier title description state { name } priority priorityLabel assignee { name email } createdAt } }'
    response=$(curl -s -X POST https://api.linear.app/graphql \
        -H "Authorization: $LINEAR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$query\"}" 2>/dev/null)

    issue=$(echo "$response" | jq '.data.issue')
fi

# Check for errors
if [[ "$issue" == "null" ]]; then
    errors=$(echo "$response" | jq -r '.errors[0].message // "Issue not found"')
    echo "Error: $errors" >&2
    exit 1
fi

# Output structured data
cat <<EOF
ticket_id: $(echo "$issue" | jq -r '.identifier // .id')
title: $(echo "$issue" | jq -r '.title // "N/A"')
status: $(echo "$issue" | jq -r '.state.name // "N/A"')
priority: $(echo "$issue" | jq -r '.priorityLabel // "N/A"')
assignee: $(echo "$issue" | jq -r '.assignee.name // "Unassigned"')
created: $(echo "$issue" | jq -r '.createdAt // "N/A"')
description: |
$(echo "$issue" | jq -r '.description // "No description"' | sed 's/^/  /')
EOF
