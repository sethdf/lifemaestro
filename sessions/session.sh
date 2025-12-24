#!/usr/bin/env bash
# lifemaestro/sessions/session.sh - AI session management (agnostic)
# Evolved from claude-sessions, now supports any AI provider

SESSIONS_BASE="${SESSIONS_BASE:-$(maestro::config 'sessions.base_dir' "$HOME/ai-sessions")}"
SESSIONS_BASE="${SESSIONS_BASE/#\~/$HOME}"

# Current context (work/home)
CURRENT_CONTEXT=""

# ============================================
# CONTEXT MANAGEMENT
# ============================================

session::current_context() {
    # Detect from current directory or use default
    if [[ -n "$CURRENT_CONTEXT" ]]; then
        echo "$CURRENT_CONTEXT"
        return
    fi

    local pwd="$PWD"
    if [[ "$pwd" == *"/work/"* ]] || [[ "$pwd" == *"/work-"* ]]; then
        echo "work"
    elif [[ "$pwd" == *"/home/"* ]] || [[ "$pwd" == *"/personal/"* ]]; then
        echo "home"
    else
        echo "$(maestro::config 'sessions.default_context' 'home')"
    fi
}

session::switch() {
    local context="$1"

    # Validate context exists
    local ctx_user=$(maestro::config "contexts.$context.git.user")
    if [[ -z "$ctx_user" ]]; then
        utils::error "Unknown context: $context"
        return 1
    fi

    CURRENT_CONTEXT="$context"

    # Set Git identity
    export GIT_AUTHOR_NAME="$(maestro::config "contexts.$context.git.user")"
    export GIT_AUTHOR_EMAIL="$(maestro::config "contexts.$context.git.email")"
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
    export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

    # Set AWS profile
    local aws_profile=$(maestro::config "contexts.$context.aws.profile")
    if [[ -n "$aws_profile" ]]; then
        export AWS_PROFILE="$aws_profile"
        export AWS_REGION="$(maestro::config "contexts.$context.aws.region" "us-east-1")"
    fi

    # Set AI provider preference
    export MAESTRO_AI_PROVIDER="$(maestro::config "contexts.$context.ai.provider" "claude")"
    export MAESTRO_AI_BACKEND="$(maestro::config "contexts.$context.ai.backend" "anthropic")"

    # Set safety rules
    export MAESTRO_SAFETY="$(maestro::config "contexts.$context.rules.safety" "relaxed")"

    utils::success "Switched to $context context"
    session::show_context
}

session::show_context() {
    local ctx=$(session::current_context)
    echo ""
    echo "Context: $ctx"
    echo "  Git:     $GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>"
    echo "  AWS:     ${AWS_PROFILE:-not set}"
    echo "  AI:      $MAESTRO_AI_PROVIDER ($MAESTRO_AI_BACKEND)"
    echo "  Safety:  $MAESTRO_SAFETY"
}

# ============================================
# SESSION CREATION
# ============================================

session::create() {
    local type="$1"
    local name="$2"
    local context="${3:-$(session::current_context)}"

    # Switch to context
    session::switch "$context"

    # Determine session directory
    local session_dir
    case "$type" in
        ticket)
            session_dir="$SESSIONS_BASE/$context/tickets/$name"
            ;;
        exploration|explore)
            session_dir="$SESSIONS_BASE/$context/explorations/$name"
            ;;
        learning|learn)
            session_dir="$SESSIONS_BASE/$context/learning/$name"
            ;;
        infra|infrastructure)
            session_dir="$SESSIONS_BASE/$context/infrastructure/$name"
            ;;
        *)
            session_dir="$SESSIONS_BASE/$context/$type/$name"
            ;;
    esac

    # Create directory
    mkdir -p "$session_dir"

    # Initialize git if not exists
    if [[ ! -d "$session_dir/.git" ]]; then
        git -C "$session_dir" init
    fi

    # Copy template if exists
    local template="$MAESTRO_ROOT/sessions/templates/$type.md"
    if [[ -f "$template" ]] && [[ ! -f "$session_dir/CLAUDE.md" ]]; then
        local session_name="$name"
        local session_date=$(date '+%Y-%m-%d')
        sed -e "s/{{SESSION_NAME}}/$session_name/g" \
            -e "s/{{DATE}}/$session_date/g" \
            -e "s/{{CONTEXT}}/$context/g" \
            "$template" > "$session_dir/CLAUDE.md"
    fi

    # Copy rules
    session::apply_rules "$session_dir" "$context"

    # Navigate to session
    cd "$session_dir"

    utils::success "Created session: $session_dir"
    echo ""
    echo "Session ready. Run 'ai' to start your AI assistant."
}

session::apply_rules() {
    local session_dir="$1"
    local context="$2"

    local safety=$(maestro::config "contexts.$context.rules.safety" "relaxed")
    local rules_file="$MAESTRO_ROOT/sessions/rules/safety-$safety.md"
    local base_rules="$MAESTRO_ROOT/sessions/rules/base.md"

    # Append rules to CLAUDE.md if they exist
    if [[ -f "$session_dir/CLAUDE.md" ]]; then
        if [[ -f "$base_rules" ]]; then
            echo "" >> "$session_dir/CLAUDE.md"
            cat "$base_rules" >> "$session_dir/CLAUDE.md"
        fi
        if [[ -f "$rules_file" ]]; then
            echo "" >> "$session_dir/CLAUDE.md"
            cat "$rules_file" >> "$session_dir/CLAUDE.md"
        fi
    fi
}

# ============================================
# SESSION SHORTCUTS
# ============================================

session::ticket() {
    local num="$1"
    local desc="$2"
    session::create "ticket" "$num-$(utils::slugify "$desc")" "work"
}

session::work() {
    local name="$1"
    session::create "exploration" "$(utils::slugify "$name")" "work"
}

session::home() {
    local name="$1"
    session::create "exploration" "$(utils::slugify "$name")" "home"
}

session::infra() {
    local name="$1"
    session::create "infrastructure" "$(utils::slugify "$name")" "work"
}

session::learn() {
    local topic="$1"
    session::create "learning" "$(utils::slugify "$topic")" "home"
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
    local ctx=$(session::current_context)

    case "$provider" in
        claude)
            local backend=$(maestro::config "contexts.$ctx.ai.backend" "anthropic")
            if [[ "$backend" == "bedrock" ]]; then
                local profile=$(maestro::config "contexts.$ctx.aws.profile")
                local ttl=$(keepalive::aws_sso_ttl "$profile")
                if [[ "$ttl" -lt 300 ]]; then
                    utils::warn "AWS credentials expiring soon, refreshing..."
                    keepalive::aws_sso_refresh "$profile"
                fi
            fi
            ;;
        amazon-q|q)
            local profile=$(maestro::config "contexts.$ctx.aws.profile")
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
    local context="${1:-$(session::current_context)}"
    local base="$SESSIONS_BASE/$context"

    if [[ ! -d "$base" ]]; then
        echo "No sessions for context: $context"
        return
    fi

    echo "Sessions ($context):"
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

    local context="${1:-}"
    local base="$SESSIONS_BASE"

    local sessions
    if [[ -n "$context" ]]; then
        sessions=$(find "$base/$context" -maxdepth 2 -type d -name ".git" 2>/dev/null | \
            xargs -I{} dirname {} | \
            sed "s|$base/||")
    else
        sessions=$(find "$base" -maxdepth 3 -type d -name ".git" 2>/dev/null | \
            xargs -I{} dirname {} | \
            sed "s|$base/||")
    fi

    local selected=$(echo "$sessions" | fzf --prompt="Session: ")

    if [[ -n "$selected" ]]; then
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
alias ccw='session::work'
alias cch='session::home'
alias ccinfra='session::infra'
alias cclearn='session::learn'
alias ccls='session::list'
alias ccgo='session::go'
alias cccompact='session::compact'
alias ccdone='session::done'
alias cc_switch_work='session::switch work'
alias cc_switch_home='session::switch home'
alias cc_status='session::show_context'
