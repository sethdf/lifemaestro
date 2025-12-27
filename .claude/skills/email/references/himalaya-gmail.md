# Himalaya Gmail Setup

## 1. Install Himalaya

```bash
# macOS
brew install himalaya

# Linux/cargo
cargo install himalaya

# Verify
himalaya --version
```

## 2. Create Google Cloud OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing)
3. Enable Gmail API:
   - APIs & Services → Library → Search "Gmail API" → Enable
4. Create OAuth credentials:
   - APIs & Services → Credentials → Create Credentials → OAuth client ID
   - Application type: Desktop app
   - Download JSON (save as `client_secret.json`)

## 3. Configure Himalaya

Create/edit `~/.config/himalaya/config.toml`:

```toml
[accounts.gmail]
default = true
email = "your.email@gmail.com"
display-name = "Your Name"

backend.type = "imap"
backend.host = "imap.gmail.com"
backend.port = 993
backend.encryption = "tls"
backend.login = "your.email@gmail.com"
backend.auth.type = "oauth2"
backend.auth.client-id = "YOUR_CLIENT_ID.apps.googleusercontent.com"
backend.auth.client-secret.keyring = "gmail-oauth-secret"
backend.auth.access-token.keyring = "gmail-oauth-access"
backend.auth.refresh-token.keyring = "gmail-oauth-refresh"
backend.auth.auth-url = "https://accounts.google.com/o/oauth2/auth"
backend.auth.token-url = "https://oauth2.googleapis.com/token"
backend.auth.scopes = ["https://mail.google.com/"]

sender.type = "smtp"
sender.host = "smtp.gmail.com"
sender.port = 465
sender.encryption = "tls"
sender.login = "your.email@gmail.com"
sender.auth.type = "oauth2"
sender.auth.client-id = "YOUR_CLIENT_ID.apps.googleusercontent.com"
sender.auth.client-secret.keyring = "gmail-oauth-secret"
sender.auth.access-token.keyring = "gmail-oauth-access"
sender.auth.refresh-token.keyring = "gmail-oauth-refresh"
sender.auth.auth-url = "https://accounts.google.com/o/oauth2/auth"
sender.auth.token-url = "https://oauth2.googleapis.com/token"
sender.auth.scopes = ["https://mail.google.com/"]
```

## 4. Store Client Secret

```bash
# Store OAuth client secret in system keyring
secret-tool store --label="gmail-oauth-secret" account gmail type oauth-secret
# Enter your client secret when prompted
```

## 5. Authenticate

```bash
himalaya account configure gmail
# Browser will open for OAuth consent
```

## 6. Test

```bash
himalaya envelope list --account gmail
```

## Troubleshooting

**"Access blocked" error**: Enable "Less secure app access" or ensure OAuth scopes are correct.

**Token refresh issues**: Re-run `himalaya account configure gmail`

## References

- [Himalaya docs](https://pimalaya.org/himalaya/)
- [Gmail IMAP settings](https://support.google.com/mail/answer/7126229)
