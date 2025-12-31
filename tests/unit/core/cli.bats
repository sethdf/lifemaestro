#!/usr/bin/env bats
# Tests for core/cli.sh

load '../../test_helper/bats-setup'
load '../../test_helper/common'

setup() {
    common_setup
}

teardown() {
    common_teardown
}

# ============================================
# EXIT CODES
# ============================================

@test "EXIT_SUCCESS is 0" {
    source "$MAESTRO_ROOT/core/cli.sh"
    assert_equal "$EXIT_SUCCESS" "0"
}

@test "EXIT_ERROR is 1" {
    source "$MAESTRO_ROOT/core/cli.sh"
    assert_equal "$EXIT_ERROR" "1"
}

@test "EXIT_CONFIG is 2" {
    source "$MAESTRO_ROOT/core/cli.sh"
    assert_equal "$EXIT_CONFIG" "2"
}

@test "EXIT_USAGE is 64" {
    source "$MAESTRO_ROOT/core/cli.sh"
    assert_equal "$EXIT_USAGE" "64"
}

@test "EXIT_NOPERM is 77" {
    source "$MAESTRO_ROOT/core/cli.sh"
    assert_equal "$EXIT_NOPERM" "77"
}

# ============================================
# OUTPUT FUNCTIONS
# ============================================

@test "cli::out writes to stdout" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run cli::out "test message"
    assert_success
    assert_output "test message"
}

@test "cli::out_raw writes without newline" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; cli::out_raw "test"; echo "end"'
    assert_output "testend"
}

@test "cli::log writes to stderr" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_QUIET=false
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; MAESTRO_QUIET=false; cli::log "log message"'
    assert_success
    assert_output "log message"
}

@test "cli::log suppressed in quiet mode" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; MAESTRO_QUIET=true; cli::log "log message"'
    assert_success
    assert_output ""
}

@test "cli::error always prints even in quiet mode" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; MAESTRO_QUIET=true; cli::error "error message" 2>&1'
    assert_success
    assert_output --partial "error message"
}

@test "cli::debug suppressed without MAESTRO_DEBUG" {
    source "$MAESTRO_ROOT/core/cli.sh"
    unset MAESTRO_DEBUG
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; unset MAESTRO_DEBUG; cli::debug "debug message"'
    assert_success
    assert_output ""
}

@test "cli::debug prints with MAESTRO_DEBUG set" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; MAESTRO_DEBUG=1; cli::debug "debug message" 2>&1'
    assert_success
    assert_output --partial "debug message"
}

# ============================================
# QUIET/JSON MODES
# ============================================

@test "cli::set_quiet enables quiet mode" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_QUIET=false
    cli::set_quiet
    assert_equal "$MAESTRO_QUIET" "true"
}

@test "cli::is_quiet returns true when quiet" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_QUIET=true
    run cli::is_quiet
    assert_success
}

@test "cli::is_quiet returns false when not quiet" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_QUIET=false
    run cli::is_quiet
    assert_failure
}

@test "cli::set_json enables json mode and quiet" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_JSON=false
    MAESTRO_QUIET=false
    cli::set_json
    assert_equal "$MAESTRO_JSON" "true"
    assert_equal "$MAESTRO_QUIET" "true"
}

# ============================================
# ARGUMENT PARSING
# ============================================

@test "cli::parse_common_flags extracts -q flag" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_QUIET=false
    cli::parse_common_flags -q some command
    assert_equal "$MAESTRO_QUIET" "true"
    assert_equal "${MAESTRO_ARGS[0]}" "some"
    assert_equal "${MAESTRO_ARGS[1]}" "command"
}

@test "cli::parse_common_flags extracts --quiet flag" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_QUIET=false
    cli::parse_common_flags --quiet test
    assert_equal "$MAESTRO_QUIET" "true"
}

@test "cli::parse_common_flags handles --debug" {
    source "$MAESTRO_ROOT/core/cli.sh"
    unset MAESTRO_DEBUG
    cli::parse_common_flags --debug test
    assert_equal "$MAESTRO_DEBUG" "1"
}

@test "cli::parse_common_flags handles --no-color" {
    source "$MAESTRO_ROOT/core/cli.sh"
    unset NO_COLOR
    cli::parse_common_flags --no-color test
    assert_equal "$NO_COLOR" "1"
}

@test "cli::parse_common_flags handles -j/--json" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_JSON=false
    cli::parse_common_flags -j test
    assert_equal "$MAESTRO_JSON" "true"
}

@test "cli::parse_common_flags preserves -- separator" {
    source "$MAESTRO_ROOT/core/cli.sh"
    MAESTRO_QUIET=false
    cli::parse_common_flags -- -q --debug
    assert_equal "$MAESTRO_QUIET" "false"
    assert_equal "${MAESTRO_ARGS[0]}" "-q"
    assert_equal "${MAESTRO_ARGS[1]}" "--debug"
}

@test "cli::parse_common_flags preserves non-flag args" {
    source "$MAESTRO_ROOT/core/cli.sh"
    cli::parse_common_flags arg1 arg2 arg3
    assert_equal "${MAESTRO_ARGS[0]}" "arg1"
    assert_equal "${MAESTRO_ARGS[1]}" "arg2"
    assert_equal "${MAESTRO_ARGS[2]}" "arg3"
}

# ============================================
# ERROR HANDLING
# ============================================

@test "cli::die exits with given code" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; cli::die 42'
    assert_failure 42
}

@test "cli::die exits with default code 1" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; cli::die'
    assert_failure 1
}

@test "cli::die prints message to stderr" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; cli::die 1 "error message" 2>&1'
    assert_failure 1
    assert_output --partial "error message"
}

@test "cli::die_usage exits with EXIT_USAGE (64)" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; cli::die_usage "bad usage" 2>&1'
    assert_failure 64
    assert_output --partial "bad usage"
}

@test "cli::die_config exits with EXIT_CONFIG (2)" {
    source "$MAESTRO_ROOT/core/cli.sh"
    run bash -c 'source "$MAESTRO_ROOT/core/cli.sh"; cli::die_config "bad config" 2>&1'
    assert_failure 2
    assert_output --partial "Configuration error"
    assert_output --partial "bad config"
}

# ============================================
# TEMP FILES
# ============================================

@test "cli::temp_dir creates directory" {
    source "$MAESTRO_ROOT/core/cli.sh"
    local temp_dir
    temp_dir=$(cli::temp_dir)
    assert [ -d "$temp_dir" ]
    rm -rf "$temp_dir"
}

@test "cli::temp_dir returns same directory on subsequent calls" {
    source "$MAESTRO_ROOT/core/cli.sh"
    local dir1 dir2
    dir1=$(cli::temp_dir)
    dir2=$(cli::temp_dir)
    assert_equal "$dir1" "$dir2"
    rm -rf "$dir1"
}

@test "cli::temp_file creates file in temp_dir" {
    source "$MAESTRO_ROOT/core/cli.sh"
    local temp_file temp_dir
    temp_dir=$(cli::temp_dir)
    temp_file=$(cli::temp_file)
    assert [ -f "$temp_file" ]
    assert [[ "$temp_file" == "$temp_dir"/* ]]
    rm -rf "$temp_dir"
}

# ============================================
# ATOMIC OPERATIONS
# ============================================

@test "cli::atomic_write creates file with content" {
    source "$MAESTRO_ROOT/core/cli.sh"
    local dest="$BATS_TEST_TMPDIR/atomic_test.txt"
    cli::atomic_write "$dest" "test content"
    assert [ -f "$dest" ]
    run cat "$dest"
    assert_output "test content"
}

@test "cli::atomic_write creates parent directories" {
    source "$MAESTRO_ROOT/core/cli.sh"
    local dest="$BATS_TEST_TMPDIR/nested/dir/file.txt"
    cli::atomic_write "$dest" "nested content"
    assert [ -f "$dest" ]
}

@test "cli::atomic_append appends to existing file" {
    source "$MAESTRO_ROOT/core/cli.sh"
    local dest="$BATS_TEST_TMPDIR/append_test.txt"
    echo "line1" > "$dest"
    cli::atomic_append "$dest" "line2"
    run cat "$dest"
    assert_output "line1
line2"
}

@test "cli::atomic_append creates file if not exists" {
    source "$MAESTRO_ROOT/core/cli.sh"
    local dest="$BATS_TEST_TMPDIR/new_append.txt"
    cli::atomic_append "$dest" "first line"
    assert [ -f "$dest" ]
    run cat "$dest"
    assert_output "first line"
}

# ============================================
# VERSION
# ============================================

@test "MAESTRO_VERSION is set" {
    source "$MAESTRO_ROOT/core/cli.sh"
    assert [ -n "$MAESTRO_VERSION" ]
}

@test "MAESTRO_VERSION matches expected format" {
    source "$MAESTRO_ROOT/core/cli.sh"
    [[ "$MAESTRO_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
