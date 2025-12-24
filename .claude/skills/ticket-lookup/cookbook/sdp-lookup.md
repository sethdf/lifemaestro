# ServiceDesk Plus (SDP) Ticket Lookup

## Overview

ServiceDesk Plus is Zoho's IT service management platform. The API uses OAuth tokens for authentication.

## Authentication

Set the API key in environment:
```bash
export SDP_API_KEY="your-oauth-token"
```

Or configure in LifeMaestro secrets (sops-encrypted).

## API Endpoint

Base URL is configured per-zone in config.toml:
```toml
[zones.acme-corp.sdp]
base_url = "https://sdp.acme-corp.com/api/v3"
```

## Fetch Request Details

```bash
curl -s -X GET \
    "${SDP_BASE_URL}/requests/${TICKET_NUM}" \
    -H "Authorization: Zoho-oauthtoken ${SDP_API_KEY}" \
    -H "Content-Type: application/json"
```

## Response Structure

```json
{
  "request": {
    "id": 12345,
    "subject": "Memory spike on prod-server-01",
    "status": {
      "name": "Open",
      "id": 1
    },
    "priority": {
      "name": "High",
      "id": 2
    },
    "requester": {
      "name": "John Doe",
      "email": "john@company.com"
    },
    "technician": {
      "name": "Jane Smith"
    },
    "description": "Full ticket description here...",
    "created_time": {
      "display_value": "Dec 20, 2024 10:30 AM"
    }
  }
}
```

## Extracting Fields

Using jq:
```bash
echo "$response" | jq -r '.request.subject'
echo "$response" | jq -r '.request.status.name'
echo "$response" | jq -r '.request.priority.name'
echo "$response" | jq -r '.request.description'
```

## Common Issues

- **401 Unauthorized**: Token expired, need to regenerate OAuth token
- **404 Not Found**: Ticket number doesn't exist or no access
- **403 Forbidden**: User doesn't have permission to view ticket
