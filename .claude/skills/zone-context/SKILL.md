---
name: zone-context
description: Manage LifeMaestro zones (work contexts). Use when user mentions switching context, zones, work vs personal, or asks about current zone.
allowed-tools:
  - Bash
  - Read
---

# Zone Context Management

Zones are flexible namespaces that configure git identity, AWS profiles, GitHub accounts, and other settings for different contexts (personal, work-employer1, freelance, etc.).

## Variables

- enable_zone_switch: true
- enable_zone_detect: true
- enable_git_config: true
- enable_aws_switch: true
- config_path: ~/.config/lifemaestro/config.toml

## Instructions

### Zone Operations

If user asks about current zone or context:
- Run `tools/zone-detect.sh` to detect zone from current directory
- Report the active zone and its settings

If user wants to switch zones:
- Read references/zone-switch.md for the switch procedure
- Run `tools/zone-switch.sh <zone-name>` to apply the switch

If user wants to list available zones:
- Run `tools/zone-list.sh` to show configured zones

If user wants to configure git for current zone AND enable_git_config is true:
- Read references/git-config.md for git configuration steps

If user wants to switch AWS profile AND enable_aws_switch is true:
- Read references/aws-switch.md for AWS SSO/profile switching

### Zone Detection Logic

Zones are detected by:
1. Explicit `MAESTRO_ZONE` environment variable
2. Pattern matching current directory against `zones.detection.patterns` in config
3. Falling back to `zones.default.name`

## Available Zones

Zones are defined in config.toml under `[zones.<name>]`. Each zone can have:
- `git.user` and `git.email` - Git identity
- `github.ssh_host` and `github.username` - GitHub account
- `aws.profile` and `aws.region` - AWS configuration
- `ai.provider` and `ai.backend` - AI provider settings
- `features.*` - Optional features (tickets, sdp, jira, etc.)

## Example Usage

```
User: "What zone am I in?"
-> Run tools/zone-detect.sh

User: "Switch to work context"
-> Run tools/zone-switch.sh acme-corp

User: "List my zones"
-> Run tools/zone-list.sh

User: "Set up git for this zone"
-> Read references/git-config.md, then apply git config
```
