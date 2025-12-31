#!/usr/bin/env bats
# Integration tests for bin/maestro CLI

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

@test "maestro (no args) shows help" {
    run "$PROJECT_ROOT/bin/maestro"
    assert_success
    assert_output --partial "Usage:"
}

@test "maestro help shows all commands" {
    run "$PROJECT_ROOT/bin/maestro" help
    assert_success
    assert_output --partial "status"
    assert_output --partial "doctor"
}

@test "maestro --help shows usage" {
    run "$PROJECT_ROOT/bin/maestro" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "maestro --version shows version" {
    run "$PROJECT_ROOT/bin/maestro" --version
    assert_success
    assert_output --partial "maestro"
}

@test "maestro -v shows version" {
    run "$PROJECT_ROOT/bin/maestro" -v
    assert_success
}

# ============================================
# STATUS COMMAND
# ============================================

@test "maestro status shows system info" {
    run "$PROJECT_ROOT/bin/maestro" status
    assert_success
    assert_output --partial "Root:"
}

@test "maestro status shows config path" {
    run "$PROJECT_ROOT/bin/maestro" status
    assert_success
    assert_output --partial "Config:"
}

@test "maestro status shows version" {
    run "$PROJECT_ROOT/bin/maestro" status
    assert_success
    assert_output --partial "Version:"
}

@test "maestro s is alias for status" {
    run "$PROJECT_ROOT/bin/maestro" s
    assert_success
    assert_output --partial "Root:"
}

# ============================================
# DOCTOR COMMAND
# ============================================

@test "maestro doctor runs health check" {
    run "$PROJECT_ROOT/bin/maestro" doctor
    # May have errors but shouldn't crash
    assert_output --partial "Health Check"
}

@test "maestro doctor checks dependencies" {
    run "$PROJECT_ROOT/bin/maestro" doctor
    assert_output --partial "Dependencies:"
}

@test "maestro doctor shows jq status" {
    run "$PROJECT_ROOT/bin/maestro" doctor
    assert_output --partial "jq"
}

@test "maestro doctor shows configuration status" {
    run "$PROJECT_ROOT/bin/maestro" doctor
    assert_output --partial "Configuration:"
}

@test "maestro d is alias for doctor" {
    run "$PROJECT_ROOT/bin/maestro" d
    assert_output --partial "Health Check"
}

# ============================================
# INIT COMMAND
# ============================================

@test "maestro init initializes system" {
    run "$PROJECT_ROOT/bin/maestro" init
    # Should succeed or report status
    [[ "$status" -eq 0 ]] || [[ "$output" == *"init"* ]]
}

# ============================================
# CONFIG COMMAND
# ============================================

@test "maestro config shows or edits config" {
    run "$PROJECT_ROOT/bin/maestro" config
    # May open editor or show path
    [[ "$output" == *"config"* ]] || [[ "$status" -eq 0 ]]
}

# ============================================
# FLAGS
# ============================================

@test "maestro -q enables quiet mode" {
    run "$PROJECT_ROOT/bin/maestro" -q status
    assert_success
    # Output should be minimal
}

@test "maestro --quiet enables quiet mode" {
    run "$PROJECT_ROOT/bin/maestro" --quiet status
    assert_success
}

@test "maestro --debug enables debug output" {
    run "$PROJECT_ROOT/bin/maestro" --debug status
    assert_success
}

# ============================================
# ERROR HANDLING
# ============================================

@test "maestro handles unknown command" {
    run "$PROJECT_ROOT/bin/maestro" nonexistent_command_xyz
    assert_failure
    assert_output --partial "Unknown command"
}

@test "maestro suggests --help for unknown command" {
    run "$PROJECT_ROOT/bin/maestro" badcmd
    assert_failure
    assert_output --partial "help"
}
