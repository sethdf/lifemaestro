#!/usr/bin/env bats
# Tests for zone-context skill scripts

load '../../test_helper/bats-setup'
load '../../test_helper/common'

SCRIPTS_DIR=""

setup() {
    common_setup
    setup_skill_scripts "zone-context"
    SCRIPTS_DIR="$MAESTRO_ROOT/.claude/skills/zone-context/scripts"
}

teardown() {
    reset_mocks
    common_teardown
}

# ============================================
# ZONE DETECTION
# ============================================

@test "zone-detect.sh returns zone from MAESTRO_ZONE env" {
    export MAESTRO_ZONE="testzone"
    run "$SCRIPTS_DIR/zone-detect.sh"
    assert_success
    assert_output --partial "zone: testzone"
    assert_output --partial "source: environment"
}

@test "zone-detect.sh falls back to default zone" {
    unset MAESTRO_ZONE
    mock_dasel_value "zones.default.name" "personal"
    run "$SCRIPTS_DIR/zone-detect.sh"
    assert_success
    assert_output --partial "zone: personal"
}

@test "zone-detect.sh detects zone from directory path" {
    unset MAESTRO_ZONE
    # Mock directory detection pattern
    mock_dasel_value "zones.detection.patterns.work" "/work/*"
    cd "$BATS_TEST_TMPDIR"
    run "$SCRIPTS_DIR/zone-detect.sh"
    # Will use default if no match
    assert_success
}

# ============================================
# ZONE SWITCHING
# ============================================

@test "zone-switch.sh requires zone name argument" {
    run "$SCRIPTS_DIR/zone-switch.sh"
    assert_failure
    assert_output --partial "Usage:"
}

@test "zone-switch.sh validates zone name - rejects semicolon" {
    run "$SCRIPTS_DIR/zone-switch.sh" "zone;rm -rf /"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone-switch.sh validates zone name - rejects pipe" {
    run "$SCRIPTS_DIR/zone-switch.sh" "zone|cat /etc/passwd"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone-switch.sh validates zone name - rejects path traversal" {
    run "$SCRIPTS_DIR/zone-switch.sh" "../etc/passwd"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone-switch.sh validates zone name - rejects slash" {
    run "$SCRIPTS_DIR/zone-switch.sh" "zone/path"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone-switch.sh validates zone name - rejects backticks" {
    run "$SCRIPTS_DIR/zone-switch.sh" 'zone`whoami`'
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone-switch.sh validates zone name - rejects dollar" {
    run "$SCRIPTS_DIR/zone-switch.sh" 'zone$(id)'
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone-switch.sh accepts valid alphanumeric name" {
    mock_dasel_value "zones.work.name" "work"
    run "$SCRIPTS_DIR/zone-switch.sh" "work"
    assert_success
    assert_output --partial "export MAESTRO_ZONE='work'"
}

@test "zone-switch.sh accepts dashes in name" {
    mock_dasel_value "zones.my-zone.name" "my-zone"
    run "$SCRIPTS_DIR/zone-switch.sh" "my-zone"
    assert_success
}

@test "zone-switch.sh accepts underscores in name" {
    mock_dasel_value "zones.my_zone.name" "my_zone"
    run "$SCRIPTS_DIR/zone-switch.sh" "my_zone"
    assert_success
}

@test "zone-switch.sh accepts mixed case" {
    mock_dasel_value "zones.MyZone123.name" "MyZone123"
    run "$SCRIPTS_DIR/zone-switch.sh" "MyZone123"
    assert_success
}

@test "zone-switch.sh outputs eval instructions" {
    mock_dasel_value "zones.personal.name" "personal"
    run "$SCRIPTS_DIR/zone-switch.sh" "personal"
    assert_success
    assert_output --partial "eval"
}

@test "zone-switch.sh exports git config commands" {
    mock_dasel_value "zones.work.name" "work"
    mock_dasel_value "zones.work.git.user" "Work User"
    mock_dasel_value "zones.work.git.email" "work@example.com"
    run "$SCRIPTS_DIR/zone-switch.sh" "work"
    assert_success
    assert_output --partial "git config"
}

@test "zone-switch.sh exports AWS profile if configured" {
    mock_dasel_value "zones.work.name" "work"
    mock_dasel_value "zones.work.aws.profile" "company-sso"
    run "$SCRIPTS_DIR/zone-switch.sh" "work"
    assert_success
    assert_output --partial "AWS_PROFILE"
}

# ============================================
# ZONE LISTING
# ============================================

@test "zone-list.sh requires dasel" {
    # Remove dasel from path
    PATH="${PATH#*mocks:}"
    run "$SCRIPTS_DIR/zone-list.sh"
    assert_failure
    assert_output --partial "dasel required"
}

@test "zone-list.sh requires config file" {
    rm -f "$MAESTRO_CONFIG"
    run "$SCRIPTS_DIR/zone-list.sh"
    assert_failure
    assert_output --partial "Config not found"
}

@test "zone-list.sh lists configured zones" {
    run "$SCRIPTS_DIR/zone-list.sh"
    # Mock returns personal and work
    assert_success
    assert_output --partial "personal"
}
