#!/usr/bin/env bash
# vendor/sync.sh - Manage external dependencies from GitHub
# Usage: vendor/sync.sh [command] [vendor-name]
#
# Commands:
#   sync [name]     Clone or update vendor(s) (default: all enabled)
#   list            List configured vendors
#   status          Show status of vendor repos
#   update [name]   Force update vendor(s)
#   clean [name]    Remove vendor repo(s)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAESTRO_ROOT="${MAESTRO_ROOT:-$(dirname "$SCRIPT_DIR")}"
VENDOR_DIR="$SCRIPT_DIR"
VENDOR_CONFIG="$VENDOR_DIR/vendor.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Parse YAML (simple parser for our format)
# Requires: grep, sed, awk
parse_yaml_vendors() {
    local yaml_file="$1"
    # Only parse vendors under the "vendors:" section, stop at "config:"
    awk '
        /^vendors:/ { in_vendors = 1; next }
        /^config:/ { in_vendors = 0 }
        /^[a-z]/ { in_vendors = 0 }
        in_vendors && /^  [a-z]/ {
            gsub(/:.*/, "");
            gsub(/^ +/, "");
            print
        }
    ' "$yaml_file"
}

get_vendor_field() {
    local yaml_file="$1"
    local vendor="$2"
    local field="$3"

    # Extract value after "field:" in the vendor section
    awk -v vendor="$vendor" -v field="$field" '
        /^  [a-z]/ { in_vendor = ($1 == vendor":") }
        in_vendor && $1 == field":" {
            gsub(/^[^:]+: *"?/, "");
            gsub(/"$/, "");
            print;
            exit
        }
    ' "$yaml_file"
}

is_vendor_enabled() {
    local yaml_file="$1"
    local vendor="$2"
    local enabled
    enabled=$(get_vendor_field "$yaml_file" "$vendor" "enabled")
    [[ "$enabled" == "true" ]]
}

# Sync a single vendor
sync_vendor() {
    local vendor="$1"
    local force="${2:-false}"

    if ! is_vendor_enabled "$VENDOR_CONFIG" "$vendor"; then
        log_warn "$vendor is disabled in vendor.yaml"
        return 0
    fi

    local repo branch desc
    repo=$(get_vendor_field "$VENDOR_CONFIG" "$vendor" "repo")
    branch=$(get_vendor_field "$VENDOR_CONFIG" "$vendor" "branch")
    desc=$(get_vendor_field "$VENDOR_CONFIG" "$vendor" "description")
    branch="${branch:-main}"

    if [[ -z "$repo" || "$repo" == *"YOURUSER"* ]]; then
        log_error "$vendor: repo URL not configured (update vendor.yaml)"
        log_info "Edit $VENDOR_CONFIG and set the repo URL for '$vendor'"
        return 1
    fi

    local target_dir="$VENDOR_DIR/$vendor"

    if [[ -d "$target_dir/.git" ]]; then
        if [[ "$force" == "true" ]]; then
            log_info "Updating $vendor..."
            (
                cd "$target_dir"
                git fetch origin "$branch" --depth=1 2>/dev/null || git fetch origin "$branch"
                git reset --hard "origin/$branch"
            )
            log_ok "$vendor updated"
        else
            log_info "$vendor already exists (use 'update' to refresh)"
        fi
    else
        log_info "Cloning $vendor..."
        log_info "  Repo: $repo"
        log_info "  Branch: $branch"

        # Try shallow clone first
        if git clone --depth=1 --branch "$branch" "$repo" "$target_dir" 2>/dev/null; then
            log_ok "$vendor cloned (shallow)"
        elif git clone --branch "$branch" "$repo" "$target_dir" 2>/dev/null; then
            log_ok "$vendor cloned"
        else
            log_error "Failed to clone $vendor from $repo"
            return 1
        fi
    fi

    # Show description
    if [[ -n "$desc" ]]; then
        log_info "  $desc"
    fi
}

# Sync all enabled vendors
sync_all() {
    local force="${1:-false}"
    local vendors
    vendors=$(parse_yaml_vendors "$VENDOR_CONFIG")

    if [[ -z "$vendors" ]]; then
        log_warn "No vendors configured in $VENDOR_CONFIG"
        return 0
    fi

    local failed=0
    for vendor in $vendors; do
        if is_vendor_enabled "$VENDOR_CONFIG" "$vendor"; then
            sync_vendor "$vendor" "$force" || ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "$failed vendor(s) failed to sync"
        return 1
    fi

    log_ok "All vendors synced"
}

# List configured vendors
list_vendors() {
    echo "Configured vendors:"
    echo ""

    local vendors
    vendors=$(parse_yaml_vendors "$VENDOR_CONFIG")

    for vendor in $vendors; do
        local repo enabled desc
        repo=$(get_vendor_field "$VENDOR_CONFIG" "$vendor" "repo")
        enabled=$(get_vendor_field "$VENDOR_CONFIG" "$vendor" "enabled")
        desc=$(get_vendor_field "$VENDOR_CONFIG" "$vendor" "description")

        local status_icon
        if [[ "$enabled" == "true" ]]; then
            status_icon="${GREEN}[enabled]${NC}"
        else
            status_icon="${YELLOW}[disabled]${NC}"
        fi

        echo -e "  $vendor $status_icon"
        if [[ -n "$desc" ]]; then
            echo "    $desc"
        fi
        echo "    Repo: $repo"
        echo ""
    done
}

# Show status of vendor repos
show_status() {
    echo "Vendor status:"
    echo ""

    local vendors
    vendors=$(parse_yaml_vendors "$VENDOR_CONFIG")

    for vendor in $vendors; do
        local target_dir="$VENDOR_DIR/$vendor"
        local enabled
        enabled=$(get_vendor_field "$VENDOR_CONFIG" "$vendor" "enabled")

        if [[ -d "$target_dir/.git" ]]; then
            local branch commit date
            branch=$(git -C "$target_dir" branch --show-current 2>/dev/null || echo "unknown")
            commit=$(git -C "$target_dir" log -1 --format="%h" 2>/dev/null || echo "unknown")
            date=$(git -C "$target_dir" log -1 --format="%cr" 2>/dev/null || echo "unknown")

            echo -e "  ${GREEN}$vendor${NC} (installed)"
            echo "    Branch: $branch @ $commit ($date)"
        elif [[ "$enabled" == "true" ]]; then
            echo -e "  ${YELLOW}$vendor${NC} (not installed - run 'sync')"
        else
            echo -e "  ${RED}$vendor${NC} (disabled)"
        fi
    done
}

# Clean vendor repo
clean_vendor() {
    local vendor="$1"
    local target_dir="$VENDOR_DIR/$vendor"

    if [[ -d "$target_dir" ]]; then
        log_info "Removing $vendor..."
        rm -rf "$target_dir"
        log_ok "$vendor removed"
    else
        log_info "$vendor not installed"
    fi
}

# Main
main() {
    local cmd="${1:-sync}"
    shift || true

    case "$cmd" in
        sync|s)
            if [[ -n "${1:-}" ]]; then
                sync_vendor "$1" false
            else
                sync_all false
            fi
            ;;
        update|u)
            if [[ -n "${1:-}" ]]; then
                sync_vendor "$1" true
            else
                sync_all true
            fi
            ;;
        list|ls|l)
            list_vendors
            ;;
        status|st)
            show_status
            ;;
        clean|rm)
            if [[ -n "${1:-}" ]]; then
                clean_vendor "$1"
            else
                log_error "Specify vendor to clean, or use 'clean-all'"
            fi
            ;;
        clean-all)
            local vendors
            vendors=$(parse_yaml_vendors "$VENDOR_CONFIG")
            for vendor in $vendors; do
                clean_vendor "$vendor"
            done
            ;;
        help|--help|-h)
            cat <<EOF
vendor/sync.sh - Manage external dependencies from GitHub

Usage: vendor/sync.sh [command] [vendor-name]

Commands:
  sync [name]     Clone or update vendor(s) (default: all enabled)
  update [name]   Force update vendor(s) to latest
  list            List configured vendors
  status          Show status of vendor repos
  clean <name>    Remove a vendor repo
  clean-all       Remove all vendor repos

Configuration:
  Edit vendor/vendor.yaml to add/configure vendors.

  To add PAI:
  1. Fork or create your PAI repo on GitHub
  2. Edit vendor/vendor.yaml
  3. Set the 'repo' URL under 'pai:'
  4. Run: vendor/sync.sh sync pai

Examples:
  vendor/sync.sh                    # Sync all enabled vendors
  vendor/sync.sh sync pai           # Sync just PAI
  vendor/sync.sh update             # Force update all
  vendor/sync.sh status             # Show what's installed
EOF
            ;;
        *)
            log_error "Unknown command: $cmd"
            echo "Run 'vendor/sync.sh help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
