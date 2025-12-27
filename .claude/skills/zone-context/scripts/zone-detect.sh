#!/usr/bin/env bash
# zone-detect.sh - Detect current zone from directory or environment
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

# Check explicit environment variable first
if [[ -n "${MAESTRO_ZONE:-}" ]]; then
    echo "zone: $MAESTRO_ZONE"
    echo "source: environment"
    exit 0
fi

# Get current directory
current_dir="$(pwd)"

# Try to match against patterns in config
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    # Get patterns array length
    pattern_count=$(dasel -f "$MAESTRO_CONFIG" -r toml 'zones.detection.patterns.len()' 2>/dev/null || echo "0")

    for ((i=0; i<pattern_count; i++)); do
        pattern=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.detection.patterns.[$i].pattern" 2>/dev/null || true)
        zone=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.detection.patterns.[$i].zone" 2>/dev/null || true)

        # Expand ~ in pattern
        expanded_pattern="${pattern/#\~/$HOME}"

        if [[ "$current_dir" =~ $expanded_pattern ]]; then
            echo "zone: $zone"
            echo "source: pattern_match"
            echo "pattern: $pattern"
            exit 0
        fi
    done
fi

# Fall back to default zone
default_zone="personal"
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    default_zone=$(dasel -f "$MAESTRO_CONFIG" -r toml 'zones.default.name' 2>/dev/null || echo "personal")
fi

echo "zone: $default_zone"
echo "source: default"
