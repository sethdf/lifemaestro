#!/usr/bin/env bash
# adapters/vendor/fabric.sh - Fabric integration
# Supports: standalone Fabric CLI, PAI patterns, or vendor/fabric patterns

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"

# ============================================
# FABRIC DETECTION
# ============================================

fabric::mode() {
    # Check for standalone Fabric CLI first (preferred)
    if command -v fabric &>/dev/null; then
        echo "cli"
        return
    fi

    # Check for PAI patterns (if PAI is installed and has patterns)
    if [[ -d "$MAESTRO_ROOT/vendor/pai/patterns" ]]; then
        echo "pai"
        return
    fi

    # Check for standalone vendor/fabric
    if [[ -d "$MAESTRO_ROOT/vendor/fabric/patterns" ]]; then
        echo "vendor"
        return
    fi

    echo "none"
}

fabric::patterns_dir() {
    local mode
    mode=$(fabric::mode)

    case "$mode" in
        cli)
            # Fabric CLI stores patterns in ~/.config/fabric/patterns
            echo "${FABRIC_PATTERNS_DIR:-$HOME/.config/fabric/patterns}"
            ;;
        pai)
            echo "$MAESTRO_ROOT/vendor/pai/patterns"
            ;;
        vendor)
            echo "$MAESTRO_ROOT/vendor/fabric/patterns"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ============================================
# PATTERN OPERATIONS
# ============================================

fabric::list_patterns() {
    local mode
    mode=$(fabric::mode)

    case "$mode" in
        cli)
            fabric --list 2>/dev/null || find "$(fabric::patterns_dir)" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null
            ;;
        pai|vendor)
            local dir
            dir=$(fabric::patterns_dir)
            if [[ -d "$dir" ]]; then
                find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
            fi
            ;;
        *)
            echo "Fabric not available. Install Fabric or configure PAI." >&2
            return 1
            ;;
    esac
}

fabric::get_pattern() {
    local pattern="$1"
    local dir
    dir=$(fabric::patterns_dir)

    if [[ -d "$dir/$pattern" ]]; then
        if [[ -f "$dir/$pattern/system.md" ]]; then
            cat "$dir/$pattern/system.md"
        elif [[ -f "$dir/$pattern/user.md" ]]; then
            cat "$dir/$pattern/user.md"
        else
            echo "Pattern '$pattern' found but no system.md" >&2
            return 1
        fi
    else
        echo "Pattern not found: $pattern" >&2
        return 1
    fi
}

fabric::run() {
    local pattern="$1"
    shift
    local input="${*:-}"

    local mode
    mode=$(fabric::mode)

    # Read from stdin if no input provided
    if [[ -z "$input" ]] && [[ ! -t 0 ]]; then
        input=$(cat)
    fi

    case "$mode" in
        cli)
            # Use native Fabric CLI
            echo "$input" | fabric -p "$pattern"
            ;;
        pai|vendor)
            # Use PAI/vendor patterns with user's AI provider
            local system_prompt
            system_prompt=$(fabric::get_pattern "$pattern") || return 1

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
                *)
                    echo "Unknown provider: $provider" >&2
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "Fabric not available. Install Fabric or configure PAI." >&2
            echo "  Install Fabric: go install github.com/danielmiessler/fabric@latest" >&2
            echo "  Or configure PAI: edit vendor/vendor.yaml" >&2
            return 1
            ;;
    esac
}

# ============================================
# YOUTUBE / CONTENT EXTRACTION
# ============================================

fabric::youtube() {
    local url="$1"
    local pattern="${2:-extract_wisdom}"

    local mode
    mode=$(fabric::mode)

    if [[ "$mode" == "cli" ]]; then
        # Fabric CLI has built-in YouTube support
        fabric -y "$url" -p "$pattern"
    else
        # Need yt tool or yt-dlp
        if command -v yt &>/dev/null; then
            yt --transcript "$url" | fabric::run "$pattern"
        elif command -v yt-dlp &>/dev/null; then
            # Get auto-generated subtitles
            local temp_dir
            temp_dir=$(mktemp -d)
            yt-dlp --skip-download --write-auto-sub --sub-format vtt --sub-lang en \
                -o "$temp_dir/%(id)s" "$url" 2>/dev/null

            local vtt_file
            vtt_file=$(find "$temp_dir" -name "*.vtt" | head -1)
            if [[ -f "$vtt_file" ]]; then
                # Convert VTT to plain text
                sed '1,/^$/d' "$vtt_file" | grep -v '^[0-9]' | grep -v '^$' | tr '\n' ' ' | \
                    fabric::run "$pattern"
            else
                echo "Could not extract transcript from: $url" >&2
                return 1
            fi
            rm -rf "$temp_dir"
        else
            echo "No YouTube extraction tool available. Install yt-dlp." >&2
            return 1
        fi
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
            mode=$(fabric::mode)
            echo "Fabric Status:"
            echo "  Mode: $mode"
            case "$mode" in
                cli)
                    echo "  Using: Fabric CLI (native)"
                    fabric --version 2>/dev/null || echo "  Version: unknown"
                    ;;
                pai)
                    echo "  Using: PAI patterns"
                    echo "  Dir: $MAESTRO_ROOT/vendor/pai/patterns"
                    ;;
                vendor)
                    echo "  Using: Vendor patterns"
                    echo "  Dir: $MAESTRO_ROOT/vendor/fabric/patterns"
                    ;;
                *)
                    echo "  Not installed"
                    echo ""
                    echo "Install options:"
                    echo "  1. Fabric CLI: go install github.com/danielmiessler/fabric@latest"
                    echo "  2. Configure PAI (includes Fabric patterns): vendor sync pai"
                    ;;
            esac
            ;;
        list|ls|l)
            fabric::list_patterns
            ;;
        show|get|s)
            if [[ -z "${1:-}" ]]; then
                echo "Usage: fabric.sh show <pattern>" >&2
                exit 1
            fi
            fabric::get_pattern "$1"
            ;;
        run|r)
            if [[ -z "${1:-}" ]]; then
                echo "Usage: fabric.sh run <pattern> [input]" >&2
                exit 1
            fi
            fabric::run "$@"
            ;;
        youtube|yt|y)
            if [[ -z "${1:-}" ]]; then
                echo "Usage: fabric.sh youtube <url> [pattern]" >&2
                exit 1
            fi
            fabric::youtube "$@"
            ;;
        help|--help|-h|*)
            cat <<EOF
fabric.sh - Fabric pattern integration

Usage: fabric.sh <command> [args]

Commands:
  status          Show Fabric installation status
  list            List available patterns
  show <pattern>  Show pattern content
  run <pattern>   Run pattern on input (pipe or args)
  youtube <url>   Extract and process YouTube content

Examples:
  fabric.sh list                          # List patterns
  fabric.sh show summarize                # Show pattern
  echo "text" | fabric.sh run summarize   # Run pattern
  fabric.sh youtube URL extract_wisdom    # Process YouTube

Modes:
  cli     - Uses native Fabric CLI (preferred)
  pai     - Uses PAI patterns with configured AI provider
  vendor  - Uses vendor/fabric patterns

Setup:
  Option 1: Install Fabric CLI
    go install github.com/danielmiessler/fabric@latest
    fabric --setup

  Option 2: Use PAI patterns
    Edit vendor/vendor.yaml, set PAI repo URL
    Run: vendor sync pai
EOF
            ;;
    esac
fi
