#!/usr/bin/env bash
# session-migrate.sh - Add .session.json to existing sessions without metadata
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

# Parse arguments
dry_run=false
zone_filter="all"
force=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) dry_run=true; shift ;;
        --zone=*) zone_filter="${1#*=}"; shift ;;
        --force) force=true; shift ;;
        -h|--help)
            echo "Usage: session-migrate.sh [options]"
            echo ""
            echo "Add .session.json metadata files to existing sessions that don't have them."
            echo ""
            echo "Options:"
            echo "  --dry-run          Show what would be done without making changes"
            echo "  --zone=ZONE        Only migrate sessions in specific zone"
            echo "  --force            Overwrite existing .session.json files"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Get sessions base directory
sessions_base="${HOME}/ai-sessions"
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    sessions_base=$(dasel -f "$MAESTRO_CONFIG" -r toml 'sessions.base_dir' 2>/dev/null || echo "$sessions_base")
    sessions_base="${sessions_base/#\~/$HOME}"
fi

if [[ ! -d "$sessions_base" ]]; then
    echo "No sessions directory found at $sessions_base" >&2
    exit 1
fi

# Get list of zones to migrate
zones=()
if [[ "$zone_filter" == "all" ]]; then
    for zone_dir in "$sessions_base"/*/; do
        [[ -d "$zone_dir" ]] && zones+=("$(basename "$zone_dir")")
    done
else
    zones=("$zone_filter")
fi

echo "Session Migration"
echo "================="
echo ""
echo "Base directory: $sessions_base"
echo "Zones: ${zones[*]}"
echo "Dry run: $dry_run"
echo "Force overwrite: $force"
echo ""

migrated=0
skipped=0
errors=0

for zone in "${zones[@]}"; do
    zone_path="$sessions_base/$zone"
    [[ -d "$zone_path" ]] || continue

    echo "[$zone]"

    # Find all sessions with CLAUDE.md
    find "$zone_path" -maxdepth 3 -name "CLAUDE.md" -type f 2>/dev/null | \
        while read -r claude_file; do
            session_dir=$(dirname "$claude_file")
            session_name=$(basename "$session_dir")
            dir_type=$(basename "$(dirname "$session_dir")")
            metadata_file="$session_dir/.session.json"

            # Check if .session.json exists
            if [[ -f "$metadata_file" ]] && [[ "$force" != "true" ]]; then
                echo "  SKIP: $dir_type/$session_name (already has metadata)"
                ((skipped++)) || true
                continue
            fi

            # Try to determine created date from git or file modification
            created=""
            if [[ -d "$session_dir/.git" ]] || git -C "$session_dir" rev-parse --git-dir &>/dev/null 2>&1; then
                # Get first commit date
                created=$(git -C "$session_dir" log --reverse --format="%aI" 2>/dev/null | head -1)
            fi
            if [[ -z "$created" ]]; then
                # Fall back to file modification time
                created=$(date -r "$claude_file" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
            fi

            # Check if session is completed
            status="active"
            if grep -q "Session Completed\|Session completed" "$claude_file" 2>/dev/null; then
                status="closed"
            fi

            # Extract date from session name if present (YYYY-MM-DD prefix)
            if [[ "$session_name" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
                date_prefix="${BASH_REMATCH[1]}"
                created="${date_prefix}T00:00:00Z"
            fi

            if [[ "$dry_run" == "true" ]]; then
                echo "  WOULD CREATE: $dir_type/$session_name"
                echo "    zone: $zone, type: $dir_type, status: $status"
            else
                # Create .session.json
                cat > "$metadata_file" <<EOF
{
  "id": "$session_name",
  "created": "$created",
  "closed": null,
  "status": "$status",
  "zone": "$zone",
  "type": "$dir_type",
  "tags": [],
  "category": null,
  "outcome": null,
  "learnings": [],
  "summary": null
}
EOF
                if [[ $? -eq 0 ]]; then
                    echo "  CREATED: $dir_type/$session_name"
                    ((migrated++)) || true
                else
                    echo "  ERROR: Failed to create metadata for $dir_type/$session_name"
                    ((errors++)) || true
                fi
            fi
        done
done

echo ""
echo "Summary:"
if [[ "$dry_run" == "true" ]]; then
    echo "  (Dry run - no changes made)"
fi
echo "  Migrated: $migrated"
echo "  Skipped: $skipped"
echo "  Errors: $errors"

if [[ $migrated -gt 0 ]] && [[ "$dry_run" != "true" ]]; then
    echo ""
    echo "Sessions migrated. Use 'session close' in Claude Code to add AI categorization."
fi
