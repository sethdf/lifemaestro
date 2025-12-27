#!/usr/bin/env bash
# lifemaestro/core/keepalive.sh - Credential keepalive daemon

KEEPALIVE_INTERVAL="${KEEPALIVE_INTERVAL:-$(maestro::config 'keepalive.interval' 300)}"
KEEPALIVE_PID_FILE="$MAESTRO_RUNTIME/keepalive.pid"
KEEPALIVE_LOG="$MAESTRO_STATE/keepalive.log"

# Refresh thresholds (seconds before expiry)
AWS_REFRESH_THRESHOLD=$(maestro::config 'keepalive.thresholds.aws_sso' 3600)
OAUTH_REFRESH_THRESHOLD=$(maestro::config 'keepalive.thresholds.oauth' 600)
AZURE_REFRESH_THRESHOLD=$(maestro::config 'keepalive.thresholds.azure_ad' 3000)
GCP_REFRESH_THRESHOLD=$(maestro::config 'keepalive.thresholds.gcp' 600)
CLAUDE_CODE_REFRESH_THRESHOLD=$(maestro::config 'keepalive.thresholds.claude_code' 86400)

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
# GCP (Google Cloud Platform)
# ============================================

keepalive::gcp_ttl() {
    local creds_file="$HOME/.config/gcloud/application_default_credentials.json"

    # Check for ADC credentials
    if [[ ! -f "$creds_file" ]]; then
        echo "0"
        return
    fi

    # ADC refresh tokens don't expire, but access tokens do
    # Check if we can get a valid token
    local token_info
    token_info=$(gcloud auth application-default print-access-token 2>/dev/null) || {
        echo "0"
        return
    }

    # If we got a token, check its expiry via tokeninfo endpoint
    local expiry
    expiry=$(curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$token_info" 2>/dev/null | \
        jq -r '.expires_in // 0' 2>/dev/null)

    echo "${expiry:-0}"
}

keepalive::gcp_refresh() {
    keepalive::log "Refreshing GCP credentials"

    # Try to refresh silently first
    if gcloud auth application-default print-access-token &>/dev/null; then
        keepalive::log "GCP credentials valid"
        return 0
    fi

    utils::notify "GCP Login Required" "Application default credentials expired" "critical"

    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        ${TERMINAL:-x-terminal-emulator} -e "gcloud auth application-default login; read -p 'Press enter to close'" &
    fi

    return 1
}

keepalive::check_gcp() {
    gcloud auth application-default print-access-token &>/dev/null
}

keepalive::gcp_project() {
    gcloud config get-value project 2>/dev/null
}

# ============================================
# VERTEX AI (Gemini via GCP)
# ============================================

keepalive::check_vertex_ai() {
    local project="${1:-$(keepalive::gcp_project)}"
    local region="${2:-us-central1}"

    [[ -z "$project" ]] && return 1

    # Check if we can list models (lightweight check)
    curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $(gcloud auth application-default print-access-token 2>/dev/null)" \
        "https://${region}-aiplatform.googleapis.com/v1/projects/${project}/locations/${region}/publishers/google/models" \
        2>/dev/null | grep -q "200"
}

# ============================================
# CLAUDE CODE (OAuth)
# ============================================

keepalive::claude_code_auth_file() {
    # Claude Code stores auth in different locations
    local possible_paths=(
        "$HOME/.claude/auth.json"
        "$HOME/.config/claude/auth.json"
        "$HOME/.claude.json"
    )

    for path in "${possible_paths[@]}"; do
        [[ -f "$path" ]] && { echo "$path"; return 0; }
    done

    return 1
}

keepalive::claude_code_ttl() {
    local auth_file
    auth_file=$(keepalive::claude_code_auth_file) || { echo "0"; return; }

    local expires_at
    expires_at=$(jq -r '.expiresAt // .expires_at // .expiry // empty' "$auth_file" 2>/dev/null)

    [[ -z "$expires_at" ]] && { echo "-1"; return; }  # -1 means no expiry info (could be valid)

    local expires_epoch now
    now=$(date +%s)

    # Try parsing as epoch or ISO date
    if [[ "$expires_at" =~ ^[0-9]+$ ]]; then
        expires_epoch="$expires_at"
    else
        if date --version &>/dev/null 2>&1; then
            expires_epoch=$(date -d "$expires_at" +%s 2>/dev/null)
        else
            expires_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null)
        fi
    fi

    [[ -z "$expires_epoch" ]] && { echo "-1"; return; }

    echo $((expires_epoch - now))
}

keepalive::check_claude_code() {
    # Check if claude CLI is authenticated
    if command -v claude &>/dev/null; then
        # Try a simple command that requires auth
        claude --version &>/dev/null && return 0
    fi

    # Fallback: check if auth file exists and has content
    local auth_file
    auth_file=$(keepalive::claude_code_auth_file) || return 1

    [[ -s "$auth_file" ]]
}

keepalive::claude_code_refresh() {
    keepalive::log "Claude Code auth needs refresh"

    utils::notify "Claude Code Login Required" "Run 'claude login' to re-authenticate" "critical"

    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        ${TERMINAL:-x-terminal-emulator} -e "claude login; read -p 'Press enter to close'" &
    fi

    return 1
}

# ============================================
# BITWARDEN
# ============================================

keepalive::bw_status() {
    command -v bw &>/dev/null || { echo "not_installed"; return; }
    bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown"
}

keepalive::check_bitwarden() {
    [[ "$(keepalive::bw_status)" == "unlocked" ]]
}

keepalive::bw_refresh() {
    local status=$(keepalive::bw_status)

    case "$status" in
        unlocked)
            keepalive::log "Bitwarden: Already unlocked"
            return 0
            ;;
        locked)
            keepalive::log "Bitwarden vault locked, attempting unlock..."
            # Try to unlock - will prompt for master password
            if BW_SESSION=$(bw unlock --raw 2>/dev/null); then
                export BW_SESSION
                keepalive::log "Bitwarden: Unlocked"
                return 0
            fi
            utils::notify "Bitwarden Locked" "Vault needs to be unlocked" "normal"
            return 1
            ;;
        unauthenticated)
            utils::notify "Bitwarden Login Required" "Run 'bw login' to authenticate" "critical"
            return 1
            ;;
        not_installed)
            return 0  # Not an error if not installed
            ;;
        *)
            keepalive::log "Bitwarden: Unknown status ($status)"
            return 1
            ;;
    esac
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

        # GCP
        local gcp_project=$(maestro::config "contexts.$ctx.gcp.project")
        if [[ -n "$gcp_project" ]]; then
            local ttl=$(keepalive::gcp_ttl)
            keepalive::log "  GCP ($gcp_project): $(utils::format_duration $ttl) remaining"

            if [[ "$ttl" -lt "$GCP_REFRESH_THRESHOLD" ]]; then
                keepalive::gcp_refresh || status=1
            fi
        fi

        # Vertex AI (Gemini via GCP)
        if [[ "$ai_backend" == "vertex" ]] || [[ "$ai_backend" == "vertex_ai" ]]; then
            local gcp_region=$(maestro::config "contexts.$ctx.gcp.region" "us-central1")
            if ! keepalive::check_vertex_ai "$gcp_project" "$gcp_region"; then
                keepalive::log "  Vertex AI: FAILED"
                status=1
            else
                keepalive::log "  Vertex AI: OK"
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

    # Check Bitwarden
    if [[ "$(maestro::config 'secrets.bitwarden.enabled')" == "true" ]] && command -v bw &>/dev/null; then
        local bw_status=$(keepalive::bw_status)
        case "$bw_status" in
            unlocked)
                keepalive::log "  Bitwarden: OK (unlocked)"
                ;;
            locked)
                keepalive::log "  Bitwarden: Locked"
                # Don't auto-unlock - requires master password interaction
                ;;
            unauthenticated)
                keepalive::log "  Bitwarden: Not logged in"
                status=1
                ;;
        esac
    fi

    # Check Claude Code (team/OAuth)
    if [[ "$(maestro::config 'ai.claude_code.enabled')" == "true" ]] && command -v claude &>/dev/null; then
        local cc_ttl=$(keepalive::claude_code_ttl)
        if [[ "$cc_ttl" -eq -1 ]]; then
            # No expiry info - just check if working
            if keepalive::check_claude_code; then
                keepalive::log "  Claude Code: OK"
            else
                keepalive::log "  Claude Code: Not authenticated"
                keepalive::claude_code_refresh || status=1
            fi
        elif [[ "$cc_ttl" -lt "$CLAUDE_CODE_REFRESH_THRESHOLD" ]]; then
            keepalive::log "  Claude Code: $(utils::format_duration $cc_ttl) remaining"
            keepalive::claude_code_refresh || status=1
        else
            keepalive::log "  Claude Code: OK ($(utils::format_duration $cc_ttl) remaining)"
        fi
    fi

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

        # GCP
        local gcp_project=$(maestro::config "contexts.$ctx.gcp.project")
        if [[ -n "$gcp_project" ]]; then
            local ttl=$(keepalive::gcp_ttl)
            if [[ "$ttl" -gt 0 ]]; then
                echo "  GCP ($gcp_project): ✅ $(utils::format_duration $ttl) remaining"
            else
                echo "  GCP ($gcp_project): ❌ EXPIRED or not authenticated"
            fi
        fi

        # Vertex AI
        if [[ "$ai_backend" == "vertex" ]] || [[ "$ai_backend" == "vertex_ai" ]]; then
            local gcp_region=$(maestro::config "contexts.$ctx.gcp.region" "us-central1")
            if keepalive::check_vertex_ai "$gcp_project" "$gcp_region"; then
                echo "  Vertex AI: ✅ Accessible"
            else
                echo "  Vertex AI: ❌ Not accessible"
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
    echo "[Bitwarden]"
    if command -v bw &>/dev/null; then
        local bw_status=$(keepalive::bw_status)
        case "$bw_status" in
            unlocked)
                echo "  Bitwarden: ✅ Unlocked"
                ;;
            locked)
                echo "  Bitwarden: 🔒 Locked (run 'bw unlock')"
                ;;
            unauthenticated)
                echo "  Bitwarden: ❌ Not logged in (run 'bw login')"
                ;;
            *)
                echo "  Bitwarden: ⚠️  Unknown status"
                ;;
        esac
    else
        echo "  Bitwarden: ⚪ Not installed"
    fi

    echo ""
    echo "[Claude Code]"
    if command -v claude &>/dev/null; then
        local cc_ttl=$(keepalive::claude_code_ttl)
        if [[ "$cc_ttl" -eq -1 ]]; then
            if keepalive::check_claude_code; then
                echo "  Claude Code: ✅ Authenticated"
            else
                echo "  Claude Code: ❌ Not authenticated"
            fi
        elif [[ "$cc_ttl" -gt 0 ]]; then
            echo "  Claude Code: ✅ $(utils::format_duration $cc_ttl) remaining"
        else
            echo "  Claude Code: ❌ Token expired"
        fi
    else
        echo "  Claude Code: ⚪ Not installed"
    fi

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
