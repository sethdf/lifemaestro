# Linear Issue Lookup

## Overview

Linear uses a GraphQL API for all operations.

## Authentication

```bash
export LINEAR_API_KEY="lin_api_xxxxx"
```

Generate at: Linear Settings > API > Personal API keys

## API Endpoint

```
https://api.linear.app/graphql
```

## Fetch Issue Details

```bash
curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "query": "query { issue(id: \"ISSUE_ID\") { id identifier title description state { name } priority priorityLabel assignee { name email } createdAt } }"
    }'
```

## Response Structure

```json
{
  "data": {
    "issue": {
      "id": "abc123",
      "identifier": "ENG-456",
      "title": "Implement caching layer",
      "description": "Add Redis caching for API responses...",
      "state": {
        "name": "In Progress"
      },
      "priority": 2,
      "priorityLabel": "High",
      "assignee": {
        "name": "Jane Smith",
        "email": "jane@company.com"
      },
      "createdAt": "2024-12-20T10:30:00.000Z"
    }
  }
}
```

## Extracting Fields

```bash
echo "$response" | jq -r '.data.issue.title'
echo "$response" | jq -r '.data.issue.state.name'
echo "$response" | jq -r '.data.issue.priorityLabel'
echo "$response" | jq -r '.data.issue.description'
```

## Search Issues

```bash
curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "query": "query { issues(filter: { assignee: { isMe: { eq: true } }, state: { name: { nin: [\"Done\", \"Canceled\"] } } }) { nodes { identifier title state { name } } } }"
    }'
```

## Issue by Identifier

If you have the human-readable identifier (e.g., "ENG-456"):

```bash
curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "query": "query { issueSearch(query: \"ENG-456\") { nodes { id identifier title description state { name } } } }"
    }'
```
