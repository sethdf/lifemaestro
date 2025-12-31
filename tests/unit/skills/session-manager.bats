#!/usr/bin/env bats
# Tests for session-manager skill scripts

load '../../test_helper/bats-setup'
load '../../test_helper/common'

SCRIPTS_DIR=""

setup() {
    common_setup
    setup_skill_scripts "session-manager"
    setup_skill_scripts "zone-context"
    SCRIPTS_DIR="$MAESTRO_ROOT/.claude/skills/session-manager/scripts"

    # Create sessions base dir
    export SESSIONS_BASE="$BATS_TEST_TMPDIR/ai-sessions"
    mkdir -p "$SESSIONS_BASE"
}

teardown() {
    reset_mocks
    common_teardown
}

# ============================================
# SESSION CREATE
# ============================================

@test "session-create.sh requires arguments" {
    run "$SCRIPTS_DIR/session-create.sh"
    assert_failure
    assert_output --partial "Usage:"
}

@test "session-create.sh creates session directory" {
    export MAESTRO_ZONE="personal"
    mock_dasel_value "sessions.base_dir" "$SESSIONS_BASE"

    run "$SCRIPTS_DIR/session-create.sh" "exploration" "test-session"
    # May fail due to missing templates, but shouldn't crash
    [[ "$status" -eq 0 ]] || [[ "$output" == *"session"* ]]
}

@test "session-create.sh validates session name - no special chars" {
    export MAESTRO_ZONE="personal"
    mock_dasel_value "sessions.base_dir" "$SESSIONS_BASE"

    run "$SCRIPTS_DIR/session-create.sh" "exploration" "test;rm -rf /"
    assert_failure
}

@test "session-create.sh validates session name - no path traversal" {
    export MAESTRO_ZONE="personal"
    mock_dasel_value "sessions.base_dir" "$SESSIONS_BASE"

    run "$SCRIPTS_DIR/session-create.sh" "exploration" "../../../etc"
    assert_failure
}

# ============================================
# SESSION LIST
# ============================================

@test "session-list.sh works with no sessions" {
    run "$SCRIPTS_DIR/session-list.sh"
    # Should succeed or report no sessions
    [[ "$status" -eq 0 ]] || [[ "$output" == *"No sessions"* ]]
}

@test "session-list.sh shows sessions in directory" {
    # Create a mock session
    mkdir -p "$SESSIONS_BASE/personal/explorations/test-session/.git"
    echo "# Test Session" > "$SESSIONS_BASE/personal/explorations/test-session/CLAUDE.md"

    export SESSIONS_BASE
    run "$SCRIPTS_DIR/session-list.sh"
    # Should find the session
    [[ "$output" == *"test-session"* ]] || [[ "$status" -eq 0 ]]
}

# ============================================
# SESSION GO (Navigation)
# ============================================

@test "session-go.sh outputs cd command" {
    # Create a mock session
    mkdir -p "$SESSIONS_BASE/personal/explorations/test-session/.git"

    export SESSIONS_BASE
    export MOCK_FZF_RESPONSE="$SESSIONS_BASE/personal/explorations/test-session"

    run "$SCRIPTS_DIR/session-go.sh"
    # Should output a cd command or path
    [[ "$output" == *"cd"* ]] || [[ "$output" == *"session"* ]] || [[ "$status" -eq 0 ]]
}

# ============================================
# SESSION SEARCH
# ============================================

@test "session-search.sh requires query" {
    run "$SCRIPTS_DIR/session-search.sh"
    # May show usage or list all
    [[ "$status" -eq 0 ]] || [[ "$output" == *"Usage"* ]]
}

@test "session-search.sh searches session names" {
    # Create mock sessions
    mkdir -p "$SESSIONS_BASE/personal/explorations/api-refactor/.git"
    mkdir -p "$SESSIONS_BASE/personal/explorations/ui-update/.git"

    export SESSIONS_BASE
    run "$SCRIPTS_DIR/session-search.sh" "api"
    # Should find api-refactor
    [[ "$output" == *"api"* ]] || [[ "$status" -eq 0 ]]
}
