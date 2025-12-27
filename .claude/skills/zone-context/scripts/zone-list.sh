#!/usr/bin/env bash
# zone-list.sh - List all configured zones
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

if ! command -v dasel &>/dev/null; then
    echo "Error: dasel required for zone listing" >&2
    echo "Install: brew install dasel" >&2
    exit 1
fi

if [[ ! -f "$MAESTRO_CONFIG" ]]; then
    echo "Error: Config not found at $MAESTRO_CONFIG" >&2
    exit 1
fi

echo "Configured Zones:"
echo "================="

# Get all zone names (keys under [zones] except 'default' and 'detection')
dasel -f "$MAESTRO_CONFIG" -r toml 'zones' -w json 2>/dev/null | \
    jq -r 'keys[] | select(. != "default" and . != "detection")' | \
while read -r zone; do
    name=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.name" 2>/dev/null || echo "$zone")
    desc=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.description" 2>/dev/null || echo "")
    features=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.features" -w json 2>/dev/null | \
        jq -r 'to_entries | map(select(.value == true) | .key) | join(", ")' 2>/dev/null || echo "none")

    echo ""
    echo "[$zone]"
    echo "  Name: $name"
    [[ -n "$desc" ]] && echo "  Description: $desc"
    echo "  Features: ${features:-none}"
done

# Show current zone
echo ""
echo "Current Zone:"
"$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" | sed 's/^/  /'
