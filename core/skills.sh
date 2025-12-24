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
#
# Strategy for provider-agnostic AI calls:
# 1. Use native CLI first (claude, ollama, openai, etc.)
# 2. Fall back to 'llm' tool if native CLI unavailable
# 3. Use direct API calls as last resort
#
# This ensures skills work with ANY AI provider, not just Claude.

# Check if llm tool is available and configured
skill::_has_llm() {
    command -v llm &>/dev/null
}

# Escape JSON string
skill::_json_escape() {
    local str="$1"
    # Escape backslashes, quotes, and newlines
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Single-shot AI call (for light AI skills)
# Uses the fastest/cheapest model appropriate
# Priority: native CLI -> llm tool -> direct API
skill::ai_oneshot() {
    local prompt="$1"
    local provider="${2:-$(maestro::config 'ai.default_fast_provider' 'ollama')}"

    case "$provider" in
        ollama)
            local model=$(maestro::config 'ai.ollama.default_model' 'llama3.2')
            if command -v ollama &>/dev/null; then
                echo "$prompt" | ollama run "$model" 2>/dev/null
            else
                cli::error "Ollama not installed"
                return 1
            fi
            ;;
        claude|anthropic)
            # 1. Try Claude CLI
            if command -v claude &>/dev/null; then
                echo "$prompt" | claude --print 2>/dev/null
            # 2. Try llm tool
            elif skill::_has_llm; then
                echo "$prompt" | llm -m claude-3-5-haiku-latest 2>/dev/null
            # 3. Direct API
            elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
                local escaped_prompt=$(skill::_json_escape "$prompt")
                curl -s https://api.anthropic.com/v1/messages \
                    -H "Content-Type: application/json" \
                    -H "x-api-key: $ANTHROPIC_API_KEY" \
                    -H "anthropic-version: 2023-06-01" \
                    -d "{\"model\": \"claude-3-5-haiku-20241022\", \"max_tokens\": 1024, \"messages\": [{\"role\": \"user\", \"content\": \"$escaped_prompt\"}]}" \
                    | jq -r '.content[0].text // .error.message // "Error"'
            else
                cli::error "No Claude CLI, llm tool, or API key available"
                return 1
            fi
            ;;
        openai|chatgpt|gpt)
            # 1. Try OpenAI CLI
            if command -v openai &>/dev/null; then
                echo "$prompt" | openai api chat.completions.create -m gpt-4o-mini 2>/dev/null
            # 2. Try llm tool
            elif skill::_has_llm; then
                echo "$prompt" | llm -m gpt-4o-mini 2>/dev/null
            # 3. Direct API
            elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
                local escaped_prompt=$(skill::_json_escape "$prompt")
                curl -s https://api.openai.com/v1/chat/completions \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $OPENAI_API_KEY" \
                    -d "{\"model\": \"gpt-4o-mini\", \"messages\": [{\"role\": \"user\", \"content\": \"$escaped_prompt\"}]}" \
                    | jq -r '.choices[0].message.content // .error.message // "Error"'
            else
                cli::error "No OpenAI CLI, llm tool, or API key available"
                return 1
            fi
            ;;
        gemini|google)
            # 1. Try llm tool (no official gemini CLI)
            if skill::_has_llm; then
                echo "$prompt" | llm -m gemini-1.5-flash 2>/dev/null
            # 2. Direct API
            elif [[ -n "${GEMINI_API_KEY:-}" ]]; then
                local escaped_prompt=$(skill::_json_escape "$prompt")
                curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "{\"contents\": [{\"parts\": [{\"text\": \"$escaped_prompt\"}]}]}" \
                    | jq -r '.candidates[0].content.parts[0].text // .error.message // "Error"'
            else
                cli::error "No llm tool or Gemini API key available"
                return 1
            fi
            ;;
        mistral)
            # 1. Try llm tool
            if skill::_has_llm; then
                echo "$prompt" | llm -m mistral-small-latest 2>/dev/null
            # 2. Direct API
            elif [[ -n "${MISTRAL_API_KEY:-}" ]]; then
                local escaped_prompt=$(skill::_json_escape "$prompt")
                curl -s https://api.mistral.ai/v1/chat/completions \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $MISTRAL_API_KEY" \
                    -d "{\"model\": \"mistral-small-latest\", \"messages\": [{\"role\": \"user\", \"content\": \"$escaped_prompt\"}]}" \
                    | jq -r '.choices[0].message.content // .error.message // "Error"'
            else
                cli::error "No llm tool or Mistral API key available"
                return 1
            fi
            ;;
        groq)
            # 1. Try llm tool
            if skill::_has_llm; then
                echo "$prompt" | llm -m groq-llama-3.1-8b-instant 2>/dev/null
            # 2. Direct API
            elif [[ -n "${GROQ_API_KEY:-}" ]]; then
                local escaped_prompt=$(skill::_json_escape "$prompt")
                curl -s https://api.groq.com/openai/v1/chat/completions \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $GROQ_API_KEY" \
                    -d "{\"model\": \"llama-3.1-8b-instant\", \"messages\": [{\"role\": \"user\", \"content\": \"$escaped_prompt\"}]}" \
                    | jq -r '.choices[0].message.content // .error.message // "Error"'
            else
                cli::error "No llm tool or Groq API key available"
                return 1
            fi
            ;;
        llm)
            if skill::_has_llm; then
                echo "$prompt" | llm 2>/dev/null
            else
                cli::error "llm tool not installed"
                return 1
            fi
            ;;
        *)
            cli::error "Unknown AI provider: $provider"
            cli::error "Supported: ollama, claude, openai, gemini, mistral, groq, llm"
            return 1
            ;;
    esac
}

# Multi-turn AI (for medium AI skills)
# Combines system prompt with user prompt for providers that support it
# Priority: native CLI -> llm tool -> direct API
skill::ai_converse() {
    local system_prompt="$1"
    local user_prompt="$2"
    local provider="${3:-$(maestro::config 'ai.default_provider' 'claude')}"

    case "$provider" in
        ollama)
            local model=$(maestro::config 'ai.ollama.default_model' 'llama3.2')
            # Ollama doesn't have native system prompt in CLI, prepend it
            if command -v ollama &>/dev/null; then
                printf "System: %s\n\nUser: %s" "$system_prompt" "$user_prompt" | ollama run "$model" 2>/dev/null
            else
                cli::error "Ollama not installed"
                return 1
            fi
            ;;
        claude|anthropic)
            # 1. Try Claude CLI
            if command -v claude &>/dev/null; then
                echo "$user_prompt" | claude --system-prompt "$system_prompt" --print 2>/dev/null
            # 2. Try llm tool
            elif skill::_has_llm; then
                echo "$user_prompt" | llm -m claude-3-5-sonnet-latest -s "$system_prompt" 2>/dev/null
            # 3. Direct API
            elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
                local escaped_system=$(skill::_json_escape "$system_prompt")
                local escaped_user=$(skill::_json_escape "$user_prompt")
                curl -s https://api.anthropic.com/v1/messages \
                    -H "Content-Type: application/json" \
                    -H "x-api-key: $ANTHROPIC_API_KEY" \
                    -H "anthropic-version: 2023-06-01" \
                    -d "{\"model\": \"claude-3-5-sonnet-20241022\", \"max_tokens\": 4096, \"system\": \"$escaped_system\", \"messages\": [{\"role\": \"user\", \"content\": \"$escaped_user\"}]}" \
                    | jq -r '.content[0].text // .error.message // "Error"'
            else
                cli::error "No Claude CLI, llm tool, or API key available"
                return 1
            fi
            ;;
        openai|chatgpt|gpt)
            # 1. Try llm tool (openai CLI doesn't support system prompts well)
            if skill::_has_llm; then
                echo "$user_prompt" | llm -m gpt-4o -s "$system_prompt" 2>/dev/null
            # 2. Direct API
            elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
                local escaped_system=$(skill::_json_escape "$system_prompt")
                local escaped_user=$(skill::_json_escape "$user_prompt")
                curl -s https://api.openai.com/v1/chat/completions \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $OPENAI_API_KEY" \
                    -d "{\"model\": \"gpt-4o\", \"messages\": [{\"role\": \"system\", \"content\": \"$escaped_system\"}, {\"role\": \"user\", \"content\": \"$escaped_user\"}]}" \
                    | jq -r '.choices[0].message.content // .error.message // "Error"'
            else
                cli::error "No llm tool or OpenAI API key available"
                return 1
            fi
            ;;
        gemini|google)
            # 1. Try llm tool
            if skill::_has_llm; then
                echo "$user_prompt" | llm -m gemini-1.5-pro -s "$system_prompt" 2>/dev/null
            # 2. Direct API (prepend system to user since Gemini doesn't have system role)
            elif [[ -n "${GEMINI_API_KEY:-}" ]]; then
                local combined="Instructions: $system_prompt\n\nTask: $user_prompt"
                local escaped_prompt=$(skill::_json_escape "$combined")
                curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$GEMINI_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "{\"contents\": [{\"parts\": [{\"text\": \"$escaped_prompt\"}]}]}" \
                    | jq -r '.candidates[0].content.parts[0].text // .error.message // "Error"'
            else
                cli::error "No llm tool or Gemini API key available"
                return 1
            fi
            ;;
        mistral)
            # 1. Try llm tool
            if skill::_has_llm; then
                echo "$user_prompt" | llm -m mistral-medium-latest -s "$system_prompt" 2>/dev/null
            # 2. Direct API
            elif [[ -n "${MISTRAL_API_KEY:-}" ]]; then
                local escaped_system=$(skill::_json_escape "$system_prompt")
                local escaped_user=$(skill::_json_escape "$user_prompt")
                curl -s https://api.mistral.ai/v1/chat/completions \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $MISTRAL_API_KEY" \
                    -d "{\"model\": \"mistral-medium-latest\", \"messages\": [{\"role\": \"system\", \"content\": \"$escaped_system\"}, {\"role\": \"user\", \"content\": \"$escaped_user\"}]}" \
                    | jq -r '.choices[0].message.content // .error.message // "Error"'
            else
                cli::error "No llm tool or Mistral API key available"
                return 1
            fi
            ;;
        groq)
            # 1. Try llm tool
            if skill::_has_llm; then
                echo "$user_prompt" | llm -m groq-llama-3.1-70b-versatile -s "$system_prompt" 2>/dev/null
            # 2. Direct API
            elif [[ -n "${GROQ_API_KEY:-}" ]]; then
                local escaped_system=$(skill::_json_escape "$system_prompt")
                local escaped_user=$(skill::_json_escape "$user_prompt")
                curl -s https://api.groq.com/openai/v1/chat/completions \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $GROQ_API_KEY" \
                    -d "{\"model\": \"llama-3.1-70b-versatile\", \"messages\": [{\"role\": \"system\", \"content\": \"$escaped_system\"}, {\"role\": \"user\", \"content\": \"$escaped_user\"}]}" \
                    | jq -r '.choices[0].message.content // .error.message // "Error"'
            else
                cli::error "No llm tool or Groq API key available"
                return 1
            fi
            ;;
        llm)
            if skill::_has_llm; then
                echo "$user_prompt" | llm -s "$system_prompt" 2>/dev/null
            else
                cli::error "llm tool not installed"
                return 1
            fi
            ;;
        *)
            cli::error "Unknown AI provider: $provider"
            cli::error "Supported: ollama, claude, openai, gemini, mistral, groq, llm"
            return 1
            ;;
    esac
}

# Interactive AI session (for full AI skills)
skill::ai_interactive() {
    local context="${1:-}"
    local provider="${2:-$(maestro::config 'ai.default_provider' 'claude')}"

    session::ai "$provider"
}

# List available AI providers
skill::ai_providers() {
    cli::out "Available AI Providers for Skills:"
    cli::out ""
    cli::out "Provider       CLI Tool      API Key"
    cli::out "--------       --------      -------"

    # Check llm (universal)
    if skill::_has_llm; then
        cli::out "llm            ✅ llm        (manages own keys)"
    fi

    # Check each provider
    local providers=("ollama" "claude" "openai" "gemini" "mistral" "groq")
    local cli_tools=("ollama" "claude" "openai" "gemini" "mistral" "groq")
    local env_vars=("" "ANTHROPIC_API_KEY" "OPENAI_API_KEY" "GEMINI_API_KEY" "MISTRAL_API_KEY" "GROQ_API_KEY")

    for i in "${!providers[@]}"; do
        local provider="${providers[$i]}"
        local cli="${cli_tools[$i]}"
        local env="${env_vars[$i]}"

        local cli_status="⚪"
        local key_status="⚪"

        if command -v "$cli" &>/dev/null; then
            cli_status="✅"
        fi

        if [[ -n "$env" ]] && [[ -n "${!env:-}" ]]; then
            key_status="✅"
        elif [[ -z "$env" ]]; then
            key_status="n/a"
        fi

        printf "%-14s %-13s %s\n" "$provider" "$cli_status $cli" "$key_status ${env:-}"
    done
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

# --- ZONE SKILLS (No AI) ---

_skill_zone_switch() {
    local zone="${1:-}"
    [[ -z "$zone" ]] && cli::die_usage "Usage: skill zone-switch <zone-name>"
    session::switch "$zone"
}
skill::register "zone-switch" "_skill_zone_switch" "none" "Switch zone"

_skill_zone_show() {
    session::show_zone
}
skill::register "zone" "_skill_zone_show" "none" "Show current zone"

# Legacy aliases
skill::register "context-switch" "_skill_zone_switch" "none" "Switch zone (legacy)"
skill::register "context" "_skill_zone_show" "none" "Show current zone (legacy)"

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

    local zone=$(session::current_zone)
    local name=$(maestro::config "zones.$zone.git.user" "User")

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
