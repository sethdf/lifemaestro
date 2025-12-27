# Thallo Setup (MS365/Outlook Calendar)

## 1. Prerequisites

```bash
# Install GPG (required for token encryption)
# macOS
brew install gnupg

# Linux
sudo apt install gnupg

# Generate GPG key if you don't have one
gpg --full-generate-key
# Choose: RSA, 4096 bits, no expiration
# Note your key ID
```

## 2. Install Thallo

```bash
pip install thallo

# Verify
thallo --help
```

## 3. Register Azure AD Application

1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to: Azure Active Directory → App registrations → New registration
3. Configure:
   - Name: "Thallo Calendar CLI"
   - Supported account types: "Accounts in this organizational directory only"
   - Redirect URI: `http://localhost:8400` (Web)
4. Note the **Application (client) ID**
5. Create client secret:
   - Certificates & secrets → New client secret
   - Note the secret value
6. Add API permissions:
   - API permissions → Add permission → Microsoft Graph
   - Delegated permissions:
     - `Calendars.ReadWrite`
     - `offline_access`
   - Grant admin consent

## 4. Configure Thallo

Create `~/.config/thallo/config.toml`:

```toml
[azure]
client_id = "YOUR_APPLICATION_CLIENT_ID"
tenant_id = "YOUR_TENANT_ID"

[gpg]
key_id = "YOUR_GPG_KEY_ID"

[calendar]
default = "Calendar"
```

Or set environment variables:
```bash
export THALLO_CLIENT_ID="your-client-id"
export THALLO_TENANT_ID="your-tenant-id"
export THALLO_GPG_KEY="your-gpg-key-id"
```

## 5. Authenticate

```bash
thallo authorize
# Browser opens for Microsoft login
# Grant calendar access
# Token encrypted and stored in ~/.thallo/
```

## 6. Test

```bash
# Fetch calendar events
thallo fetch

# Get event details
thallo info
```

## Common Commands

```bash
# Authorize/re-authorize
thallo authorize

# Fetch events (default: today)
thallo fetch

# Fetch specific date range
thallo fetch --start "2024-01-01" --end "2024-01-07"

# Get event/day details
thallo info

# Add event
thallo add --title "Team Meeting" --start "2024-01-15T14:00" \
  --end "2024-01-15T15:00" --location "Conf Room"
```

## Token Storage

Thallo encrypts tokens using GPG:
- Stored in `~/.thallo/`
- Requires GPG key for decryption
- Automatic token refresh

## Troubleshooting

**"No GPG key"**: Generate a GPG key first (see Prerequisites).

**"AADSTS50011" error**: Check redirect URI matches `http://localhost:8400`.

**"Insufficient privileges"**: Ensure `Calendars.ReadWrite` has admin consent.

**Token decrypt failed**: Ensure GPG agent is running: `gpg-agent --daemon`

## Limitations

- Thallo is relatively new (Nov 2024)
- Basic feature set compared to gcalcli
- No recurring event editing (yet)
- No natural language parsing (yet)

## References

- [Thallo GitHub](https://github.com/fjebaker/thallo)
- [MS Graph Calendar API](https://learn.microsoft.com/en-us/graph/api/resources/calendar)
