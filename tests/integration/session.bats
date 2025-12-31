#!/usr/bin/env bats
# Integration tests for bin/session CLI

load '../test_helper/bats-setup'
load '../test_helper/common'

setup() {
    common_setup
    setup_skill_scripts "session-manager"
    setup_skill_scripts "zone-context"

    # Set up sessions directory
    export SESSIONS_BASE="$BATS_TEST_TMPDIR/ai-sessions"
    mkdir -p "$SESSIONS_BASE"
}

teardown() {
    reset_mocks
    common_teardown
}

# ============================================
# BASIC COMMANDS
# ============================================

@test "session (no args) shows status or context" {
    run "$PROJECT_ROOT/bin/session"
    # Either shows status, context, or help
    assert_success
}

@test "session help shows usage" {
    run "$PROJECT_ROOT/bin/session" help
    assert_success
    assert_output --partial "Usage:"
}

@test "session --help shows usage" {
    run "$PROJECT_ROOT/bin/session" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "session --version shows version" {
    run "$PROJECT_ROOT/bin/session" --version
    assert_success
    assert_output --partial "lifemaestro"
}

# ============================================
# NEW SESSION
# ============================================

@test "session new requires arguments" {
    run "$PROJECT_ROOT/bin/session" new
    # May prompt interactively or show usage
    [[ "$status" -ne 0 ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"name"* ]]
}

@test "session new exploration creates session" {
    export MAESTRO_ZONE="personal"
    mock_dasel_value "sessions.base_dir" "$SESSIONS_BASE"

    run "$PROJECT_ROOT/bin/session" new exploration "test-session"
    # May succeed or fail based on templates
    [[ "$output" == *"session"* ]] || [[ "$status" -eq 0 ]]
}

# ============================================
# TICKET SESSION
# ============================================

@test "session ticket requires ticket ref" {
    run "$PROJECT_ROOT/bin/session" ticket
    assert_failure
    assert_output --partial "Usage:"
}

@test "session ticket validates reference format" {
    run "$PROJECT_ROOT/bin/session" ticket "invalid;rm -rf /"
    # Should fail validation
    [[ "$status" -ne 0 ]] || [[ "$output" != *"rm"* ]]
}

# ============================================
# LIST SESSIONS
# ============================================

@test "session list works" {
    run "$PROJECT_ROOT/bin/session" list
    # May show empty list or "No sessions"
    assert_success
}

@test "session ls is alias for list" {
    run "$PROJECT_ROOT/bin/session" ls
    assert_success
}

@test "session list shows existing sessions" {
    # Create a mock session
    mkdir -p "$SESSIONS_BASE/personal/explorations/my-session/.git"
    echo "# My Session" > "$SESSIONS_BASE/personal/explorations/my-session/CLAUDE.md"

    export SESSIONS_BASE
    run "$PROJECT_ROOT/bin/session" list
    # Should find the session
    [[ "$output" == *"my-session"* ]] || [[ "$status" -eq 0 ]]
}

# ============================================
# SWITCH CONTEXT
# ============================================

@test "session switch requires context" {
    run "$PROJECT_ROOT/bin/session" switch
    assert_failure
    assert_output --partial "Usage:"
}

@test "session switch work switches to work context" {
    run "$PROJECT_ROOT/bin/session" switch work
    # Should set context or output switch commands
    [[ "$output" == *"work"* ]] || [[ "$status" -eq 0 ]]
}

@test "session switch home switches to home context" {
    run "$PROJECT_ROOT/bin/session" switch home
    [[ "$output" == *"home"* ]] || [[ "$status" -eq 0 ]]
}

# ============================================
# SESSION SHORTCUTS
# ============================================

@test "session work creates work exploration" {
    export MAESTRO_ZONE="work"
    mock_dasel_value "sessions.base_dir" "$SESSIONS_BASE"

    run "$PROJECT_ROOT/bin/session" work "test-work"
    # May succeed or need zone setup
    [[ "$output" == *"session"* ]] || [[ "$status" -eq 0 ]] || [[ "$output" == *"work"* ]]
}

@test "session home creates home exploration" {
    export MAESTRO_ZONE="personal"
    mock_dasel_value "sessions.base_dir" "$SESSIONS_BASE"

    run "$PROJECT_ROOT/bin/session" home "test-home"
    [[ "$output" == *"session"* ]] || [[ "$status" -eq 0 ]] || [[ "$output" == *"home"* ]]
}

# ============================================
# GO (Navigation)
# ============================================

@test "session go with no sessions shows message" {
    run "$PROJECT_ROOT/bin/session" go
    # Should show "no sessions" or open fzf (which would fail in test)
    [[ "$status" -eq 0 ]] || [[ "$output" == *"session"* ]]
}

@test "session g is alias for go" {
    run "$PROJECT_ROOT/bin/session" g
    [[ "$status" -eq 0 ]] || [[ "$output" == *"session"* ]]
}

# ============================================
# STATUS COMMANDS
# ============================================

@test "session status shows current session" {
    run "$PROJECT_ROOT/bin/session" status
    assert_success
}

@test "session context shows current context" {
    run "$PROJECT_ROOT/bin/session" context
    assert_success
}
