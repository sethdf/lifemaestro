# GitHub Issues Lookup

## Overview

GitHub REST API v3 for fetching issue details. Uses `gh` CLI or direct API calls.

## Authentication

Preferred: Use GitHub CLI (already authenticated)
```bash
gh auth status
```

Or set token:
```bash
export GITHUB_TOKEN="ghp_xxxxx"
```

## Using gh CLI (Recommended)

```bash
# View issue
gh issue view 123 --repo owner/repo

# JSON output
gh issue view 123 --repo owner/repo --json title,state,body,assignees,labels
```

## Direct API Call

```bash
curl -s -X GET \
    "https://api.github.com/repos/${OWNER}/${REPO}/issues/${ISSUE_NUM}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json"
```

## Response Structure

```json
{
  "number": 123,
  "title": "Bug: Login fails on mobile",
  "state": "open",
  "body": "## Description\n\nWhen trying to login on mobile...",
  "user": {
    "login": "reporter-username"
  },
  "assignee": {
    "login": "assigned-username"
  },
  "labels": [
    {"name": "bug"},
    {"name": "high-priority"}
  ],
  "created_at": "2024-12-20T10:30:00Z",
  "comments": 5
}
```

## Extracting Fields

With gh CLI:
```bash
gh issue view 123 --repo owner/repo --json title,state,body,assignees -q '.title'
```

With curl + jq:
```bash
echo "$response" | jq -r '.title'
echo "$response" | jq -r '.state'
echo "$response" | jq -r '.body'
echo "$response" | jq -r '.assignee.login'
```

## Parsing Issue Reference

Common formats:
- `#123` - issue in current repo
- `owner/repo#123` - full reference
- `https://github.com/owner/repo/issues/123` - URL

```bash
# Extract from URL
echo "https://github.com/owner/repo/issues/123" | \
    sed -E 's|https://github.com/([^/]+)/([^/]+)/issues/([0-9]+)|\1 \2 \3|'
```

## List Issues

```bash
# My assigned issues
gh issue list --assignee @me

# By label
gh issue list --label "bug" --repo owner/repo
```
