#!/usr/bin/env bats
# Tests for ticket-lookup skill scripts

load '../../test_helper/bats-setup'
load '../../test_helper/common'

SCRIPTS_DIR=""

setup() {
    common_setup
    setup_skill_scripts "ticket-lookup"
    setup_skill_scripts "zone-context"
    SCRIPTS_DIR="$MAESTRO_ROOT/.claude/skills/ticket-lookup/scripts"
}

teardown() {
    reset_mocks
    common_teardown
}

# ============================================
# JIRA FETCH
# ============================================

@test "jira-fetch.sh requires issue key argument" {
    run "$SCRIPTS_DIR/jira-fetch.sh"
    assert_failure
    assert_output --partial "Usage:"
}

@test "jira-fetch.sh fails without JIRA_EMAIL" {
    export MAESTRO_ZONE="work"
    mock_dasel_value "zones.work.features.jira" "true"
    mock_dasel_value "zones.work.jira.base_url" "https://jira.example.com"
    unset JIRA_EMAIL
    export JIRA_API_TOKEN="test-token"
    run "$SCRIPTS_DIR/jira-fetch.sh" "PROJ-123"
    assert_failure
    assert_output --partial "JIRA_EMAIL"
}

@test "jira-fetch.sh fails without JIRA_API_TOKEN" {
    export MAESTRO_ZONE="work"
    mock_dasel_value "zones.work.features.jira" "true"
    mock_dasel_value "zones.work.jira.base_url" "https://jira.example.com"
    export JIRA_EMAIL="test@example.com"
    unset JIRA_API_TOKEN
    run "$SCRIPTS_DIR/jira-fetch.sh" "PROJ-123"
    assert_failure
    assert_output --partial "JIRA_API_TOKEN"
}

@test "jira-fetch.sh makes API call with credentials" {
    export MAESTRO_ZONE="work"
    export JIRA_EMAIL="test@example.com"
    export JIRA_API_TOKEN="test-token"
    mock_dasel_value "zones.work.features.jira" "true"
    mock_dasel_value "zones.work.jira.base_url" "https://jira.example.com"

    run "$SCRIPTS_DIR/jira-fetch.sh" "PROJ-123"
    assert_success

    # Verify curl was called
    run cat "${BATS_TEST_TMPDIR}/curl.calls"
    assert_output --partial "jira"
}

@test "jira-fetch.sh returns structured data" {
    export MAESTRO_ZONE="work"
    export JIRA_EMAIL="test@example.com"
    export JIRA_API_TOKEN="test-token"
    mock_dasel_value "zones.work.features.jira" "true"
    mock_dasel_value "zones.work.jira.base_url" "https://jira.example.com"

    run "$SCRIPTS_DIR/jira-fetch.sh" "PROJ-123"
    assert_success
    assert_output --partial "ticket_id:"
}

# ============================================
# GITHUB FETCH
# ============================================

@test "github-fetch.sh requires issue reference" {
    run "$SCRIPTS_DIR/github-fetch.sh"
    assert_failure
    assert_output --partial "Usage:"
}

@test "github-fetch.sh accepts owner/repo#num format" {
    run "$SCRIPTS_DIR/github-fetch.sh" "owner/repo#123"
    assert_success
    assert_output --partial "ticket_id:"
}

@test "github-fetch.sh accepts URL format" {
    run "$SCRIPTS_DIR/github-fetch.sh" "https://github.com/owner/repo/issues/123"
    assert_success
}

@test "github-fetch.sh accepts PR URL" {
    run "$SCRIPTS_DIR/github-fetch.sh" "https://github.com/owner/repo/pull/456"
    assert_success
}

@test "github-fetch.sh fails with invalid format" {
    run "$SCRIPTS_DIR/github-fetch.sh" "invalid"
    assert_failure
}

@test "github-fetch.sh uses gh CLI" {
    run "$SCRIPTS_DIR/github-fetch.sh" "owner/repo#123"

    # Check gh was called
    if [[ -f "${BATS_TEST_TMPDIR}/gh.calls" ]]; then
        run cat "${BATS_TEST_TMPDIR}/gh.calls"
        assert_output --partial "issue" || assert_output --partial "api"
    fi
}

# ============================================
# SDP FETCH
# ============================================

@test "sdp-fetch.sh requires ticket number" {
    run "$SCRIPTS_DIR/sdp-fetch.sh"
    assert_failure
    assert_output --partial "Usage:"
}

@test "sdp-fetch.sh fails without SDP_API_KEY" {
    export MAESTRO_ZONE="work"
    mock_dasel_value "zones.work.features.sdp" "true"
    mock_dasel_value "zones.work.sdp.base_url" "https://sdp.example.com/api/v3"
    unset SDP_API_KEY
    run "$SCRIPTS_DIR/sdp-fetch.sh" "12345"
    assert_failure
    assert_output --partial "SDP_API_KEY"
}

@test "sdp-fetch.sh strips SDP- prefix" {
    export MAESTRO_ZONE="work"
    export SDP_API_KEY="test-key"
    mock_dasel_value "zones.work.features.sdp" "true"
    mock_dasel_value "zones.work.sdp.base_url" "https://sdp.example.com/api/v3"

    run "$SCRIPTS_DIR/sdp-fetch.sh" "SDP-12345"
    assert_success

    # Verify curl was called without SDP- prefix
    run cat "${BATS_TEST_TMPDIR}/curl.calls"
    assert_output --partial "requests/12345"
}

@test "sdp-fetch.sh accepts plain number" {
    export MAESTRO_ZONE="work"
    export SDP_API_KEY="test-key"
    mock_dasel_value "zones.work.features.sdp" "true"
    mock_dasel_value "zones.work.sdp.base_url" "https://sdp.example.com/api/v3"

    run "$SCRIPTS_DIR/sdp-fetch.sh" "12345"
    assert_success
}

@test "sdp-fetch.sh handles authentication error" {
    export MAESTRO_ZONE="work"
    export SDP_API_KEY="invalid-key"
    mock_dasel_value "zones.work.features.sdp" "true"
    mock_dasel_value "zones.work.sdp.base_url" "https://sdp.example.com/api/v3"
    mock_curl_response "${FIXTURES_DIR}/api_responses/sdp/request-error-4001.json"

    run "$SCRIPTS_DIR/sdp-fetch.sh" "12345"
    assert_failure
    assert_output --partial "Authentication failed"
}

@test "sdp-fetch.sh handles not found error" {
    export MAESTRO_ZONE="work"
    export SDP_API_KEY="test-key"
    mock_dasel_value "zones.work.features.sdp" "true"
    mock_dasel_value "zones.work.sdp.base_url" "https://sdp.example.com/api/v3"
    mock_curl_response "${FIXTURES_DIR}/api_responses/sdp/request-error-4000.json"

    run "$SCRIPTS_DIR/sdp-fetch.sh" "99999"
    assert_failure
    assert_output --partial "not found"
}

@test "sdp-fetch.sh fails when SDP not enabled for zone" {
    export MAESTRO_ZONE="personal"
    export SDP_API_KEY="test-key"
    mock_dasel_value "zones.personal.features.sdp" "false"

    run "$SCRIPTS_DIR/sdp-fetch.sh" "12345"
    assert_failure
    assert_output --partial "SDP is not enabled"
}

# ============================================
# LINEAR FETCH
# ============================================

@test "linear-fetch.sh requires issue identifier" {
    run "$SCRIPTS_DIR/linear-fetch.sh"
    assert_failure
    assert_output --partial "Usage:"
}

@test "linear-fetch.sh fails without LINEAR_API_KEY" {
    unset LINEAR_API_KEY
    run "$SCRIPTS_DIR/linear-fetch.sh" "LIN-123"
    assert_failure
    assert_output --partial "LINEAR_API_KEY"
}

@test "linear-fetch.sh makes GraphQL API call" {
    export LINEAR_API_KEY="test-key"

    run "$SCRIPTS_DIR/linear-fetch.sh" "LIN-123"
    assert_success

    # Verify curl was called with Linear API
    run cat "${BATS_TEST_TMPDIR}/curl.calls"
    assert_output --partial "linear"
}
