# Jira Ticket Lookup

## Overview

Jira Cloud API v3 for fetching issue details.

## Authentication

For Jira Cloud, use API token:
```bash
export JIRA_EMAIL="you@company.com"
export JIRA_API_TOKEN="your-api-token"
```

Generate token at: https://id.atlassian.com/manage-profile/security/api-tokens

## API Endpoint

Base URL is configured per-zone in config.toml:
```toml
[zones.acme-corp.jira]
base_url = "https://acme-corp.atlassian.net"
project_key = "ACME"
```

## Fetch Issue Details

```bash
curl -s -X GET \
    "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}" \
    -H "Authorization: Basic $(echo -n "$JIRA_EMAIL:$JIRA_API_TOKEN" | base64)" \
    -H "Content-Type: application/json"
```

## Response Structure

```json
{
  "key": "ACME-123",
  "fields": {
    "summary": "Fix login timeout issue",
    "status": {
      "name": "In Progress"
    },
    "priority": {
      "name": "High"
    },
    "assignee": {
      "displayName": "Jane Smith",
      "emailAddress": "jane@company.com"
    },
    "reporter": {
      "displayName": "John Doe"
    },
    "description": {
      "content": [...]
    },
    "created": "2024-12-20T10:30:00.000+0000",
    "labels": ["backend", "urgent"]
  }
}
```

## Extracting Fields

```bash
echo "$response" | jq -r '.fields.summary'
echo "$response" | jq -r '.fields.status.name'
echo "$response" | jq -r '.fields.priority.name'
echo "$response" | jq -r '.fields.assignee.displayName'
```

## Description Parsing

Jira uses Atlassian Document Format (ADF). For plain text:
```bash
# Simple extraction (loses formatting)
echo "$response" | jq -r '.fields.description.content[].content[]?.text // empty' | tr '\n' ' '
```

## Search for Issues

```bash
# JQL search
curl -s -X GET \
    "${JIRA_BASE_URL}/rest/api/3/search?jql=project=${PROJECT_KEY}+AND+assignee=currentUser()" \
    -H "Authorization: Basic $(echo -n "$JIRA_EMAIL:$JIRA_API_TOKEN" | base64)"
```
