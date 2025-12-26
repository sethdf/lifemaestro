# Zone Switching Procedure

## Overview

Switching zones configures your environment for a specific context (personal, work, freelance, etc.).

## What Gets Configured

1. **Environment Variable**: `MAESTRO_ZONE` is set
2. **Git Identity**: `user.name` and `user.email` in local repo
3. **AWS Profile**: `AWS_PROFILE` environment variable
4. **SSH Host**: For GitHub operations using correct SSH key

## Switch Steps

1. Run the zone-switch tool:
   ```bash
   eval "$(~/.config/lifemaestro/.claude/skills/zone-context/tools/zone-switch.sh <zone-name>)"
   ```

2. For persistent switching in current shell, add to environment:
   ```bash
   export MAESTRO_ZONE="<zone-name>"
   ```

3. For permanent zone in a directory, create `.maestro-zone` file:
   ```bash
   echo "<zone-name>" > .maestro-zone
   ```

## Verification

After switching, verify with:
```bash
echo "Zone: $MAESTRO_ZONE"
git config user.email
echo "AWS Profile: $AWS_PROFILE"
```

## Common Issues

- **Git identity not changing**: Run `git config user.email` to verify local config
- **AWS credentials expired**: Run `aws sso login --profile <profile>` for the zone's profile
- **SSH key issues**: Verify `~/.ssh/config` has the correct Host alias for the zone's `github.ssh_host`
