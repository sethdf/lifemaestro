#!/usr/bin/env bash
# zone-switch.sh - Switch to a different zone
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

zone="${1:-}"

if [[ -z "$zone" ]]; then
    echo "Usage: zone-switch.sh <zone-name>" >&2
    echo "Available zones:" >&2
    "$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-list.sh" >&2
    exit 1
fi

# Verify zone exists
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    zone_name=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.name" 2>/dev/null || true)
    if [[ -z "$zone_name" ]]; then
        echo "Error: Zone '$zone' not found in config" >&2
        exit 1
    fi
fi

# Export zone to current shell (caller needs to eval this)
echo "export MAESTRO_ZONE='$zone'"

# Get zone settings
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    git_user=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.git.user" 2>/dev/null || true)
    git_email=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.git.email" 2>/dev/null || true)
    github_ssh=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.github.ssh_host" 2>/dev/null || true)
    aws_profile=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.aws.profile" 2>/dev/null || true)

    # Configure git if in a git repo
    if [[ -d ".git" ]] && [[ -n "$git_user" ]] && [[ -n "$git_email" ]]; then
        echo "git config user.name '$git_user'"
        echo "git config user.email '$git_email'"
    fi

    # Export AWS profile
    if [[ -n "$aws_profile" ]]; then
        echo "export AWS_PROFILE='$aws_profile'"
    fi
fi

echo "# Zone switched to: $zone"
echo "# Run: eval \"\$(zone-switch.sh $zone)\" to apply"
