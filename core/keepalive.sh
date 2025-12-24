#!/usr/bin/env bash
# lifemaestro/core/keepalive.sh - Credential keepalive daemon

KEEPALIVE_INTERVAL="${KEEPALIVE_INTERVAL:-$(maestro::config 'keepalive.interval' 300)}"
KEEPALIVE_PID_FILE="$MAESTRO_RUNTIME/keepalive.pid"
KEEPALIVE_LOG="$MAESTRO_STATE/keepalive.log"

# Refresh thresholds (seconds before expiry)
AWS_REFRESH_THRESHOLD=$(maestro::config 'keepalive.thresholds.aws_sso' 3600)
OAUTH_REFRESH_THRESHOLD=$(maestro::config 'keepalive.thresholds.oauth' 600)
AZURE_REFRESH_THRESHOLD=$(maestro::config 'keepalive.thresholds.azure_ad' 3000)

# ============================================
# AWS SSO
# ============================================

keepalive::aws_sso_ttl() {
    local profile="$1"
    local cache_dir="$HOME/.aws/sso/cache"

    [[ -d "$cache_dir" ]] || { echo "0"; return; }

    local cache_file=$(ls -t "$cache_dir"/*.json 2>/dev/null | head -1)
    [[ -z "$cache_file" ]] && { echo "0"; return; }

    local expires_at=$(jq -r '.expiresAt // empty' "$cache_file" 2>/dev/null)
    [[ -z "$expires_at" ]] && { echo "0"; return; }

    # Parse ISO date
    local expires_epoch
    if date --version &>/dev/null 2>&1; then
        # GNU date
        expires_epoch=$(date -d "$expires_at" +%s 2>/dev/null)
    else
        # BSD date (macOS)
        expires_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null)
    fi

    local now=$(date +%s)
    echo $((expires_epoch - now))
}

keepalive::aws_sso_refresh() {
    local profile="$1"
    keepalive::log "Refreshing AWS SSO for profile: $profile"

    # Try non-interactive refresh first
    if aws sso login --profile "$profile" --no-browser 2>/dev/null; then
        keepalive::log "AWS SSO refreshed (no-browser)"
        return 0
    fi

    # Need interactive - notify user
    utils::notify "AWS SSO Expiring" "Profile $profile needs re-authentication" "critical"

    # Open terminal for auth if GUI available
    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        ${TERMINAL:-x-terminal-emulator} -e "aws sso login --profile $profile; read -p 'Press enter to close'" &
    fi

    return 1
}

keepalive::check_aws() {
    local profile="$1"
    AWS_PROFILE="$profile" aws sts get-caller-identity &>/dev/null
}

# ============================================
# AZURE AD
# ============================================

keepalive::azure_ttl() {
    local token_file="$HOME/.azure/msal_token_cache.json"
    [[ -f "$token_file" ]] || { echo "0"; return; }

    local expires=$(jq -r '.AccessToken | to_entries[0].value.expires_on // 0' "$token_file" 2>/dev/null)
    local now=$(date +%s)
    echo $((expires - now))
}

keepalive::azure_refresh() {
    keepalive::log "Refreshing Azure AD token"

    # Try silent refresh
    if az account get-access-token &>/dev/null; then
        keepalive::log "Azure token refreshed silently"
        return 0
    fi

    utils::notify "Azure Login Required" "Azure AD token expired" "critical"

    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        az login &
    fi

    return 1
}

keepalive::check_azure() {
    az account get-access-token &>/dev/null
}

# ============================================
# OAUTH (Mail via himalaya)
# ============================================

keepalive::oauth_check() {
    local account="$1"

    # Himalaya auto-refreshes OAuth - just check if it works
    if himalaya -a "$account" folders -o json &>/dev/null; then
        return 0
    fi

    return 1
}

keepalive::oauth_refresh() {
    local account="$1"
    keepalive::log "Refreshing OAuth for: $account"

    # Himalaya handles refresh automatically
    # If this fails, token is truly expired
    if himalaya -a "$account" folders &>/dev/null; then
        keepalive::log "OAuth refreshed for $account"
        return 0
    fi

    utils::notify "OAuth Expired" "$account needs re-authentication" "critical"
    return 1
}

# ============================================
# LOCAL SERVICES
# ============================================

keepalive::check_ollama() {
    curl -s --max-time 2 "http://localhost:11434/api/tags" &>/dev/null
}

keepalive::start_ollama() {
    if ! keepalive::check_ollama; then
        keepalive::log "Starting Ollama..."
        ollama serve &>/dev/null &
        sleep 2
    fi
}

# ============================================
# API KEYS (Validation only)
# ============================================

keepalive::check_api_key() {
    local provider="$1"

    case "$provider" in
        anthropic)
            [[ -n "${ANTHROPIC_API_KEY:-}" ]] && \
            curl -s -o /dev/null -w "%{http_code}" \
                -H "x-api-key: $ANTHROPIC_API_KEY" \
                -H "anthropic-version: 2023-06-01" \
                "https://api.anthropic.com/v1/models" | grep -q "200"
            ;;
        openai)
            [[ -n "${OPENAI_API_KEY:-}" ]] && \
            curl -s -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer $OPENAI_API_KEY" \
                "https://api.openai.com/v1/models" | grep -q "200"
            ;;
        gemini)
            [[ -n "${GEMINI_API_KEY:-}" ]] && \
            curl -s -o /dev/null -w "%{http_code}" \
                "https://generativelanguage.googleapis.com/v1/models?key=$GEMINI_API_KEY" | grep -q "200"
            ;;
        *)
            # Unknown - assume OK if env var is set
            local env_var=$(maestro::config "credentials.env.$provider")
            [[ -n "${!env_var:-}" ]]
            ;;
    esac
}

# ============================================
# BEDROCK
# ============================================

keepalive::check_bedrock() {
    local profile="${1:-}"
    local region="${2:-us-east-1}"

    AWS_PROFILE="$profile" aws bedrock list-foundation-models \
        --region "$region" \
        --max-results 1 \
        &>/dev/null
}

# ============================================
# MAIN CHECK LOOP
# ============================================

keepalive::check_all() {
    local status=0
    keepalive::log "Running credential check..."

    # Check each configured context
    for ctx in work home; do
        local ctx_enabled=$(maestro::config "contexts.$ctx.git.user" "")
        [[ -z "$ctx_enabled" ]] && continue

        keepalive::log "Checking context: $ctx"

        # AWS SSO
        local aws_profile=$(maestro::config "contexts.$ctx.aws.profile")
        if [[ -n "$aws_profile" ]]; then
            local ttl=$(keepalive::aws_sso_ttl "$aws_profile")
            keepalive::log "  AWS SSO ($aws_profile): $(utils::format_duration $ttl) remaining"

            if [[ "$ttl" -lt "$AWS_REFRESH_THRESHOLD" ]]; then
                keepalive::aws_sso_refresh "$aws_profile" || status=1
            fi
        fi

        # Bedrock (if using)
        local ai_backend=$(maestro::config "contexts.$ctx.ai.backend")
        if [[ "$ai_backend" == "bedrock" ]]; then
            local region=$(maestro::config "contexts.$ctx.aws.region" "us-east-1")
            if ! keepalive::check_bedrock "$aws_profile" "$region"; then
                keepalive::log "  Bedrock: FAILED"
                status=1
            else
                keepalive::log "  Bedrock: OK"
            fi
        fi

        # Mail OAuth
        local mail_account=$(maestro::config "contexts.$ctx.mail.account")
        if [[ -n "$mail_account" ]] && command -v himalaya &>/dev/null; then
            if keepalive::oauth_check "$mail_account"; then
                keepalive::log "  Mail ($mail_account): OK"
            else
                keepalive::log "  Mail ($mail_account): FAILED"
                keepalive::oauth_refresh "$mail_account" || status=1
            fi
        fi
    done

    # Check local services
    if [[ "$(maestro::config 'ai.ollama.enabled')" == "true" ]]; then
        if [[ "$(maestro::config 'ai.ollama.auto_start')" == "true" ]]; then
            keepalive::start_ollama
        fi
        if keepalive::check_ollama; then
            keepalive::log "  Ollama: OK"
        else
            keepalive::log "  Ollama: Not running"
        fi
    fi

    # Check API keys
    for provider in anthropic openai gemini; do
        if [[ "$(maestro::config "ai.$provider.enabled")" == "true" ]]; then
            if keepalive::check_api_key "$provider"; then
                keepalive::log "  $provider API: OK"
            else
                keepalive::log "  $provider API: Invalid or missing"
            fi
        fi
    done

    keepalive::log "Credential check complete (status: $status)"
    return $status
}

# ============================================
# DAEMON
# ============================================

keepalive::daemon() {
    keepalive::log "Starting keepalive daemon (interval: ${KEEPALIVE_INTERVAL}s)"

    echo $$ > "$KEEPALIVE_PID_FILE"
    trap 'rm -f "$KEEPALIVE_PID_FILE"; keepalive::log "Daemon stopped"' EXIT

    while true; do
        keepalive::check_all
        sleep "$KEEPALIVE_INTERVAL"
    done
}

keepalive::start() {
    if [[ -f "$KEEPALIVE_PID_FILE" ]] && kill -0 "$(cat "$KEEPALIVE_PID_FILE")" 2>/dev/null; then
        echo "Daemon already running (PID $(cat "$KEEPALIVE_PID_FILE"))"
        return 0
    fi

    keepalive::daemon &
    disown
    echo "Daemon started (PID $!)"
}

keepalive::stop() {
    if [[ -f "$KEEPALIVE_PID_FILE" ]]; then
        kill "$(cat "$KEEPALIVE_PID_FILE")" 2>/dev/null
        rm -f "$KEEPALIVE_PID_FILE"
        echo "Daemon stopped"
    else
        echo "Daemon not running"
    fi
}

keepalive::running() {
    [[ -f "$KEEPALIVE_PID_FILE" ]] && kill -0 "$(cat "$KEEPALIVE_PID_FILE")" 2>/dev/null
}

# ============================================
# STATUS
# ============================================

keepalive::status() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            LifeMaestro Credential Status                     ║"
    echo "║            $(date '+%Y-%m-%d %H:%M:%S')                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    for ctx in work home; do
        local ctx_enabled=$(maestro::config "contexts.$ctx.git.user" "")
        [[ -z "$ctx_enabled" ]] && continue

        echo "[$ctx]"

        # AWS SSO
        local aws_profile=$(maestro::config "contexts.$ctx.aws.profile")
        if [[ -n "$aws_profile" ]]; then
            local ttl=$(keepalive::aws_sso_ttl "$aws_profile")
            if [[ "$ttl" -gt 0 ]]; then
                echo "  AWS SSO ($aws_profile): ✅ $(utils::format_duration $ttl) remaining"
            else
                echo "  AWS SSO ($aws_profile): ❌ EXPIRED"
            fi
        fi

        # Bedrock
        local ai_backend=$(maestro::config "contexts.$ctx.ai.backend")
        if [[ "$ai_backend" == "bedrock" ]]; then
            if keepalive::check_bedrock "$aws_profile"; then
                echo "  Bedrock: ✅ Accessible"
            else
                echo "  Bedrock: ❌ Not accessible"
            fi
        fi

        # Mail
        local mail_account=$(maestro::config "contexts.$ctx.mail.account")
        if [[ -n "$mail_account" ]] && command -v himalaya &>/dev/null; then
            if keepalive::oauth_check "$mail_account"; then
                echo "  Mail ($mail_account): ✅ Valid"
            else
                echo "  Mail ($mail_account): ❌ Invalid"
            fi
        fi

        echo ""
    done

    echo "[Local Services]"
    if keepalive::check_ollama; then
        echo "  Ollama: ✅ Running"
    else
        echo "  Ollama: ⚪ Not running"
    fi

    echo ""
    echo "[API Keys]"
    for provider in anthropic openai gemini; do
        local env_var=$(maestro::config "credentials.env.$provider")
        if [[ -n "${!env_var:-}" ]]; then
            if keepalive::check_api_key "$provider"; then
                echo "  $provider: ✅ Valid"
            else
                echo "  $provider: ⚠️  Set but invalid"
            fi
        else
            echo "  $provider: ⚪ Not set"
        fi
    done

    echo ""
    if keepalive::running; then
        echo "Daemon: ✅ Running (PID $(cat "$KEEPALIVE_PID_FILE"))"
    else
        echo "Daemon: ⚪ Not running"
    fi
}

# ============================================
# LOGGING
# ============================================

keepalive::log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg" >> "$KEEPALIVE_LOG"

    if [[ -n "${MAESTRO_DEBUG:-}" ]]; then
        echo "$msg" >&2
    fi
}
