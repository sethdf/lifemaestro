#!/usr/bin/env bash
# adapters/vendor/pai.sh - PAI (Personal AI Infrastructure) integration
# Provides access to PAI patterns, scripts, and configs

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
PAI_DIR="$MAESTRO_ROOT/vendor/pai"

# ============================================
# PAI STATUS
# ============================================

pai::is_installed() {
    [[ -d "$PAI_DIR" ]]
}

pai::version() {
    if pai::is_installed; then
        git -C "$PAI_DIR" log -1 --format="%h (%cr)" 2>/dev/null || echo "unknown"
    else
        echo "not installed"
    fi
}

# ============================================
# PATTERNS
# ============================================

pai::list_patterns() {
    local patterns_dir="$PAI_DIR/patterns"
    if [[ -d "$patterns_dir" ]]; then
        find "$patterns_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
    fi
}

pai::get_pattern() {
    local pattern="$1"
    local patterns_dir="$PAI_DIR/patterns"
    local pattern_dir="$patterns_dir/$pattern"

    if [[ -d "$pattern_dir" ]]; then
        # Look for system.md (Fabric convention) or pattern.md
        if [[ -f "$pattern_dir/system.md" ]]; then
            cat "$pattern_dir/system.md"
        elif [[ -f "$pattern_dir/pattern.md" ]]; then
            cat "$pattern_dir/pattern.md"
        elif [[ -f "$pattern_dir/README.md" ]]; then
            cat "$pattern_dir/README.md"
        else
            echo "Pattern '$pattern' has no system.md or pattern.md" >&2
            return 1
        fi
    else
        echo "Pattern not found: $pattern" >&2
        return 1
    fi
}

pai::run_pattern() {
    local pattern="$1"
    shift
    local input="$*"

    # Get pattern content
    local system_prompt
    system_prompt=$(pai::get_pattern "$pattern") || return 1

    # Get user's preferred AI provider for patterns
    local provider
    provider=$(maestro::config 'skills.providers.light' 'ollama')

    case "$provider" in
        ollama)
            local model
            model=$(maestro::config 'ai.ollama.default_model' 'llama3.2')
            echo "$input" | ollama run "$model" "$system_prompt"
            ;;
        claude)
            echo "$input" | claude --print --system "$system_prompt"
            ;;
        llm)
            echo "$input" | llm -s "$system_prompt"
            ;;
        fabric)
            # Use Fabric directly if installed
            echo "$input" | fabric -p "$pattern"
            ;;
        *)
            echo "Unknown provider: $provider" >&2
            return 1
            ;;
    esac
}

# ============================================
# SCRIPTS / TOOLS
# ============================================

pai::list_scripts() {
    local bin_dir="$PAI_DIR/bin"
    if [[ -d "$bin_dir" ]]; then
        find "$bin_dir" -maxdepth 1 -type f -executable -exec basename {} \; | sort
    fi
}

pai::run_script() {
    local script="$1"
    shift
    local bin_dir="$PAI_DIR/bin"
    local script_path="$bin_dir/$script"

    if [[ -x "$script_path" ]]; then
        "$script_path" "$@"
    else
        echo "Script not found or not executable: $script" >&2
        return 1
    fi
}

# ============================================
# CONFIG TEMPLATES
# ============================================

pai::list_configs() {
    local config_dir="$PAI_DIR/config"
    if [[ -d "$config_dir" ]]; then
        find "$config_dir" -type f -name "*.yaml" -o -name "*.toml" -o -name "*.json" | \
            sed "s|$config_dir/||" | sort
    fi
}

pai::get_config() {
    local config="$1"
    local config_path="$PAI_DIR/config/$config"

    if [[ -f "$config_path" ]]; then
        cat "$config_path"
    else
        echo "Config not found: $config" >&2
        return 1
    fi
}

# ============================================
# CLI (when sourced directly)
# ============================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-help}"
    shift || true

    case "$cmd" in
        status|st)
            echo "PAI Status:"
            echo "  Installed: $(pai::is_installed && echo 'yes' || echo 'no')"
            echo "  Version: $(pai::version)"
            echo "  Directory: $PAI_DIR"
            ;;
        patterns|p)
            if [[ -z "${1:-}" ]]; then
                echo "Available patterns:"
                pai::list_patterns | sed 's/^/  /'
            else
                pai::get_pattern "$1"
            fi
            ;;
        run|r)
            if [[ -z "${1:-}" ]]; then
                echo "Usage: pai.sh run <pattern> [input]" >&2
                exit 1
            fi
            pattern="$1"
            shift
            if [[ -t 0 ]]; then
                # Interactive
                pai::run_pattern "$pattern" "$*"
            else
                # Piped input
                input=$(cat)
                pai::run_pattern "$pattern" "$input"
            fi
            ;;
        scripts|s)
            if [[ -z "${1:-}" ]]; then
                echo "Available scripts:"
                pai::list_scripts | sed 's/^/  /'
            else
                pai::run_script "$@"
            fi
            ;;
        configs|c)
            if [[ -z "${1:-}" ]]; then
                echo "Available configs:"
                pai::list_configs | sed 's/^/  /'
            else
                pai::get_config "$1"
            fi
            ;;
        update|u)
            "$MAESTRO_ROOT/vendor/sync.sh" update pai
            ;;
        help|--help|-h|*)
            cat <<EOF
pai.sh - PAI (Personal AI Infrastructure) adapter

Usage: pai.sh <command> [args]

Commands:
  status          Show PAI installation status
  patterns [name] List patterns or show specific pattern
  run <pattern>   Run a pattern with input (pipe or args)
  scripts [name]  List scripts or run specific script
  configs [name]  List configs or show specific config
  update          Update PAI from GitHub

Examples:
  pai.sh patterns                    # List all patterns
  pai.sh patterns summarize          # Show summarize pattern
  echo "text" | pai.sh run summarize # Run pattern on input
  pai.sh scripts                     # List available scripts
  pai.sh update                      # Pull latest from GitHub

Setup:
  1. Edit vendor/vendor.yaml and set your PAI repo URL
  2. Run: vendor sync pai
EOF
            ;;
    esac
fi
