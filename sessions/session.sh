#!/usr/bin/env bash
# lifemaestro/sessions/session.sh - AI session management (agnostic)
# Evolved from claude-sessions, now supports any AI provider

SESSIONS_BASE="${SESSIONS_BASE:-$(maestro::config 'sessions.base_dir' "$HOME/ai-sessions")}"
SESSIONS_BASE="${SESSIONS_BASE/#\~/$HOME}"

# Current zone
CURRENT_ZONE=""

# ============================================
# ZONE MANAGEMENT
# ============================================

session::current_zone() {
    # Check explicit environment variable first
    if [[ -n "${MAESTRO_ZONE:-}" ]]; then
        echo "$MAESTRO_ZONE"
        return
    fi

    # Check cached value
    if [[ -n "$CURRENT_ZONE" ]]; then
        echo "$CURRENT_ZONE"
        return
    fi

    # Try to detect from directory patterns in config
    local pwd="$PWD"
    # Fall back to default zone
    echo "$(maestro::config 'sessions.default_zone' 'personal')"
}

# Alias for backwards compatibility
session::current_context() {
    session::current_zone
}

session::switch() {
    local zone="$1"

    # Validate zone exists
    local zone_user=$(maestro::config "zones.$zone.git.user")
    if [[ -z "$zone_user" ]]; then
        utils::error "Unknown zone: $zone"
        return 1
    fi

    CURRENT_ZONE="$zone"
    export MAESTRO_ZONE="$zone"

    # Set Git identity
    export GIT_AUTHOR_NAME="$(maestro::config "zones.$zone.git.user")"
    export GIT_AUTHOR_EMAIL="$(maestro::config "zones.$zone.git.email")"
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
    export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

    # Set AWS profile
    local aws_profile=$(maestro::config "zones.$zone.aws.profile")
    if [[ -n "$aws_profile" ]]; then
        export AWS_PROFILE="$aws_profile"
        export AWS_REGION="$(maestro::config "zones.$zone.aws.region" "us-east-1")"
    fi

    # Set AI provider preference
    export MAESTRO_AI_PROVIDER="$(maestro::config "zones.$zone.ai.provider" "claude")"
    export MAESTRO_AI_BACKEND="$(maestro::config "zones.$zone.ai.backend" "anthropic")"

    # Set safety rules
    export MAESTRO_SAFETY="$(maestro::config "zones.$zone.rules.safety" "relaxed")"

    utils::success "Switched to zone: $zone"
    session::show_zone
}

session::show_zone() {
    local zone=$(session::current_zone)
    echo ""
    echo "Zone: $zone"
    echo "  Git:     $GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>"
    echo "  AWS:     ${AWS_PROFILE:-not set}"
    echo "  AI:      $MAESTRO_AI_PROVIDER ($MAESTRO_AI_BACKEND)"
    echo "  Safety:  $MAESTRO_SAFETY"
}

# Alias for backwards compatibility
session::show_context() {
    session::show_zone
}

# ============================================
# SESSION CREATION
# ============================================

# Validate session/type name to prevent path traversal
session::validate_name() {
    local name="$1"
    local label="${2:-name}"

    # Check for path traversal attempts
    if [[ "$name" =~ \.\. ]] || [[ "$name" =~ ^/ ]] || [[ "$name" =~ ^~ ]]; then
        cli::error "Invalid $label: '$name' contains path traversal characters"
        return 1
    fi

    # Check for shell metacharacters
    if [[ "$name" =~ [\;\|\&\$\`\(\)\{\}\<\>] ]]; then
        cli::error "Invalid $label: '$name' contains shell metacharacters"
        return 1
    fi

    return 0
}

session::create() {
    local type="$1"
    local name="$2"
    local zone="${3:-$(session::current_zone)}"

    # Validate inputs to prevent path traversal
    session::validate_name "$type" "type" || return 1
    session::validate_name "$name" "session name" || return 1
    session::validate_name "$zone" "zone" || return 1

    # Switch to zone
    session::switch "$zone"

    # Determine session directory
    local session_dir
    case "$type" in
        ticket)
            session_dir="$SESSIONS_BASE/$zone/tickets/$name"
            ;;
        exploration|explore)
            session_dir="$SESSIONS_BASE/$zone/explorations/$name"
            ;;
        learning|learn)
            session_dir="$SESSIONS_BASE/$zone/learning/$name"
            ;;
        infra|infrastructure)
            session_dir="$SESSIONS_BASE/$zone/infrastructure/$name"
            ;;
        investigation)
            session_dir="$SESSIONS_BASE/$zone/investigations/$name"
            ;;
        *)
            session_dir="$SESSIONS_BASE/$zone/$type/$name"
            ;;
    esac

    # Final safety check: ensure path is under SESSIONS_BASE
    local resolved_base="${SESSIONS_BASE/#\~/$HOME}"
    local resolved_dir
    resolved_dir=$(mkdir -p "$session_dir" && cd "$session_dir" && pwd)
    if [[ ! "$resolved_dir" =~ ^"$resolved_base" ]]; then
        cli::error "Security: session directory escapes base path"
        rm -rf "$session_dir" 2>/dev/null || true
        return 1
    fi

    # Initialize git if not exists
    if [[ ! -d "$session_dir/.git" ]]; then
        git -C "$session_dir" init
    fi

    # Copy template if exists
    local template="$MAESTRO_ROOT/sessions/templates/$type.md"
    if [[ -f "$template" ]] && [[ ! -f "$session_dir/CLAUDE.md" ]]; then
        local session_date=$(date '+%Y-%m-%d')
        local engineer=$(maestro::config "zones.$zone.git.user" "$USER")
        local rules=$(session::get_rules "$zone")

        sed -e "s/{{NAME}}/$name/g" \
            -e "s/{{DATE}}/$session_date/g" \
            -e "s/{{CC_CONTEXT}}/$zone/g" \
            -e "s/{{CC_ENGINEER}}/$engineer/g" \
            -e "s/{{OBJECTIVE}}/[Describe your objective]/g" \
            -e "s/{{TICKET_NUM}}//g" \
            -e "s/{{TICKET_DETAILS}}//g" \
            "$template" > "$session_dir/CLAUDE.md"

        # Append rules (can't use sed for multiline)
        if [[ -n "$rules" ]]; then
            sed -i "s|{{RULES}}|$rules|g" "$session_dir/CLAUDE.md" 2>/dev/null || \
                echo "$rules" >> "$session_dir/CLAUDE.md"
        else
            sed -i "s/{{RULES}}//g" "$session_dir/CLAUDE.md" 2>/dev/null || true
        fi
    fi

    # Navigate to session
    cd "$session_dir"

    utils::success "Created session: $session_dir"
    echo ""
    echo "Session ready. Run 'ai' to start your AI assistant."
}

session::get_rules() {
    local zone="$1"
    local rules=""

    local safety=$(maestro::config "zones.$zone.rules.safety" "relaxed")
    local rules_file="$MAESTRO_ROOT/sessions/rules/safety-$safety.md"
    local base_rules="$MAESTRO_ROOT/sessions/rules/base.md"

    if [[ -f "$base_rules" ]]; then
        rules+=$(cat "$base_rules")
        rules+=$'\n\n'
    fi
    if [[ -f "$rules_file" ]]; then
        rules+=$(cat "$rules_file")
    fi

    echo "$rules"
}

# ============================================
# SESSION SHORTCUTS
# ============================================

session::ticket() {
    local ticket_ref="$1"
    local desc="${2:-}"
    local zone="${3:-$(session::current_zone)}"

    # Auto-fetch ticket details
    local ticket_details=""
    local ticket_title=""
    local tools_dir="$MAESTRO_ROOT/.claude/skills/ticket-lookup/tools"

    cli::info "Fetching ticket details for: $ticket_ref"

    # Auto-detect ticket type and fetch
    if [[ "$ticket_ref" =~ ^SDP-?([0-9]+)$ ]] || [[ "$ticket_ref" =~ ^[0-9]+$ ]]; then
        ticket_details=$("$tools_dir/sdp-fetch.sh" "$ticket_ref" 2>/dev/null) || true
    elif [[ "$ticket_ref" =~ ^[A-Z]+-[0-9]+$ ]]; then
        ticket_details=$("$tools_dir/jira-fetch.sh" "$ticket_ref" 2>/dev/null) || true
    elif [[ "$ticket_ref" =~ ^LIN- ]] || [[ "$ticket_ref" =~ linear\.app ]]; then
        ticket_details=$("$tools_dir/linear-fetch.sh" "$ticket_ref" 2>/dev/null) || true
    elif [[ "$ticket_ref" =~ ^#?[0-9]+$ ]] || [[ "$ticket_ref" =~ github\.com ]] || [[ "$ticket_ref" =~ / ]]; then
        ticket_details=$("$tools_dir/github-fetch.sh" "$ticket_ref" 2>/dev/null) || true
    fi

    # Extract title from fetched details for session name
    if [[ -n "$ticket_details" ]]; then
        ticket_title=$(echo "$ticket_details" | grep "^title:" | cut -d: -f2- | xargs)
        cli::success "Fetched: $ticket_title"
    else
        cli::warn "Could not fetch ticket details (will create session anyway)"
    fi

    # Use provided description, or ticket title, or ticket ref
    local session_name
    if [[ -n "$desc" ]]; then
        session_name="$ticket_ref-$(utils::slugify "$desc")"
    elif [[ -n "$ticket_title" ]]; then
        session_name="$ticket_ref-$(utils::slugify "$ticket_title")"
    else
        session_name="$ticket_ref"
    fi

    # Create the session with ticket context
    session::create_ticket "$session_name" "$ticket_ref" "$ticket_details" "$zone"
}

session::create_ticket() {
    local name="$1"
    local ticket_ref="$2"
    local ticket_details="$3"
    local zone="${4:-$(session::current_zone)}"

    # Validate inputs to prevent path traversal
    session::validate_name "$name" "session name" || return 1
    session::validate_name "$zone" "zone" || return 1

    # Switch to zone
    session::switch "$zone"

    local session_dir="$SESSIONS_BASE/$zone/tickets/$name"

    # Final safety check: ensure path is under SESSIONS_BASE
    local resolved_base="${SESSIONS_BASE/#\~/$HOME}"
    local resolved_dir
    resolved_dir=$(mkdir -p "$session_dir" && cd "$session_dir" && pwd)
    if [[ ! "$resolved_dir" =~ ^"$resolved_base" ]]; then
        cli::error "Security: session directory escapes base path"
        rm -rf "$session_dir" 2>/dev/null || true
        return 1
    fi

    # Initialize git if not exists
    if [[ ! -d "$session_dir/.git" ]]; then
        git -C "$session_dir" init
    fi

    # Create CLAUDE.md with ticket context
    local template="$MAESTRO_ROOT/sessions/templates/ticket.md"
    if [[ -f "$template" ]] && [[ ! -f "$session_dir/CLAUDE.md" ]]; then
        local session_date=$(date '+%Y-%m-%d')
        local engineer=$(maestro::config "zones.$zone.git.user" "$USER")
        local rules=$(session::get_rules "$zone")

        # Format ticket details for markdown
        local formatted_details=""
        if [[ -n "$ticket_details" ]]; then
            formatted_details=$(echo "$ticket_details" | sed 's/^/> /')
        else
            formatted_details="_(Ticket details could not be fetched automatically)_"
        fi

        sed -e "s/{{NAME}}/$name/g" \
            -e "s/{{DATE}}/$session_date/g" \
            -e "s/{{CC_CONTEXT}}/$zone/g" \
            -e "s/{{CC_ENGINEER}}/$engineer/g" \
            -e "s/{{TICKET_NUM}}/$ticket_ref/g" \
            -e "s/{{OBJECTIVE}}/[Describe your objective]/g" \
            "$template" > "$session_dir/CLAUDE.md"

        # Replace ticket details (multiline, can't use sed)
        local tmp_file=$(mktemp)
        awk -v details="$formatted_details" '{gsub(/\{\{TICKET_DETAILS\}\}/, details); print}' \
            "$session_dir/CLAUDE.md" > "$tmp_file" && mv "$tmp_file" "$session_dir/CLAUDE.md"

        # Append rules
        if [[ -n "$rules" ]]; then
            sed -i "s|{{RULES}}|$rules|g" "$session_dir/CLAUDE.md" 2>/dev/null || \
                echo "$rules" >> "$session_dir/CLAUDE.md"
        else
            sed -i "s/{{RULES}}//g" "$session_dir/CLAUDE.md" 2>/dev/null || true
        fi
    fi

    # Navigate to session
    cd "$session_dir"

    utils::success "Created ticket session: $session_dir"
    echo ""
    echo "Session ready with ticket context. Run 'ai' to start."
}

session::explore() {
    local name="$1"
    local zone="${2:-$(session::current_zone)}"
    session::create "exploration" "$(utils::slugify "$name")" "$zone"
}

session::investigation() {
    local name="$1"
    local zone="${2:-$(session::current_zone)}"
    session::create "investigation" "$(utils::slugify "$name")" "$zone"
}

session::infra() {
    local name="$1"
    local zone="${2:-$(session::current_zone)}"
    session::create "infrastructure" "$(utils::slugify "$name")" "$zone"
}

session::learn() {
    local topic="$1"
    local zone="${2:-$(session::current_zone)}"
    session::create "learning" "$(utils::slugify "$topic")" "$zone"
}

# Legacy aliases (zone-agnostic now)
session::work() {
    session::explore "$@"
}

session::home() {
    session::explore "$@"
}

# ============================================
# AI LAUNCHER
# ============================================

session::ai() {
    local provider="${1:-$MAESTRO_AI_PROVIDER}"
    provider="${provider:-$(maestro::config 'ai.default_provider' 'claude')}"

    # Ensure credentials before launching
    session::ensure_creds "$provider"

    # Launch the AI
    case "$provider" in
        claude)
            claude "${@:2}"
            ;;
        aider)
            local backend=$(maestro::config 'ai.aider.backend' 'anthropic')
            case "$backend" in
                anthropic) aider --sonnet "${@:2}" ;;
                openai)    aider --4o "${@:2}" ;;
                ollama)    aider --ollama "${@:2}" ;;
                bedrock)   aider --bedrock "${@:2}" ;;
                *)         aider "${@:2}" ;;
            esac
            ;;
        amazon-q|q)
            q chat "${@:2}"
            ;;
        gh-copilot)
            gh copilot chat "${@:2}"
            ;;
        ollama)
            local model=$(maestro::config 'ai.ollama.default_model' 'llama3.2')
            ollama run "$model" "${@:2}"
            ;;
        llm)
            llm chat "${@:2}"
            ;;
        *)
            utils::error "Unknown AI provider: $provider"
            return 1
            ;;
    esac
}

session::ensure_creds() {
    local provider="$1"
    local zone=$(session::current_zone)

    case "$provider" in
        claude)
            local backend=$(maestro::config "zones.$zone.ai.backend" "anthropic")
            if [[ "$backend" == "bedrock" ]]; then
                local profile=$(maestro::config "zones.$zone.aws.profile")
                local ttl=$(keepalive::aws_sso_ttl "$profile")
                if [[ "$ttl" -lt 300 ]]; then
                    utils::warn "AWS credentials expiring soon, refreshing..."
                    keepalive::aws_sso_refresh "$profile"
                fi
            fi
            ;;
        amazon-q|q)
            local profile=$(maestro::config "zones.$zone.aws.profile")
            if ! keepalive::check_aws "$profile"; then
                utils::warn "AWS credentials invalid, refreshing..."
                keepalive::aws_sso_refresh "$profile"
            fi
            ;;
        gh-copilot)
            if ! gh auth status &>/dev/null; then
                utils::warn "GitHub auth required..."
                gh auth login
            fi
            ;;
        ollama)
            if ! keepalive::check_ollama; then
                utils::info "Starting Ollama..."
                keepalive::start_ollama
            fi
            ;;
    esac
}

# ============================================
# SESSION UTILITIES
# ============================================

session::list() {
    local zone="${1:-$(session::current_zone)}"
    local base="$SESSIONS_BASE/$zone"

    if [[ ! -d "$base" ]]; then
        echo "No sessions for zone: $zone"
        return
    fi

    echo "Sessions ($zone):"
    find "$base" -maxdepth 2 -type d -name ".git" | while read gitdir; do
        local session_dir=$(dirname "$gitdir")
        local name=$(basename "$session_dir")
        local type=$(basename $(dirname "$session_dir"))
        echo "  $type/$name"
    done
}

session::go() {
    # Interactive session picker using fzf
    if ! command -v fzf &>/dev/null; then
        utils::error "fzf required for session picker"
        return 1
    fi

    local zone="${1:-}"
    local base="$SESSIONS_BASE"

    local sessions
    if [[ -n "$zone" ]]; then
        sessions=$(find "$base/$zone" -maxdepth 2 -type d -name ".git" 2>/dev/null | \
            xargs -I{} dirname {} | \
            sed "s|$base/||")
    else
        sessions=$(find "$base" -maxdepth 3 -type d -name ".git" 2>/dev/null | \
            xargs -I{} dirname {} | \
            sed "s|$base/||")
    fi

    local selected=$(echo "$sessions" | fzf --prompt="Session: ")

    if [[ -n "$selected" ]]; then
        # Extract zone from path and switch
        local selected_zone=$(echo "$selected" | cut -d'/' -f1)
        session::switch "$selected_zone"
        cd "$base/$selected"
        utils::success "Switched to: $selected"
    fi
}

session::compact() {
    # Archive and compact CLAUDE.md
    local claude_md="CLAUDE.md"
    [[ -f "$claude_md" ]] || { utils::error "No CLAUDE.md found"; return 1; }

    local archive_dir=".claude-archives"
    mkdir -p "$archive_dir"

    local timestamp=$(date '+%Y%m%d_%H%M%S')
    cp "$claude_md" "$archive_dir/CLAUDE_$timestamp.md"

    utils::success "Archived to $archive_dir/CLAUDE_$timestamp.md"
    utils::info "You can now trim $claude_md"
}

session::done() {
    # Mark session as complete
    local session_dir="$PWD"

    if [[ -f "CLAUDE.md" ]]; then
        echo "" >> CLAUDE.md
        echo "---" >> CLAUDE.md
        echo "Session completed: $(date '+%Y-%m-%d %H:%M')" >> CLAUDE.md
    fi

    git add -A
    git commit -m "Session complete" || true

    utils::success "Session marked complete"
}

# ============================================
# ALIASES (for muscle memory from claude-sessions)
# ============================================

# These aliases maintain compatibility with claude-sessions naming
alias cc='session::ai'
alias ccticket='session::ticket'
alias ccw='session::explore'
alias cch='session::explore'
alias ccinfra='session::infra'
alias cclearn='session::learn'
alias ccls='session::list'
alias ccgo='session::go'
alias cccompact='session::compact'
alias ccdone='session::done'
alias cc_switch='session::switch'
alias cc_status='session::show_zone'
