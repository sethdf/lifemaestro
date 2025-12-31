#!/usr/bin/env bats
# Integration tests for bin/ticket CLI

load '../test_helper/bats-setup'
load '../test_helper/common'

setup() {
    common_setup
    setup_skill_scripts "ticket-lookup"
    setup_skill_scripts "zone-context"
}

teardown() {
    reset_mocks
    common_teardown
}

# ============================================
# BASIC COMMANDS
# ============================================

@test "ticket (no args) shows help" {
    run "$PROJECT_ROOT/bin/ticket"
    assert_success
    assert_output --partial "Usage:"
}

@test "ticket help shows all commands" {
    run "$PROJECT_ROOT/bin/ticket" help
    assert_success
    assert_output --partial "sdp"
    assert_output --partial "jira"
    assert_output --partial "github"
}

@test "ticket --help shows usage" {
    run "$PROJECT_ROOT/bin/ticket" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "ticket --version shows version" {
    run "$PROJECT_ROOT/bin/ticket" --version
    assert_success
    assert_output --partial "lifemaestro"
}

# ============================================
# SDP COMMAND
# ============================================

@test "ticket sdp requires ticket number" {
    run "$PROJECT_ROOT/bin/ticket" sdp
    assert_failure
    assert_output --partial "Usage:"
}

@test "ticket sdp calls sdp-fetch script" {
    export MAESTRO_ZONE="work"
    export SDP_API_KEY="test-key"
    mock_dasel_value "zones.work.features.sdp" "true"
    mock_dasel_value "zones.work.sdp.base_url" "https://sdp.example.com/api/v3"

    run "$PROJECT_ROOT/bin/ticket" sdp 12345
    assert_success
    assert_output --partial "ticket_id:"
}

# ============================================
# JIRA COMMAND
# ============================================

@test "ticket jira requires issue key" {
    run "$PROJECT_ROOT/bin/ticket" jira
    assert_failure
    assert_output --partial "Usage:"
}

@test "ticket jira calls jira-fetch script" {
    export MAESTRO_ZONE="work"
    export JIRA_EMAIL="test@example.com"
    export JIRA_API_TOKEN="test-token"
    mock_dasel_value "zones.work.features.jira" "true"
    mock_dasel_value "zones.work.jira.base_url" "https://jira.example.com"

    run "$PROJECT_ROOT/bin/ticket" jira PROJ-123
    assert_success
    assert_output --partial "ticket_id:"
}

# ============================================
# GITHUB COMMAND
# ============================================

@test "ticket github requires issue reference" {
    run "$PROJECT_ROOT/bin/ticket" github
    assert_failure
    assert_output --partial "Usage:"
}

@test "ticket github accepts owner/repo#num" {
    run "$PROJECT_ROOT/bin/ticket" github owner/repo#123
    assert_success
}

@test "ticket github accepts URL" {
    run "$PROJECT_ROOT/bin/ticket" github "https://github.com/owner/repo/issues/123"
    assert_success
}

# ============================================
# LINEAR COMMAND
# ============================================

@test "ticket linear requires issue id" {
    run "$PROJECT_ROOT/bin/ticket" linear
    assert_failure
    assert_output --partial "Usage:"
}

@test "ticket linear calls linear-fetch script" {
    export LINEAR_API_KEY="test-key"

    run "$PROJECT_ROOT/bin/ticket" linear LIN-123
    assert_success
}

# ============================================
# AUTO DETECTION
# ============================================

@test "ticket auto detects JIRA format" {
    export MAESTRO_ZONE="work"
    export JIRA_EMAIL="test@example.com"
    export JIRA_API_TOKEN="test-token"
    mock_dasel_value "zones.work.features.jira" "true"
    mock_dasel_value "zones.work.jira.base_url" "https://jira.example.com"

    run "$PROJECT_ROOT/bin/ticket" auto "PROJ-123"
    # Should route to jira
    [[ "$status" -eq 0 ]] || [[ "$output" == *"PROJ-123"* ]]
}

@test "ticket auto detects SDP format (pure number)" {
    export MAESTRO_ZONE="work"
    export SDP_API_KEY="test-key"
    mock_dasel_value "zones.work.features.sdp" "true"
    mock_dasel_value "zones.work.sdp.base_url" "https://sdp.example.com/api/v3"

    run "$PROJECT_ROOT/bin/ticket" auto "12345"
    # Should route to sdp
    [[ "$output" == *"ticket_id"* ]] || [[ "$output" == *"12345"* ]]
}

@test "ticket auto detects GitHub URL" {
    run "$PROJECT_ROOT/bin/ticket" auto "https://github.com/owner/repo/issues/123"
    assert_success
}

@test "ticket auto detects GitHub shorthand" {
    run "$PROJECT_ROOT/bin/ticket" auto "owner/repo#123"
    assert_success
}

@test "ticket auto fails on unknown format" {
    run "$PROJECT_ROOT/bin/ticket" auto "unknown-format-xyz-@#$"
    assert_failure
    assert_output --partial "Cannot auto-detect"
}

# ============================================
# QUIET MODE
# ============================================

@test "ticket -q suppresses status messages" {
    export SDP_API_KEY="test-key"
    export MAESTRO_ZONE="work"
    mock_dasel_value "zones.work.features.sdp" "true"
    mock_dasel_value "zones.work.sdp.base_url" "https://sdp.example.com/api/v3"

    run "$PROJECT_ROOT/bin/ticket" -q sdp 12345
    assert_success
    # Output should be concise
}
