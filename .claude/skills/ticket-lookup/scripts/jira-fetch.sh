#!/usr/bin/env bash
# jira-fetch.sh - Fetch issue details from Jira
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

issue_key="${1:-}"

if [[ -z "$issue_key" ]]; then
    echo "Usage: jira-fetch.sh <issue-key>" >&2
    echo "Example: jira-fetch.sh PROJ-123" >&2
    exit 1
fi

# Get current zone
zone=$("$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" | grep "^zone:" | cut -d' ' -f2)

# Check if Jira is enabled for this zone
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    jira_enabled=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.features.jira" 2>/dev/null || echo "false")
    if [[ "$jira_enabled" != "true" ]]; then
        echo "Error: Jira is not enabled for zone '$zone'" >&2
        echo "Enable it in config.toml: zones.$zone.features.jira = true" >&2
        exit 1
    fi

    JIRA_BASE_URL=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.jira.base_url" 2>/dev/null || echo "")
fi

# Check for credentials
if [[ -z "${JIRA_EMAIL:-}" ]] || [[ -z "${JIRA_API_TOKEN:-}" ]]; then
    echo "Error: JIRA_EMAIL and JIRA_API_TOKEN environment variables required" >&2
    exit 1
fi

if [[ -z "${JIRA_BASE_URL:-}" ]]; then
    echo "Error: Jira base URL not configured for zone '$zone'" >&2
    exit 1
fi

# Build auth header
auth_header=$(echo -n "$JIRA_EMAIL:$JIRA_API_TOKEN" | base64)

# Fetch issue
response=$(curl -s -X GET \
    "${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}" \
    -H "Authorization: Basic ${auth_header}" \
    -H "Content-Type: application/json" 2>/dev/null)

# Check for errors
if echo "$response" | jq -e '.errorMessages' &>/dev/null; then
    error=$(echo "$response" | jq -r '.errorMessages[0] // "Unknown error"')
    echo "Error: $error" >&2
    exit 1
fi

# Extract description (Jira uses ADF format)
description=$(echo "$response" | jq -r '
    .fields.description.content[]?.content[]?.text // empty
' 2>/dev/null | tr '\n' ' ' || echo "No description")

# Output structured data
cat <<EOF
ticket_id: $(echo "$response" | jq -r '.key')
title: $(echo "$response" | jq -r '.fields.summary // "N/A"')
status: $(echo "$response" | jq -r '.fields.status.name // "N/A"')
priority: $(echo "$response" | jq -r '.fields.priority.name // "N/A"')
assignee: $(echo "$response" | jq -r '.fields.assignee.displayName // "Unassigned"')
reporter: $(echo "$response" | jq -r '.fields.reporter.displayName // "N/A"')
created: $(echo "$response" | jq -r '.fields.created // "N/A"')
labels: $(echo "$response" | jq -r '.fields.labels | join(", ") // "none"')
description: |
  ${description}
EOF
