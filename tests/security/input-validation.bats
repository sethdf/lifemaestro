#!/usr/bin/env bats
# Security tests for input validation across all commands

load '../test_helper/bats-setup'
load '../test_helper/common'

setup() {
    common_setup
    setup_skill_scripts "zone-context"
    setup_skill_scripts "session-manager"
    setup_skill_scripts "ticket-lookup"

    # Set up sessions directory
    export SESSIONS_BASE="$BATS_TEST_TMPDIR/ai-sessions"
    mkdir -p "$SESSIONS_BASE"
}

teardown() {
    reset_mocks
    common_teardown
}

# ============================================
# COMMAND INJECTION - SEMICOLON
# ============================================

@test "zone rejects semicolon injection" {
    run "$PROJECT_ROOT/bin/zone" switch "zone;echo hacked"
    assert_failure
    assert_output --partial "Invalid zone name"
    refute_output --partial "hacked"
}

@test "session rejects semicolon injection in name" {
    run "$PROJECT_ROOT/bin/session" new exploration "test;echo hacked"
    assert_failure
    refute_output --partial "hacked"
}

# ============================================
# COMMAND INJECTION - PIPE
# ============================================

@test "zone rejects pipe injection" {
    run "$PROJECT_ROOT/bin/zone" switch "zone|cat /etc/passwd"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "session rejects pipe injection" {
    run "$PROJECT_ROOT/bin/session" new exploration "test|cat /etc/passwd"
    assert_failure
}

# ============================================
# COMMAND INJECTION - BACKTICKS
# ============================================

@test "zone rejects backtick injection" {
    run "$PROJECT_ROOT/bin/zone" switch 'zone`whoami`'
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "session rejects backtick injection" {
    run "$PROJECT_ROOT/bin/session" new exploration 'test`id`'
    assert_failure
}

# ============================================
# COMMAND INJECTION - DOLLAR EXPANSION
# ============================================

@test "zone rejects dollar expansion" {
    run "$PROJECT_ROOT/bin/zone" switch 'zone$(whoami)'
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone rejects dollar brace expansion" {
    run "$PROJECT_ROOT/bin/zone" switch 'zone${USER}'
    assert_failure
}

@test "session rejects dollar expansion" {
    run "$PROJECT_ROOT/bin/session" new exploration 'test$(id)'
    assert_failure
}

# ============================================
# PATH TRAVERSAL
# ============================================

@test "zone rejects path traversal with .." {
    run "$PROJECT_ROOT/bin/zone" switch "../etc"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone rejects deep path traversal" {
    run "$PROJECT_ROOT/bin/zone" switch "../../../../../../etc/passwd"
    assert_failure
}

@test "zone rejects absolute path" {
    run "$PROJECT_ROOT/bin/zone" switch "/etc/passwd"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone rejects tilde expansion" {
    run "$PROJECT_ROOT/bin/zone" switch "~root"
    assert_failure
}

@test "session rejects path traversal" {
    run "$PROJECT_ROOT/bin/session" new exploration "../../../etc"
    assert_failure
}

# ============================================
# SPECIAL CHARACTERS
# ============================================

@test "zone rejects ampersand" {
    run "$PROJECT_ROOT/bin/zone" switch "zone&echo hacked"
    assert_failure
}

@test "zone rejects double ampersand" {
    run "$PROJECT_ROOT/bin/zone" switch "zone&&echo hacked"
    assert_failure
}

@test "zone rejects greater than (redirect)" {
    run "$PROJECT_ROOT/bin/zone" switch "zone>file"
    assert_failure
}

@test "zone rejects less than (redirect)" {
    run "$PROJECT_ROOT/bin/zone" switch "zone<file"
    assert_failure
}

@test "zone rejects newlines" {
    run "$PROJECT_ROOT/bin/zone" switch $'zone\necho hacked'
    assert_failure
}

@test "zone rejects carriage return" {
    run "$PROJECT_ROOT/bin/zone" switch $'zone\recho hacked'
    assert_failure
}

@test "zone rejects tab characters" {
    run "$PROJECT_ROOT/bin/zone" switch $'zone\techo hacked'
    assert_failure
}

@test "zone rejects null bytes" {
    run "$PROJECT_ROOT/bin/zone" switch $'zone\x00hacked'
    assert_failure
}

# ============================================
# QUOTES
# ============================================

@test "zone rejects single quotes" {
    run "$PROJECT_ROOT/bin/zone" switch "zone'test"
    assert_failure
}

@test "zone rejects double quotes" {
    run "$PROJECT_ROOT/bin/zone" switch 'zone"test'
    assert_failure
}

# ============================================
# VALID INPUT ACCEPTANCE
# ============================================

@test "zone accepts lowercase letters" {
    mock_dasel_value "zones.validzone.name" "validzone"
    run "$PROJECT_ROOT/bin/zone" switch "validzone"
    assert_success
}

@test "zone accepts uppercase letters" {
    mock_dasel_value "zones.VALIDZONE.name" "VALIDZONE"
    run "$PROJECT_ROOT/bin/zone" switch "VALIDZONE"
    assert_success
}

@test "zone accepts numbers" {
    mock_dasel_value "zones.zone123.name" "zone123"
    run "$PROJECT_ROOT/bin/zone" switch "zone123"
    assert_success
}

@test "zone accepts dashes" {
    mock_dasel_value "zones.my-zone.name" "my-zone"
    run "$PROJECT_ROOT/bin/zone" switch "my-zone"
    assert_success
}

@test "zone accepts underscores" {
    mock_dasel_value "zones.my_zone.name" "my_zone"
    run "$PROJECT_ROOT/bin/zone" switch "my_zone"
    assert_success
}

@test "zone accepts mixed valid characters" {
    mock_dasel_value "zones.My-Zone_123.name" "My-Zone_123"
    run "$PROJECT_ROOT/bin/zone" switch "My-Zone_123"
    assert_success
}

# ============================================
# TICKET INPUT VALIDATION
# ============================================

@test "ticket sdp rejects SQL injection" {
    run "$PROJECT_ROOT/bin/ticket" sdp "12345; DROP TABLE requests;--"
    assert_failure
}

@test "ticket jira rejects command injection" {
    export MAESTRO_ZONE="work"
    export JIRA_EMAIL="test@example.com"
    export JIRA_API_TOKEN="test"
    mock_dasel_value "zones.work.features.jira" "true"

    run "$PROJECT_ROOT/bin/ticket" jira "PROJ-123;echo hacked"
    # Should fail or sanitize
    refute_output --partial "hacked"
}

@test "ticket github rejects URL injection" {
    run "$PROJECT_ROOT/bin/ticket" github "https://evil.com/owner/repo/issues/123"
    # Should fail or only accept github.com
    [[ "$status" -ne 0 ]] || [[ "$output" != *"evil.com"* ]]
}

# ============================================
# EMPTY AND WHITESPACE
# ============================================

@test "zone rejects empty string" {
    run "$PROJECT_ROOT/bin/zone" switch ""
    assert_failure
}

@test "zone rejects whitespace only" {
    run "$PROJECT_ROOT/bin/zone" switch "   "
    assert_failure
}

@test "session rejects empty name" {
    run "$PROJECT_ROOT/bin/session" new exploration ""
    assert_failure
}

# ============================================
# UNICODE AND ENCODING
# ============================================

@test "zone rejects unicode characters" {
    run "$PROJECT_ROOT/bin/zone" switch "zone名前"
    assert_failure
}

@test "zone rejects emoji" {
    run "$PROJECT_ROOT/bin/zone" switch "zone😀"
    assert_failure
}

@test "zone rejects URL-encoded characters" {
    run "$PROJECT_ROOT/bin/zone" switch "zone%20test"
    assert_failure
}

# ============================================
# VERY LONG INPUT
# ============================================

@test "zone handles very long input" {
    local long_name=$(printf 'a%.0s' {1..1000})
    run "$PROJECT_ROOT/bin/zone" switch "$long_name"
    # Should either accept (valid chars) or fail gracefully (no crash)
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "session handles very long name" {
    local long_name=$(printf 'a%.0s' {1..1000})
    run "$PROJECT_ROOT/bin/session" new exploration "$long_name"
    # Should handle gracefully
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}
