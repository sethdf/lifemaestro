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
# ADAPTER LOADING
# ============================================

declare -A MAESTRO_ADAPTERS

maestro::load_adapter() {
    local module="$1"
    local adapters

    # Get configured adapters for this module
    mapfile -t adapters < <(maestro::config_array "adapters.$module")

    # If none configured, use defaults
    if [[ ${#adapters[@]} -eq 0 ]]; then
        case "$module" in
            ai)      adapters=(claude ollama) ;;
            mail)    adapters=(himalaya imap) ;;
            secrets) adapters=(sops pass env) ;;
            search)  adapters=(notmuch grep) ;;
        esac
    fi

    # Try each adapter in order
    for adapter in "${adapters[@]}"; do
        local adapter_file="$MAESTRO_ROOT/adapters/$module/$adapter.sh"

        if [[ -f "$adapter_file" ]] && maestro::adapter_available "$module" "$adapter"; then
            source "$adapter_file"
            MAESTRO_ADAPTERS[$module]="$adapter"
            maestro::log "Loaded adapter: $module/$adapter"
            return 0
        fi
    done

    maestro::log "WARNING: No adapter found for $module"
    return 1
}

maestro::adapter_available() {
    local module="$1"
    local adapter="$2"

    case "$module/$adapter" in
        # AI adapters
        ai/claude)      command -v claude &>/dev/null ;;
        ai/ollama)      command -v ollama &>/dev/null && curl -s --max-time 1 localhost:11434 &>/dev/null ;;
        ai/openai)      [[ -n "${OPENAI_API_KEY:-}" ]] ;;
        ai/llm)         command -v llm &>/dev/null ;;
        ai/aider)       command -v aider &>/dev/null ;;

        # Mail adapters
        mail/himalaya)  command -v himalaya &>/dev/null ;;
        mail/neomutt)   command -v neomutt &>/dev/null ;;
        mail/imap)      command -v curl &>/dev/null ;;

        # Secrets adapters
        secrets/sops)   command -v sops &>/dev/null ;;
        secrets/pass)   command -v pass &>/dev/null ;;
        secrets/1password) command -v op &>/dev/null ;;
        secrets/env)    return 0 ;;  # Always available

        # Search adapters
        search/notmuch) command -v notmuch &>/dev/null ;;
        search/mu)      command -v mu &>/dev/null ;;
        search/grep)    return 0 ;;  # Always available

        # Unknown - assume available
        *) return 0 ;;
    esac
}

# ============================================
# INITIALIZATION
# ============================================

maestro::init() {
    # Source core modules
    source "$MAESTRO_ROOT/core/utils.sh"
    source "$MAESTRO_ROOT/core/interfaces.sh"

    # Load adapters
    maestro::load_adapter "secrets"  # Load first - others may need it
    maestro::load_adapter "ai"

    # Load optional modules
    [[ -f "$MAESTRO_ROOT/adapters/mail/${MAESTRO_ADAPTERS[mail]:-}.sh" ]] && maestro::load_adapter "mail"
    [[ -f "$MAESTRO_ROOT/adapters/search/${MAESTRO_ADAPTERS[search]:-}.sh" ]] && maestro::load_adapter "search"

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
    echo ""
    echo "Loaded Adapters:"
    for module in "${!MAESTRO_ADAPTERS[@]}"; do
        echo "  $module: ${MAESTRO_ADAPTERS[$module]}"
    done
}

# Auto-init if sourced directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    maestro::init
    maestro::status
fi
