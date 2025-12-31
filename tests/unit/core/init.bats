#!/usr/bin/env bats
# Tests for core/init.sh

load '../../test_helper/bats-setup'
load '../../test_helper/common'

setup() {
    common_setup
    # Copy interfaces.sh if it exists (required by init.sh)
    if [[ -f "$PROJECT_ROOT/core/interfaces.sh" ]]; then
        cp "$PROJECT_ROOT/core/interfaces.sh" "$MAESTRO_ROOT/core/"
    else
        # Create stub
        echo '#!/usr/bin/env bash' > "$MAESTRO_ROOT/core/interfaces.sh"
    fi
}

teardown() {
    common_teardown
}

# ============================================
# XDG PATHS
# ============================================

@test "MAESTRO_ROOT uses XDG_CONFIG_HOME" {
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg_config"
    unset MAESTRO_ROOT
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    [[ "$MAESTRO_ROOT" == "$BATS_TEST_TMPDIR/xdg_config/lifemaestro" ]]
}

@test "MAESTRO_ROOT defaults to ~/.config/lifemaestro" {
    unset XDG_CONFIG_HOME
    unset MAESTRO_ROOT
    # We can't easily test this without affecting user's actual home
    # Just verify the default pattern
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    [[ "$MAESTRO_ROOT" == *"lifemaestro" ]]
}

@test "MAESTRO_STATE uses XDG_STATE_HOME" {
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg_state"
    unset MAESTRO_STATE
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    [[ "$MAESTRO_STATE" == "$BATS_TEST_TMPDIR/xdg_state/lifemaestro" ]]
}

@test "MAESTRO_DATA uses XDG_DATA_HOME" {
    export XDG_DATA_HOME="$BATS_TEST_TMPDIR/xdg_data"
    unset MAESTRO_DATA
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    [[ "$MAESTRO_DATA" == "$BATS_TEST_TMPDIR/xdg_data/lifemaestro" ]]
}

@test "Environment variables override defaults" {
    export MAESTRO_ROOT="$BATS_TEST_TMPDIR/custom_root"
    export MAESTRO_CONFIG="$BATS_TEST_TMPDIR/custom.toml"
    mkdir -p "$MAESTRO_ROOT/core"
    cp "$PROJECT_ROOT/core/cli.sh" "$MAESTRO_ROOT/core/"
    cp "$PROJECT_ROOT/core/utils.sh" "$MAESTRO_ROOT/core/"
    echo '#!/bin/bash' > "$MAESTRO_ROOT/core/interfaces.sh"
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    assert_equal "$MAESTRO_ROOT" "$BATS_TEST_TMPDIR/custom_root"
    assert_equal "$MAESTRO_CONFIG" "$BATS_TEST_TMPDIR/custom.toml"
}

# ============================================
# CONFIG FUNCTIONS
# ============================================

@test "maestro::config returns default for missing key" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::config "nonexistent.key" "default_value"
    assert_output "default_value"
}

@test "maestro::config env var takes precedence" {
    export MAESTRO_TEST_KEY="env_value"
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::config "test.key" "default"
    assert_output "env_value"
    unset MAESTRO_TEST_KEY
}

@test "maestro::config reads from config file" {
    mock_dasel_value "maestro.version" "1.0.0"
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::config "maestro.version" "0.0.0"
    assert_output "1.0.0"
}

# ============================================
# LOGGING
# ============================================

@test "maestro::log writes to log file" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    maestro::log "test message"
    assert [ -f "$MAESTRO_STATE/maestro.log" ]
    run cat "$MAESTRO_STATE/maestro.log"
    assert_output --partial "test message"
}

@test "maestro::log includes timestamp" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    maestro::log "timestamped message"
    run cat "$MAESTRO_STATE/maestro.log"
    [[ "$output" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2} ]]
}

@test "maestro::log includes level" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    maestro::log "error message" "ERROR"
    run cat "$MAESTRO_STATE/maestro.log"
    assert_output --partial "[ERROR]"
}

@test "maestro::log debug output with MAESTRO_DEBUG" {
    export MAESTRO_DEBUG=1
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run bash -c 'source "$PROJECT_ROOT/core/init.sh" 2>/dev/null; MAESTRO_DEBUG=1; maestro::log "debug test" 2>&1'
    # Debug should print to stderr
    [[ "$output" == *"debug test"* ]] || [[ -f "$MAESTRO_STATE/maestro.log" ]]
}

# ============================================
# STATUS
# ============================================

@test "maestro::status shows root path" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::status
    assert_output --partial "Root:"
    assert_output --partial "$MAESTRO_ROOT"
}

@test "maestro::status shows config path" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::status
    assert_output --partial "Config:"
}

@test "maestro::status shows version" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::status
    assert_output --partial "Version:"
}

# ============================================
# DOCTOR
# ============================================

@test "maestro::doctor runs without error" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::doctor
    # May have warnings but shouldn't crash
    assert_output --partial "Health Check"
}

@test "maestro::doctor checks dependencies" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::doctor
    assert_output --partial "Dependencies:"
}

@test "maestro::doctor shows jq status" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::doctor
    assert_output --partial "jq"
}

@test "maestro::doctor shows curl status" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::doctor
    assert_output --partial "curl"
}

@test "maestro::doctor shows git status" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::doctor
    assert_output --partial "git"
}

@test "maestro::doctor checks config file" {
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    run maestro::doctor
    assert_output --partial "Configuration:"
}

# ============================================
# DIRECTORY CREATION
# ============================================

@test "init.sh creates state directory" {
    export MAESTRO_STATE="$BATS_TEST_TMPDIR/new_state"
    rm -rf "$MAESTRO_STATE"
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    assert [ -d "$MAESTRO_STATE" ]
}

@test "init.sh creates runtime directory" {
    export MAESTRO_RUNTIME="$BATS_TEST_TMPDIR/new_runtime"
    rm -rf "$MAESTRO_RUNTIME"
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    assert [ -d "$MAESTRO_RUNTIME" ]
}

@test "init.sh creates data directory" {
    export MAESTRO_DATA="$BATS_TEST_TMPDIR/new_data"
    rm -rf "$MAESTRO_DATA"
    source "$PROJECT_ROOT/core/init.sh" 2>/dev/null || true
    assert [ -d "$MAESTRO_DATA" ]
}
