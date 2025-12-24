#!/usr/bin/env bash
# lifemaestro/core/skills.sh - Skill-level AI integration framework
#
# Each skill decides its own AI usage level:
#   - none:   Pure bash, zero AI tokens
#   - light:  Single-shot AI call (categorize, classify, extract)
#   - medium: Multi-step AI (draft, refine, summarize)
#   - full:   Interactive AI session
#
# This approach is MORE TOKEN EFFICIENT than MCP because:
# - MCP tools load 5000+ tokens of tool definitions in EVERY conversation
# - Skills invoke AI only when needed, for specific purposes
# - User controls exactly where AI tokens are spent

# ============================================
# SKILL REGISTRY
# ============================================

declare -A SKILL_REGISTRY
declare -A SKILL_AI_LEVEL

# Register a skill with its AI level
skill::register() {
    local name="$1"
    local func="$2"
    local ai_level="${3:-none}"  # none, light, medium, full
    local description="${4:-}"

    SKILL_REGISTRY[$name]="$func"
    SKILL_AI_LEVEL[$name]="$ai_level"

    maestro::log "Registered skill: $name (AI: $ai_level)"
}

# Get AI level for a skill
skill::ai_level() {
    local name="$1"
    echo "${SKILL_AI_LEVEL[$name]:-none}"
}

# Run a skill
skill::run() {
    local name="$1"
    shift

    local func="${SKILL_REGISTRY[$name]}"
    if [[ -z "$func" ]]; then
        cli::error "Unknown skill: $name"
        return 1
    fi

    local ai_level=$(skill::ai_level "$name")
    cli::debug "Running skill '$name' (AI level: $ai_level)"

    # Track AI usage for reporting
    local start_time=$(date +%s)

    # Run the skill
    $func "$@"
    local result=$?

    local end_time=$(date +%s)
    maestro::log "Skill $name completed in $((end_time - start_time))s (AI: $ai_level)"

    return $result
}

# List all skills
skill::list() {
    cli::out "Available Skills:"
    cli::out ""
    for name in "${!SKILL_REGISTRY[@]}"; do
        local ai_level="${SKILL_AI_LEVEL[$name]}"
        local indicator=""
        case "$ai_level" in
            none)   indicator="○" ;;
            light)  indicator="◐" ;;
            medium) indicator="◑" ;;
            full)   indicator="●" ;;
        esac
        cli::out "  $indicator $name ($ai_level)"
    done
    cli::out ""
    cli::out "Legend: ○ none  ◐ light  ◑ medium  ● full"
}

# ============================================
# AI HELPERS FOR SKILLS
# ============================================

# Single-shot AI call (for light AI skills)
# Uses the fastest/cheapest model appropriate
skill::ai_oneshot() {
    local prompt="$1"
    local provider="${2:-$(maestro::config 'ai.default_fast_provider' 'ollama')}"

    case "$provider" in
        ollama)
            local model=$(maestro::config 'ai.ollama.default_model' 'llama3.2')
            echo "$prompt" | ollama run "$model" 2>/dev/null
            ;;
        claude)
            claude --print "$prompt" 2>/dev/null
            ;;
        llm)
            echo "$prompt" | llm 2>/dev/null
            ;;
        openai)
            # Use gpt-4o-mini for quick tasks
            curl -s https://api.openai.com/v1/chat/completions \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${OPENAI_API_KEY}" \
                -d "{\"model\": \"gpt-4o-mini\", \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}]}" \
                | jq -r '.choices[0].message.content'
            ;;
        *)
            cli::error "Unknown AI provider: $provider"
            return 1
            ;;
    esac
}

# Multi-turn AI (for medium AI skills)
skill::ai_converse() {
    local system_prompt="$1"
    local user_prompt="$2"
    local provider="${3:-$(maestro::config 'ai.default_provider' 'claude')}"

    case "$provider" in
        claude)
            echo "$user_prompt" | claude --system "$system_prompt" --print 2>/dev/null
            ;;
        ollama)
            local model=$(maestro::config 'ai.ollama.default_model' 'llama3.2')
            printf "System: %s\n\nUser: %s" "$system_prompt" "$user_prompt" | ollama run "$model" 2>/dev/null
            ;;
        llm)
            echo "$user_prompt" | llm -s "$system_prompt" 2>/dev/null
            ;;
        *)
            skill::ai_oneshot "$user_prompt" "$provider"
            ;;
    esac
}

# Interactive AI session (for full AI skills)
skill::ai_interactive() {
    local context="${1:-}"
    local provider="${2:-$(maestro::config 'ai.default_provider' 'claude')}"

    session::ai "$provider"
}

# ============================================
# LOAD SKILLS FROM DIRECTORY
# ============================================

skill::load_all() {
    local skills_dir="$MAESTRO_ROOT/skills"

    [[ -d "$skills_dir" ]] || return

    for skill_file in "$skills_dir"/*.sh; do
        [[ -f "$skill_file" ]] || continue
        source "$skill_file"
        maestro::log "Loaded skill file: $(basename "$skill_file")"
    done
}

# Auto-load skills on source
skill::load_all

# ============================================
# BUILT-IN SKILLS
# ============================================

# --- CREDENTIAL SKILLS (No AI) ---

_skill_creds_status() {
    keepalive::status
}
skill::register "creds" "_skill_creds_status" "none" "Show credential status"

_skill_creds_refresh() {
    AWS_REFRESH_THRESHOLD=999999 OAUTH_REFRESH_THRESHOLD=999999 keepalive::check_all
}
skill::register "creds-refresh" "_skill_creds_refresh" "none" "Force refresh credentials"

# --- SESSION SKILLS (No AI) ---

_skill_session_new() {
    local type="${1:-exploration}"
    local name="${2:-}"

    if [[ -z "$name" ]]; then
        cli::die_usage "Usage: skill session-new <type> <name>"
    fi

    session::create "$type" "$name"
}
skill::register "session-new" "_skill_session_new" "none" "Create new session"

_skill_session_list() {
    session::list "$@"
}
skill::register "session-list" "_skill_session_list" "none" "List sessions"

# --- CONTEXT SKILLS (No AI) ---

_skill_context_switch() {
    local ctx="${1:-}"
    [[ -z "$ctx" ]] && cli::die_usage "Usage: skill context-switch <work|home>"
    session::switch "$ctx"
}
skill::register "context-switch" "_skill_context_switch" "none" "Switch context"

_skill_context_show() {
    session::show_context
}
skill::register "context" "_skill_context_show" "none" "Show current context"

# --- QUICK AI SKILLS (Light AI) ---

_skill_categorize() {
    local input="${1:-}"

    if [[ -z "$input" ]] && cli::has_stdin; then
        input=$(cat)
    fi

    [[ -z "$input" ]] && cli::die_usage "Usage: skill categorize <text> or pipe input"

    skill::ai_oneshot "Categorize this into one of: work, personal, urgent, info, spam. Just respond with the category name, nothing else.\n\nText: $input"
}
skill::register "categorize" "_skill_categorize" "light" "Categorize text"

_skill_extract_action() {
    local input="${1:-}"

    if [[ -z "$input" ]] && cli::has_stdin; then
        input=$(cat)
    fi

    [[ -z "$input" ]] && cli::die_usage "Usage: skill extract-action <text>"

    skill::ai_oneshot "Extract the main action item from this text. Respond with just the action, starting with a verb. If no action, respond 'None'.\n\nText: $input"
}
skill::register "extract-action" "_skill_extract_action" "light" "Extract action from text"

_skill_sentiment() {
    local input="${1:-}"

    if [[ -z "$input" ]] && cli::has_stdin; then
        input=$(cat)
    fi

    [[ -z "$input" ]] && cli::die_usage "Usage: skill sentiment <text>"

    skill::ai_oneshot "Rate the sentiment: positive, neutral, or negative. Just the word, nothing else.\n\nText: $input"
}
skill::register "sentiment" "_skill_sentiment" "light" "Analyze sentiment"

# --- SUMMARIZATION SKILLS (Medium AI) ---

_skill_summarize() {
    local input="${1:-}"

    if [[ -z "$input" ]] && cli::has_stdin; then
        input=$(cat)
    fi

    [[ -z "$input" ]] && cli::die_usage "Usage: skill summarize <text> or pipe input"

    skill::ai_converse \
        "You are a concise summarizer. Summarize the given text in 2-3 sentences." \
        "$input"
}
skill::register "summarize" "_skill_summarize" "medium" "Summarize text"

_skill_draft_reply() {
    local input="${1:-}"

    if [[ -z "$input" ]] && cli::has_stdin; then
        input=$(cat)
    fi

    [[ -z "$input" ]] && cli::die_usage "Usage: skill draft-reply <email text>"

    local ctx=$(session::current_context)
    local name=$(maestro::config "contexts.$ctx.git.user" "User")

    skill::ai_converse \
        "You are drafting a professional email reply. Be concise and helpful. Sign as '$name'." \
        "Draft a reply to this email:\n\n$input"
}
skill::register "draft-reply" "_skill_draft_reply" "medium" "Draft email reply"

_skill_explain() {
    local input="${1:-}"

    if [[ -z "$input" ]] && cli::has_stdin; then
        input=$(cat)
    fi

    [[ -z "$input" ]] && cli::die_usage "Usage: skill explain <code or text>"

    skill::ai_converse \
        "Explain the following clearly and concisely. If it's code, explain what it does. If it's text, explain the key points." \
        "$input"
}
skill::register "explain" "_skill_explain" "medium" "Explain code or text"

# --- CODING SKILLS (Full AI) ---

_skill_code() {
    skill::ai_interactive "" "claude"
}
skill::register "code" "_skill_code" "full" "Start coding session"

_skill_chat() {
    local provider="${1:-$(maestro::config 'ai.default_provider' 'claude')}"
    skill::ai_interactive "" "$provider"
}
skill::register "chat" "_skill_chat" "full" "Start AI chat session"
