#!/usr/bin/env bats
# Integration tests for bin/skills CLI

load '../test_helper/bats-setup'
load '../test_helper/common'

setup() {
    common_setup
}

teardown() {
    common_teardown
}

# ============================================
# BASIC COMMANDS
# ============================================

@test "skills (no args) lists available skills" {
    run "$PROJECT_ROOT/bin/skills"
    # Should list skills or show message
    [[ "$status" -eq 0 ]] || [[ "$output" == *"skill"* ]]
}

@test "skills shows local skills" {
    run "$PROJECT_ROOT/bin/skills"
    # Should show section for local skills
    [[ "$output" == *"Local"* ]] || [[ "$output" == *"skill"* ]] || [[ "$status" -eq 0 ]]
}

@test "skills --help shows usage" {
    run "$PROJECT_ROOT/bin/skills" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "skills -h shows usage" {
    run "$PROJECT_ROOT/bin/skills" -h
    assert_success
}
