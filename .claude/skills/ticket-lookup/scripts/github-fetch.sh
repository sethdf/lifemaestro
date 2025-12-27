#!/usr/bin/env bash
# github-fetch.sh - Fetch issue details from GitHub
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

# Parse arguments
if [[ $# -eq 1 ]]; then
    # Single argument: could be #123, owner/repo#123, or URL
    ref="$1"

    if [[ "$ref" =~ ^https://github.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
        issue_num="${BASH_REMATCH[3]}"
    elif [[ "$ref" =~ ^([^/]+)/([^#]+)#([0-9]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
        issue_num="${BASH_REMATCH[3]}"
    elif [[ "$ref" =~ ^#?([0-9]+)$ ]]; then
        # Just a number, try to get repo from current directory
        issue_num="${BASH_REMATCH[1]}"
        if command -v gh &>/dev/null; then
            repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name' 2>/dev/null || echo "")
            if [[ -n "$repo_info" ]]; then
                owner="${repo_info%/*}"
                repo="${repo_info#*/}"
            else
                echo "Error: Cannot determine repository. Use: github-fetch.sh owner/repo#123" >&2
                exit 1
            fi
        else
            echo "Error: Cannot determine repository. Use: github-fetch.sh owner/repo#123" >&2
            exit 1
        fi
    else
        echo "Usage: github-fetch.sh <owner> <repo> <issue-number>" >&2
        echo "   or: github-fetch.sh owner/repo#123" >&2
        echo "   or: github-fetch.sh #123 (in a git repo)" >&2
        exit 1
    fi
elif [[ $# -eq 3 ]]; then
    owner="$1"
    repo="$2"
    issue_num="$3"
else
    echo "Usage: github-fetch.sh <owner> <repo> <issue-number>" >&2
    echo "   or: github-fetch.sh owner/repo#123" >&2
    exit 1
fi

# Get current zone
zone=$("$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" | grep "^zone:" | cut -d' ' -f2)

# Check if GitHub Issues is enabled for this zone
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    gh_enabled=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.features.github_issues" 2>/dev/null || echo "true")
    if [[ "$gh_enabled" == "false" ]]; then
        echo "Error: GitHub Issues is not enabled for zone '$zone'" >&2
        exit 1
    fi
fi

# Prefer gh CLI if available
if command -v gh &>/dev/null; then
    response=$(gh issue view "$issue_num" --repo "$owner/$repo" \
        --json number,title,state,body,assignees,labels,createdAt,comments 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo "Error: Issue not found or no access" >&2
        exit 1
    fi

    # Output structured data
    cat <<EOF
ticket_id: ${owner}/${repo}#${issue_num}
title: $(echo "$response" | jq -r '.title // "N/A"')
status: $(echo "$response" | jq -r '.state // "N/A"')
priority: N/A
assignee: $(echo "$response" | jq -r '.assignees[0].login // "Unassigned"')
labels: $(echo "$response" | jq -r '[.labels[].name] | join(", ") // "none"')
created: $(echo "$response" | jq -r '.createdAt // "N/A"')
comments: $(echo "$response" | jq -r '.comments | length')
description: |
$(echo "$response" | jq -r '.body // "No description"' | sed 's/^/  /')
EOF
else
    # Fall back to API
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        echo "Error: gh CLI not available and GITHUB_TOKEN not set" >&2
        exit 1
    fi

    response=$(curl -s -X GET \
        "https://api.github.com/repos/${owner}/${repo}/issues/${issue_num}" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" 2>/dev/null)

    # Check for errors
    if echo "$response" | jq -e '.message' &>/dev/null; then
        error=$(echo "$response" | jq -r '.message')
        echo "Error: $error" >&2
        exit 1
    fi

    # Output structured data
    cat <<EOF
ticket_id: ${owner}/${repo}#${issue_num}
title: $(echo "$response" | jq -r '.title // "N/A"')
status: $(echo "$response" | jq -r '.state // "N/A"')
priority: N/A
assignee: $(echo "$response" | jq -r '.assignee.login // "Unassigned"')
labels: $(echo "$response" | jq -r '[.labels[].name] | join(", ") // "none"')
created: $(echo "$response" | jq -r '.created_at // "N/A"')
comments: $(echo "$response" | jq -r '.comments // 0')
description: |
$(echo "$response" | jq -r '.body // "No description"' | sed 's/^/  /')
EOF
fi
