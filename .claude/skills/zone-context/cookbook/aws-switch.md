# AWS Profile Switching for Zones

## Overview

Each zone can have a dedicated AWS profile configured in `~/.aws/config`.

## SSO-Based Profiles

Modern AWS setup uses IAM Identity Center (SSO):

```ini
# ~/.aws/config

[profile personal-sso]
sso_start_url = https://my-personal.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = PowerUserAccess
region = us-west-2

[profile work-sso]
sso_start_url = https://acme-corp.awsapps.com/start
sso_region = us-east-1
sso_account_id = 987654321098
sso_role_name = DeveloperAccess
region = us-east-1
```

## Switching Profiles

1. **Set profile for current session**:
   ```bash
   export AWS_PROFILE="work-sso"
   ```

2. **Login if credentials expired**:
   ```bash
   aws sso login --profile work-sso
   ```

3. **Verify credentials**:
   ```bash
   aws sts get-caller-identity
   ```

## Automatic Switching

The zone-switch tool automatically exports `AWS_PROFILE` based on the zone's `aws.profile` setting.

```bash
eval "$(zone-switch.sh acme-corp)"
# Now AWS_PROFILE is set to the zone's configured profile
```

## Credential Refresh

If credentials expire during a session:

```bash
# For SSO profiles
aws sso login

# Or use LifeMaestro keepalive to auto-refresh
maestro creds refresh aws
```

## Bedrock Access

For zones using Claude via AWS Bedrock:
1. Ensure the zone's AWS profile has Bedrock permissions
2. Set `ai.backend = "bedrock"` in the zone config
3. The AI provider will automatically use Bedrock when in that zone
