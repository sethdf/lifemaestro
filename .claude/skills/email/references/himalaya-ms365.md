# Himalaya MS365/Outlook Setup

## 1. Install Himalaya

```bash
# macOS
brew install himalaya

# Linux/cargo
cargo install himalaya

# Verify
himalaya --version
```

## 2. Register Azure AD Application

1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to: Azure Active Directory → App registrations → New registration
3. Configure:
   - Name: "Himalaya Email Client"
   - Supported account types: "Accounts in this organizational directory only"
   - Redirect URI: `http://localhost` (Web)
4. Note the **Application (client) ID** and **Directory (tenant) ID**
5. Create client secret:
   - Certificates & secrets → New client secret
   - Note the secret value (only shown once!)
6. Add API permissions:
   - API permissions → Add permission → Microsoft Graph
   - Delegated permissions:
     - `IMAP.AccessAsUser.All`
     - `SMTP.Send`
     - `offline_access`
   - Grant admin consent

## 3. Configure Himalaya

Create/edit `~/.config/himalaya/config.toml`:

```toml
[accounts.ms365]
default = false
email = "your.email@company.com"
display-name = "Your Name"

backend.type = "imap"
backend.host = "outlook.office365.com"
backend.port = 993
backend.encryption = "tls"
backend.login = "your.email@company.com"
backend.auth.type = "oauth2"
backend.auth.client-id = "YOUR_APPLICATION_CLIENT_ID"
backend.auth.client-secret.keyring = "ms365-oauth-secret"
backend.auth.access-token.keyring = "ms365-oauth-access"
backend.auth.refresh-token.keyring = "ms365-oauth-refresh"
backend.auth.auth-url = "https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/authorize"
backend.auth.token-url = "https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/token"
backend.auth.scopes = [
    "https://outlook.office365.com/IMAP.AccessAsUser.All",
    "https://outlook.office365.com/SMTP.Send",
    "offline_access"
]

sender.type = "smtp"
sender.host = "smtp.office365.com"
sender.port = 587
sender.encryption = "starttls"
sender.login = "your.email@company.com"
sender.auth.type = "oauth2"
sender.auth.client-id = "YOUR_APPLICATION_CLIENT_ID"
sender.auth.client-secret.keyring = "ms365-oauth-secret"
sender.auth.access-token.keyring = "ms365-oauth-access"
sender.auth.refresh-token.keyring = "ms365-oauth-refresh"
sender.auth.auth-url = "https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/authorize"
sender.auth.token-url = "https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/token"
sender.auth.scopes = [
    "https://outlook.office365.com/IMAP.AccessAsUser.All",
    "https://outlook.office365.com/SMTP.Send",
    "offline_access"
]
```

Replace:
- `YOUR_APPLICATION_CLIENT_ID` with your Azure app client ID
- `YOUR_TENANT_ID` with your Azure tenant ID
- `your.email@company.com` with your MS365 email

## 4. Store Client Secret

```bash
# Store OAuth client secret in system keyring
secret-tool store --label="ms365-oauth-secret" account ms365 type oauth-secret
# Enter your Azure app client secret when prompted
```

## 5. Authenticate

```bash
himalaya account configure ms365
# Browser will open for Microsoft login
```

## 6. Test

```bash
himalaya envelope list --account ms365
```

## Troubleshooting

**"AADSTS50011" error**: Redirect URI mismatch. Check Azure app registration.

**"Insufficient privileges"**: Ensure API permissions have admin consent.

**IMAP disabled**: Some MS365 tenants disable IMAP. Contact your admin.

## References

- [Himalaya docs](https://pimalaya.org/himalaya/)
- [MS365 IMAP/OAuth setup](https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth)
