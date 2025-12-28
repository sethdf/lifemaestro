#!/usr/bin/env bash
# lifemaestro/core/init.sh - Bootstrap and initialization
#
# Configuration Precedence (highest to lowest):
#   1. Command line flags (handled by cli.sh)
#   2. Environment variables (MAESTRO_*)
#   3. Config file (~/.config/lifemaestro/config.toml)
#   4. Hardcoded defaults

set -euo pipefail

# ============================================
# PATHS (XDG compliant)
# ============================================

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"
MAESTRO_STATE="${MAESTRO_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/lifemaestro}"
MAESTRO_RUNTIME="${MAESTRO_RUNTIME:-${XDG_RUNTIME_DIR:-/tmp}/maestro-$USER}"
MAESTRO_DATA="${MAESTRO_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/lifemaestro}"

# Ensure directories exist
mkdir -p "$MAESTRO_STATE" "$MAESTRO_RUNTIME" "$MAESTRO_DATA"

# ============================================
# LOAD CLI MODULE FIRST
# ============================================

if [[ -f "$MAESTRO_ROOT/core/cli.sh" ]]; then
    source "$MAESTRO_ROOT/core/cli.sh"
fi

# ============================================
# CONFIG PARSING WITH PRECEDENCE
# ============================================

# Internal: read from config file only
maestro::_config_file() {
    local key="$1"
    local default="${2:-}"

    [[ -f "$MAESTRO_CONFIG" ]] || { echo "$default"; return; }

    # Use dasel if available (fast, proper TOML)
    if command -v dasel &>/dev/null; then
        dasel -f "$MAESTRO_CONFIG" -r toml "$key" 2>/dev/null || echo "$default"
        return
    fi

    # Fallback to yq if available
    if command -v yq &>/dev/null; then
        yq -r ".$key // \"$default\"" "$MAESTRO_CONFIG" 2>/dev/null || echo "$default"
        return
    fi

    # Last resort: grep-based (limited, flat keys only)
    grep -E "^${key//./\\.}\s*=" "$MAESTRO_CONFIG" 2>/dev/null | \
        cut -d'=' -f2- | tr -d ' "' || echo "$default"
}

# Main config function with precedence
# Priority: env var > config file > default
maestro::config() {
    local key="$1"
    local default="${2:-}"

    # 1. Check environment variable (convert dots to underscores, uppercase)
    #    e.g., "ai.default_provider" -> "MAESTRO_AI_DEFAULT_PROVIDER"
    local env_key="MAESTRO_$(echo "$key" | tr '[:lower:].' '[:upper:]_')"

    if [[ -n "${!env_key:-}" ]]; then
        echo "${!env_key}"
        return
    fi

    # 2. Check config file
    local file_val
    file_val=$(maestro::_config_file "$key" "")

    if [[ -n "$file_val" ]]; then
        echo "$file_val"
        return
    fi

    # 3. Return default
    echo "$default"
}

maestro::config_array() {
    local key="$1"

    if command -v dasel &>/dev/null; then
        dasel -f "$MAESTRO_CONFIG" -r toml -m "$key.[]" 2>/dev/null
        return
    fi

    if command -v yq &>/dev/null; then
        yq -r ".$key[]?" "$MAESTRO_CONFIG" 2>/dev/null
        return
    fi
}

# ============================================
# INITIALIZATION
# ============================================

maestro::init() {
    # Source core modules
    source "$MAESTRO_ROOT/core/utils.sh"
    source "$MAESTRO_ROOT/core/interfaces.sh"

    # Load keepalive
    if [[ -f "$MAESTRO_ROOT/core/keepalive.sh" ]]; then
        source "$MAESTRO_ROOT/core/keepalive.sh"
    fi

    # Load sessions
    if [[ -f "$MAESTRO_ROOT/sessions/session.sh" ]]; then
        source "$MAESTRO_ROOT/sessions/session.sh"
    fi

    # Load skills framework
    if [[ -f "$MAESTRO_ROOT/core/skills.sh" ]]; then
        source "$MAESTRO_ROOT/core/skills.sh"
    fi

    # Auto-start keepalive if configured
    if [[ "$(maestro::config 'keepalive.autostart.enabled')" == "true" ]]; then
        maestro::keepalive_autostart
    fi

    maestro::log "LifeMaestro initialized"
}

maestro::keepalive_autostart() {
    local method=$(maestro::config 'keepalive.autostart.method' 'background')

    case "$method" in
        systemd)
            systemctl --user is-active maestro-keepalive &>/dev/null || \
                systemctl --user start maestro-keepalive 2>/dev/null || true
            ;;
        background)
            local pidfile="$MAESTRO_RUNTIME/keepalive.pid"
            if [[ ! -f "$pidfile" ]] || ! kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
                keepalive::daemon &
                disown
            fi
            ;;
    esac
}

# ============================================
# LOGGING
# ============================================

maestro::log() {
    local msg="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to file
    echo "[$timestamp] [$level] $msg" >> "$MAESTRO_STATE/maestro.log"

    # Debug to stderr if MAESTRO_DEBUG is set
    if [[ -n "${MAESTRO_DEBUG:-}" ]]; then
        echo "[$level] $msg" >&2
    fi
}

# ============================================
# STATUS
# ============================================

maestro::status() {
    echo "LifeMaestro Status"
    echo "=================="
    echo ""
    echo "Root:    $MAESTRO_ROOT"
    echo "Config:  $MAESTRO_CONFIG"
    echo "State:   $MAESTRO_STATE"
    echo "Version: $MAESTRO_VERSION"
}

# ============================================
# DOCTOR (Health Check)
# ============================================

maestro::doctor() {
    local errors=0
    local warnings=0

    echo "LifeMaestro Health Check"
    echo "========================"
    echo ""

    # Check required dependencies
    echo "Dependencies:"
    local required_deps=(jq curl git)
    local optional_deps=(dasel fzf gh yq)

    for dep in "${required_deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            echo "  ✓ $dep"
        else
            echo "  ✗ $dep (REQUIRED)"
            ((errors++)) || true
        fi
    done

    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            echo "  ✓ $dep"
        else
            echo "  ○ $dep (optional)"
            ((warnings++)) || true
        fi
    done
    echo ""

    # Check config file
    echo "Configuration:"
    if [[ -f "$MAESTRO_CONFIG" ]]; then
        echo "  ✓ Config file: $MAESTRO_CONFIG"

        # Validate TOML syntax
        if command -v dasel &>/dev/null; then
            if dasel -f "$MAESTRO_CONFIG" -r toml "maestro.version" &>/dev/null; then
                echo "  ✓ Config syntax valid"
            else
                echo "  ✗ Config syntax invalid"
                ((errors++)) || true
            fi
        else
            echo "  ○ Config syntax (install dasel to validate)"
        fi
    else
        echo "  ✗ Config file not found: $MAESTRO_CONFIG"
        echo "    Fix: cp $MAESTRO_ROOT/config.toml $MAESTRO_CONFIG"
        ((errors++)) || true
    fi
    echo ""

    # Check zones
    echo "Zones:"
    if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
        local zones
        zones=$(dasel -f "$MAESTRO_CONFIG" -r toml -m 'zones.-' 2>/dev/null | grep -v '^default$\|^detection$' | head -5)
        if [[ -n "$zones" ]]; then
            while IFS= read -r zone; do
                local git_user
                git_user=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.git.user" 2>/dev/null || echo "")
                if [[ -n "$git_user" ]]; then
                    echo "  ✓ $zone (git: $git_user)"
                else
                    echo "  ○ $zone (no git identity configured)"
                    ((warnings++)) || true
                fi
            done <<< "$zones"
        else
            echo "  ✗ No zones configured"
            echo "    Fix: Add [zones.personal] section to config.toml"
            ((errors++)) || true
        fi
    else
        echo "  ○ Cannot check zones (dasel not installed)"
    fi
    echo ""

    # Check git
    echo "Git:"
    if git config user.name &>/dev/null; then
        echo "  ✓ Global user: $(git config user.name)"
    else
        echo "  ○ No global git user (will use zone-specific)"
    fi
    if git config user.email &>/dev/null; then
        echo "  ✓ Global email: $(git config user.email)"
    else
        echo "  ○ No global git email (will use zone-specific)"
    fi
    echo ""

    # Check sessions directory
    echo "Sessions:"
    local sessions_base="${SESSIONS_BASE:-$HOME/ai-sessions}"
    sessions_base="${sessions_base/#\~/$HOME}"
    if [[ -d "$sessions_base" ]]; then
        local session_count
        session_count=$(find "$sessions_base" -maxdepth 3 -type d -name ".git" 2>/dev/null | wc -l)
        echo "  ✓ Sessions directory: $sessions_base ($session_count sessions)"
    else
        echo "  ○ Sessions directory not created yet: $sessions_base"
        echo "    (Will be created on first 'session new')"
    fi
    echo ""

    # Check API keys (optional)
    echo "API Keys (optional):"
    local api_keys=(ANTHROPIC_API_KEY OPENAI_API_KEY SDP_API_KEY JIRA_API_TOKEN LINEAR_API_KEY GITHUB_TOKEN)
    local has_any_key=false
    for key in "${api_keys[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            echo "  ✓ $key (set)"
            has_any_key=true
        fi
    done
    if [[ "$has_any_key" == "false" ]]; then
        echo "  ○ No API keys configured (set as needed)"
    fi
    echo ""

    # Summary
    echo "─────────────────────────"
    if [[ $errors -eq 0 ]]; then
        if [[ $warnings -eq 0 ]]; then
            echo "✓ All checks passed!"
        else
            echo "✓ Ready to use ($warnings optional items)"
        fi
        return 0
    else
        echo "✗ $errors error(s), $warnings warning(s)"
        echo ""
        echo "Run 'maestro doctor' again after fixing errors."
        return 1
    fi
}

# Auto-init if sourced directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    maestro::init
    maestro::status
fi
