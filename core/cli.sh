#!/usr/bin/env bash
# lifemaestro/core/cli.sh - 12-Factor CLI compliance layer
#
# This module provides:
# - Proper stdout/stderr separation
# - TTY and pipe detection
# - Exit codes
# - Signal handling
# - Quiet mode
# - Atomic file operations

# ============================================
# VERSION
# ============================================

MAESTRO_VERSION="0.2.0"

# ============================================
# EXIT CODES
# ============================================

readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1           # Generic error
readonly EXIT_CONFIG=2          # Configuration error
readonly EXIT_USAGE=64          # Command line usage error (EX_USAGE)
readonly EXIT_NOINPUT=66        # Cannot open input (EX_NOINPUT)
readonly EXIT_UNAVAILABLE=69    # Service unavailable (EX_UNAVAILABLE)
readonly EXIT_SOFTWARE=70       # Internal software error (EX_SOFTWARE)
readonly EXIT_IOERR=74          # I/O error (EX_IOERR)
readonly EXIT_TEMPFAIL=75       # Temporary failure (EX_TEMPFAIL)
readonly EXIT_NOPERM=77         # Permission denied (EX_NOPERM)
readonly EXIT_SIGINT=130        # Terminated by Ctrl+C (128 + SIGINT)
readonly EXIT_SIGTERM=143       # Terminated by SIGTERM (128 + SIGTERM)

# ============================================
# STREAM DETECTION
# ============================================

# Check if stdout is a terminal
cli::is_tty() {
    [[ -t 1 ]]
}

# Check if stderr is a terminal
cli::is_tty_err() {
    [[ -t 2 ]]
}

# Check if stdin has data (is being piped to)
cli::has_stdin() {
    [[ ! -t 0 ]]
}

# Check if stdout is being piped
cli::is_piped() {
    [[ ! -t 1 ]]
}

# ============================================
# COLOR SUPPORT
# ============================================

cli::setup_colors() {
    # Only enable colors if:
    # 1. stderr is a TTY (for status messages)
    # 2. NO_COLOR env is not set
    # 3. TERM is not "dumb"
    if cli::is_tty_err && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
        COLOR_RESET=$'\033[0m'
        COLOR_RED=$'\033[0;31m'
        COLOR_GREEN=$'\033[0;32m'
        COLOR_YELLOW=$'\033[0;33m'
        COLOR_BLUE=$'\033[0;34m'
        COLOR_BOLD=$'\033[1m'
        COLOR_DIM=$'\033[2m'
    else
        COLOR_RESET=''
        COLOR_RED=''
        COLOR_GREEN=''
        COLOR_YELLOW=''
        COLOR_BLUE=''
        COLOR_BOLD=''
        COLOR_DIM=''
    fi
}

# Initialize colors
cli::setup_colors

# ============================================
# OUTPUT MODES
# ============================================

MAESTRO_QUIET="${MAESTRO_QUIET:-false}"
MAESTRO_JSON="${MAESTRO_JSON:-false}"

cli::set_quiet() {
    MAESTRO_QUIET=true
}

cli::is_quiet() {
    [[ "$MAESTRO_QUIET" == "true" ]]
}

cli::set_json() {
    MAESTRO_JSON=true
    MAESTRO_QUIET=true  # JSON mode implies quiet (no stderr noise)
}

cli::is_json() {
    [[ "$MAESTRO_JSON" == "true" ]]
}

# ============================================
# OUTPUT FUNCTIONS
# ============================================
# RULE: Data goes to stdout, everything else to stderr

# Print data to stdout (only use for actual command output/data)
cli::out() {
    echo "$@"
}

# Print raw data without newline
cli::out_raw() {
    printf '%s' "$@"
}

# Print JSON data to stdout
cli::out_json() {
    if command -v jq &>/dev/null; then
        echo "$@" | jq .
    else
        echo "$@"
    fi
}

# Status/log messages go to stderr
cli::log() {
    cli::is_quiet && return
    echo "$@" >&2
}

cli::success() {
    cli::is_quiet && return
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*" >&2
}

cli::error() {
    # Errors always print, even in quiet mode
    echo -e "${COLOR_RED}✗${COLOR_RESET} $*" >&2
}

cli::warn() {
    cli::is_quiet && return
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $*" >&2
}

cli::info() {
    cli::is_quiet && return
    echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} $*" >&2
}

cli::debug() {
    [[ -z "${MAESTRO_DEBUG:-}" ]] && return
    echo -e "${COLOR_DIM}[DEBUG] $*${COLOR_RESET}" >&2
}

# Progress indicator (only if stderr is TTY)
cli::progress() {
    cli::is_quiet && return
    cli::is_tty_err || return
    printf '\r%s' "$*" >&2
}

cli::progress_done() {
    cli::is_quiet && return
    cli::is_tty_err || return
    printf '\r\033[K' >&2  # Clear line
}

# ============================================
# SIGNAL HANDLING
# ============================================

# Cleanup function - override in your script
MAESTRO_CLEANUP_FUNCS=()

cli::register_cleanup() {
    MAESTRO_CLEANUP_FUNCS+=("$1")
}

cli::cleanup() {
    local exit_code=$?

    # Run all registered cleanup functions
    for func in "${MAESTRO_CLEANUP_FUNCS[@]}"; do
        $func 2>/dev/null || true
    done

    # Remove temp files if any
    if [[ -n "${MAESTRO_TEMP_DIR:-}" ]] && [[ -d "$MAESTRO_TEMP_DIR" ]]; then
        rm -rf "$MAESTRO_TEMP_DIR"
    fi

    return $exit_code
}

cli::handle_sigint() {
    cli::log ""  # Newline after ^C
    cli::cleanup
    exit $EXIT_SIGINT
}

cli::handle_sigterm() {
    cli::cleanup
    exit $EXIT_SIGTERM
}

cli::setup_signals() {
    trap cli::handle_sigint SIGINT
    trap cli::handle_sigterm SIGTERM
    trap cli::cleanup EXIT
}

# ============================================
# ATOMIC FILE OPERATIONS
# ============================================

# Create a temporary directory for this session
cli::temp_dir() {
    if [[ -z "${MAESTRO_TEMP_DIR:-}" ]]; then
        MAESTRO_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/maestro.XXXXXX")
    fi
    echo "$MAESTRO_TEMP_DIR"
}

# Create a temporary file
cli::temp_file() {
    local suffix="${1:-}"
    mktemp "$(cli::temp_dir)/tmp${suffix}.XXXXXX"
}

# Atomic write: write to temp file, then move to destination
cli::atomic_write() {
    local dest="$1"
    local content="${2:-}"

    local temp_file
    temp_file=$(cli::temp_file)

    # Write content (from argument or stdin)
    if [[ -n "$content" ]]; then
        echo "$content" > "$temp_file"
    else
        cat > "$temp_file"
    fi

    # Ensure destination directory exists
    mkdir -p "$(dirname "$dest")"

    # Atomic move
    mv "$temp_file" "$dest"
}

# Atomic append (less atomic, but safer than direct append)
cli::atomic_append() {
    local dest="$1"
    local content="$2"

    if [[ ! -f "$dest" ]]; then
        cli::atomic_write "$dest" "$content"
        return
    fi

    local temp_file
    temp_file=$(cli::temp_file)

    # Copy existing + append
    cat "$dest" > "$temp_file"
    echo "$content" >> "$temp_file"

    mv "$temp_file" "$dest"
}

# ============================================
# ARGUMENT PARSING HELPERS
# ============================================

# Parse common flags from arguments
# Returns remaining args via MAESTRO_ARGS array
cli::parse_common_flags() {
    MAESTRO_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quiet)
                MAESTRO_QUIET=true
                shift
                ;;
            -j|--json)
                cli::set_json
                shift
                ;;
            -v|--version)
                cli::out "lifemaestro $MAESTRO_VERSION"
                exit $EXIT_SUCCESS
                ;;
            -h|--help)
                # Let the calling script handle help
                MAESTRO_ARGS+=("$1")
                shift
                ;;
            --debug)
                export MAESTRO_DEBUG=1
                shift
                ;;
            --no-color)
                export NO_COLOR=1
                cli::setup_colors
                shift
                ;;
            --)
                shift
                MAESTRO_ARGS+=("$@")
                break
                ;;
            *)
                MAESTRO_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# ============================================
# ERROR HANDLING
# ============================================

cli::die() {
    local exit_code="${1:-$EXIT_ERROR}"
    local message="${2:-}"

    if [[ -n "$message" ]]; then
        cli::error "$message"
    fi

    exit "$exit_code"
}

cli::die_usage() {
    local message="$1"
    cli::error "$message"
    cli::log "Run with --help for usage information"
    exit $EXIT_USAGE
}

cli::die_config() {
    local message="$1"
    cli::error "Configuration error: $message"
    exit $EXIT_CONFIG
}

# ============================================
# INITIALIZATION
# ============================================

cli::init() {
    cli::setup_signals
    cli::setup_colors
}

# Auto-initialize if sourced
cli::init
