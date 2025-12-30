#!/usr/bin/env bash
# azuredevops-fetch.sh - Fetch work item details from Azure DevOps
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

work_item_id="${1:-}"

if [[ -z "$work_item_id" ]]; then
    echo "Usage: azuredevops-fetch.sh <work-item-id>" >&2
    echo "Example: azuredevops-fetch.sh 12345" >&2
    exit 1
fi

# Strip "ADO-" or "#" prefix if present
work_item_id="${work_item_id#ADO-}"
work_item_id="${work_item_id#\#}"

# Get current zone
zone=$("$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" | grep "^zone:" | cut -d' ' -f2)

# Check if Azure DevOps is enabled for this zone and load config
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    ado_enabled=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.features.azure_devops" 2>/dev/null || echo "false")
    if [[ "$ado_enabled" != "true" ]]; then
        echo "Error: Azure DevOps is not enabled for zone '$zone'" >&2
        echo "Enable it in config.toml: zones.$zone.features.azure_devops = true" >&2
        exit 1
    fi

    ADO_ORGANIZATION=${ADO_ORGANIZATION:-$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.azure_devops.organization" 2>/dev/null || echo "")}
    ADO_PROJECT=${ADO_PROJECT:-$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.azure_devops.project" 2>/dev/null || echo "")}
fi

# Check for PAT
if [[ -z "${ADO_PAT:-}" ]]; then
    echo "Error: ADO_PAT environment variable not set" >&2
    echo "Create a Personal Access Token at: https://dev.azure.com/{org}/_usersSettings/tokens" >&2
    exit 1
fi

if [[ -z "${ADO_ORGANIZATION:-}" ]]; then
    echo "Error: Azure DevOps organization not configured for zone '$zone'" >&2
    echo "Set ADO_ORGANIZATION or configure zones.$zone.azure_devops.organization in config.toml" >&2
    exit 1
fi

if [[ -z "${ADO_PROJECT:-}" ]]; then
    echo "Error: Azure DevOps project not configured for zone '$zone'" >&2
    echo "Set ADO_PROJECT or configure zones.$zone.azure_devops.project in config.toml" >&2
    exit 1
fi

# Build auth header (PAT uses empty username)
auth_header=$(echo -n ":$ADO_PAT" | base64)

# Fetch work item
response=$(curl -s -X GET \
    "https://dev.azure.com/${ADO_ORGANIZATION}/${ADO_PROJECT}/_apis/wit/workitems/${work_item_id}?\$expand=relations&api-version=7.0" \
    -H "Authorization: Basic ${auth_header}" \
    -H "Content-Type: application/json" 2>/dev/null)

# Check for errors
if echo "$response" | jq -e '.message' &>/dev/null; then
    error=$(echo "$response" | jq -r '.message')
    echo "Error: $error" >&2
    exit 1
fi

# Extract fields
fields=$(echo "$response" | jq '.fields')

# Get assignee (handle both display name formats)
assignee=$(echo "$fields" | jq -r '.["System.AssignedTo"].displayName // .["System.AssignedTo"] // "Unassigned"')

# Get parent work item if exists
parent_id=$(echo "$response" | jq -r '.relations[]? | select(.rel == "System.LinkTypes.Hierarchy-Reverse") | .url | split("/") | .[-1] // empty' 2>/dev/null | head -1)
parent_info=""
if [[ -n "$parent_id" ]]; then
    parent_info="parent: ADO-${parent_id}"
fi

# Output structured data
cat <<EOF
ticket_id: ADO-${work_item_id}
title: $(echo "$fields" | jq -r '.["System.Title"] // "N/A"')
type: $(echo "$fields" | jq -r '.["System.WorkItemType"] // "N/A"')
status: $(echo "$fields" | jq -r '.["System.State"] // "N/A"')
priority: $(echo "$fields" | jq -r '.["Microsoft.VSTS.Common.Priority"] // "N/A"')
severity: $(echo "$fields" | jq -r '.["Microsoft.VSTS.Common.Severity"] // "N/A"')
assignee: ${assignee}
created_by: $(echo "$fields" | jq -r '.["System.CreatedBy"].displayName // .["System.CreatedBy"] // "N/A"')
created: $(echo "$fields" | jq -r '.["System.CreatedDate"] // "N/A"')
changed: $(echo "$fields" | jq -r '.["System.ChangedDate"] // "N/A"')
iteration: $(echo "$fields" | jq -r '.["System.IterationPath"] // "N/A"')
area: $(echo "$fields" | jq -r '.["System.AreaPath"] // "N/A"')
tags: $(echo "$fields" | jq -r '.["System.Tags"] // "none"')
${parent_info}
url: https://dev.azure.com/${ADO_ORGANIZATION}/${ADO_PROJECT}/_workitems/edit/${work_item_id}
description: |
$(echo "$fields" | jq -r '.["System.Description"] // "No description"' | sed 's/<[^>]*>//g' | sed 's/^/  /')
EOF
