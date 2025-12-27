# gcalcli Setup (Google Calendar)

## 1. Install gcalcli

```bash
# pip
pip install gcalcli

# macOS
brew install gcalcli

# Verify
gcalcli --version
```

## 2. Create Google Cloud OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing)
3. Enable Google Calendar API:
   - APIs & Services → Library → Search "Google Calendar API" → Enable
4. Configure OAuth consent screen:
   - APIs & Services → OAuth consent screen
   - User Type: External (or Internal for Workspace)
   - Fill in app name, user support email
   - Add scopes: `../auth/calendar`
5. Create OAuth credentials:
   - APIs & Services → Credentials → Create Credentials → OAuth client ID
   - Application type: Desktop app
   - Name: "gcalcli"
   - Download JSON

## 3. Configure gcalcli

```bash
# Set credentials path
export GCALCLI_OAUTH_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GCALCLI_OAUTH_CLIENT_SECRET="your-client-secret"

# Or use client secrets file
gcalcli --client-id=your-client-id --client-secret=your-client-secret init
```

Or place credentials in `~/.gcalcli_oauth`:
```json
{
  "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
  "client_secret": "YOUR_CLIENT_SECRET"
}
```

## 4. Authenticate

```bash
gcalcli init
# Browser opens for Google OAuth consent
# Grant calendar access
```

Tokens stored in `~/.gcalcli_oauth`

## 5. Test

```bash
# List calendars
gcalcli list

# Show agenda
gcalcli agenda

# Show today
gcalcli agenda --nostarted
```

## Common Commands

```bash
# List calendars
gcalcli list

# Show agenda (next 5 days)
gcalcli agenda

# Show specific date range
gcalcli agenda "2024-01-01" "2024-01-07"

# Add event (natural language)
gcalcli add --calendar "Work" --title "Team Meeting" \
  --when "tomorrow 2pm" --duration 60 --where "Conf Room A"

# Quick add (Google's natural language)
gcalcli quick "Lunch with John Friday noon"

# Search events
gcalcli search "team meeting"

# Delete event
gcalcli delete --calendar "Work" "Team Meeting"

# Edit event
gcalcli edit --calendar "Work" "Team Meeting"
```

## Configuration File

Create `~/.gcalclirc`:
```ini
[gcalcli]
default-calendar = Work
military = false
detail-calendar = true
detail-location = true
detail-length = true
```

## Multiple Calendars

```bash
# List specific calendar
gcalcli --calendar "Personal" agenda

# Add to specific calendar
gcalcli --calendar "Personal" quick "Dentist Tuesday 10am"
```

## Troubleshooting

**"Access Not Configured" error**: Enable Google Calendar API in Cloud Console.

**"Access blocked" error**: App is in testing mode. Add your email as test user in OAuth consent screen.

**Token expired**: Run `gcalcli init` again.

## References

- [gcalcli GitHub](https://github.com/insanum/gcalcli)
- [Google Calendar API](https://developers.google.com/calendar)
