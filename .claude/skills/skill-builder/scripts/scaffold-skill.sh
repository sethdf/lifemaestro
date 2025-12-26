#!/usr/bin/env bash
# scaffold-skill.sh - Create new skill from templates
# Wrapper for skills/scaffold.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAESTRO_ROOT="${MAESTRO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

exec "$MAESTRO_ROOT/skills/scaffold.sh" "$@"
