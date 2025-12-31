#!/usr/bin/env bats
# Integration tests for bin/zone CLI

load '../test_helper/bats-setup'
load '../test_helper/common'

setup() {
    common_setup
    setup_skill_scripts "zone-context"
}

teardown() {
    reset_mocks
    common_teardown
}

# ============================================
# BASIC COMMANDS
# ============================================

@test "zone (no args) shows current zone" {
    export MAESTRO_ZONE="testzone"
    run "$PROJECT_ROOT/bin/zone"
    assert_success
    assert_output --partial "testzone"
}

@test "zone current shows current zone" {
    export MAESTRO_ZONE="myzone"
    run "$PROJECT_ROOT/bin/zone" current
    assert_success
    assert_output --partial "myzone"
}

@test "zone list shows available zones" {
    run "$PROJECT_ROOT/bin/zone" list
    # May succeed or fail with "dasel required"
    [[ "$status" -eq 0 ]] || [[ "$output" == *"dasel"* ]] || [[ "$output" == *"Config"* ]]
}

@test "zone switch outputs eval commands" {
    mock_dasel_value "zones.work.name" "work"
    run "$PROJECT_ROOT/bin/zone" switch work
    assert_success
    assert_output --partial "MAESTRO_ZONE"
}

@test "zone switch shows usage hint" {
    mock_dasel_value "zones.work.name" "work"
    run "$PROJECT_ROOT/bin/zone" switch work
    assert_success
    assert_output --partial "eval"
}

# ============================================
# INPUT VALIDATION
# ============================================

@test "zone switch validates zone name" {
    run "$PROJECT_ROOT/bin/zone" switch "bad;name"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone switch rejects path traversal" {
    run "$PROJECT_ROOT/bin/zone" switch "../etc"
    assert_failure
    assert_output --partial "Invalid zone name"
}

@test "zone switch accepts valid names" {
    mock_dasel_value "zones.valid-zone_123.name" "valid-zone_123"
    run "$PROJECT_ROOT/bin/zone" switch "valid-zone_123"
    assert_success
}

# ============================================
# APPLY COMMAND
# ============================================

@test "zone apply fails from subshell" {
    run "$PROJECT_ROOT/bin/zone" apply personal
    assert_failure
    assert_output --partial "Cannot apply zone from subshell"
}

@test "zone apply shows eval alternative" {
    run "$PROJECT_ROOT/bin/zone" apply personal
    assert_failure
    assert_output --partial "eval"
}

# ============================================
# FLAGS
# ============================================

@test "zone --version shows version" {
    run "$PROJECT_ROOT/bin/zone" --version
    assert_success
    assert_output --partial "lifemaestro"
}

@test "zone -v shows version" {
    run "$PROJECT_ROOT/bin/zone" -v
    assert_success
    assert_output --partial "lifemaestro"
}

@test "zone --help shows usage" {
    run "$PROJECT_ROOT/bin/zone" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Commands:"
}

@test "zone -h shows usage" {
    run "$PROJECT_ROOT/bin/zone" -h
    assert_success
    assert_output --partial "Usage:"
}

@test "zone help shows usage" {
    run "$PROJECT_ROOT/bin/zone" help
    assert_success
    assert_output --partial "Usage:"
}

# ============================================
# SHORTHAND COMMANDS
# ============================================

@test "zone c is alias for current" {
    export MAESTRO_ZONE="aliaszone"
    run "$PROJECT_ROOT/bin/zone" c
    assert_success
    assert_output --partial "aliaszone"
}

@test "zone ls is alias for list" {
    run "$PROJECT_ROOT/bin/zone" ls
    [[ "$status" -eq 0 ]] || [[ "$output" == *"dasel"* ]]
}

@test "zone s is alias for switch" {
    mock_dasel_value "zones.work.name" "work"
    run "$PROJECT_ROOT/bin/zone" s work
    assert_success
}

# ============================================
# ZONE NAME AS ARGUMENT
# ============================================

@test "zone accepts zone name directly for switch" {
    mock_dasel_value "zones.personal.name" "personal"
    run "$PROJECT_ROOT/bin/zone" personal
    assert_success
    assert_output --partial "MAESTRO_ZONE"
}
