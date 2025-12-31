#!/usr/bin/env bash
# Common BATS setup - source this in every test file

# Determine test helper directory
TEST_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load bats libraries
load "${TEST_HELPER_DIR}/bats-support/load"
load "${TEST_HELPER_DIR}/bats-assert/load"

# Project root (two levels up from test_helper)
export PROJECT_ROOT="${TEST_HELPER_DIR}/../.."

# Set up isolated test environment
export BATS_TEST_TMPDIR="${BATS_TMPDIR:-/tmp}/maestro-test-$$"
export MAESTRO_ROOT="${BATS_TEST_TMPDIR}/lifemaestro"
export MAESTRO_CONFIG="${MAESTRO_ROOT}/config.toml"
export MAESTRO_STATE="${BATS_TEST_TMPDIR}/state"
export MAESTRO_RUNTIME="${BATS_TEST_TMPDIR}/runtime"
export MAESTRO_DATA="${BATS_TEST_TMPDIR}/data"

# Add mocks to PATH (higher priority than real commands)
export PATH="${TEST_HELPER_DIR}/mocks:${PATH}"

# Disable colors for predictable output
export NO_COLOR=1

# Fixtures directory
export FIXTURES_DIR="${TEST_HELPER_DIR}/../fixtures"

# Create test directories
setup_test_dirs() {
    mkdir -p "$MAESTRO_ROOT"
    mkdir -p "$MAESTRO_STATE"
    mkdir -p "$MAESTRO_RUNTIME"
    mkdir -p "$MAESTRO_DATA"
    mkdir -p "$MAESTRO_ROOT/core"
    mkdir -p "$MAESTRO_ROOT/.claude/skills"
}

# Copy core modules to test environment
setup_core_modules() {
    if [[ -d "$PROJECT_ROOT/core" ]]; then
        cp -r "$PROJECT_ROOT/core"/* "$MAESTRO_ROOT/core/"
    fi
}

# Copy skill scripts to test environment
setup_skill_scripts() {
    local skill="$1"
    if [[ -d "$PROJECT_ROOT/.claude/skills/$skill" ]]; then
        mkdir -p "$MAESTRO_ROOT/.claude/skills/$skill"
        cp -r "$PROJECT_ROOT/.claude/skills/$skill"/* "$MAESTRO_ROOT/.claude/skills/$skill/"
    fi
}

# Install a test config file
install_config() {
    local fixture="${1:-config.toml}"
    if [[ -f "${FIXTURES_DIR}/config/${fixture}" ]]; then
        cp "${FIXTURES_DIR}/config/${fixture}" "$MAESTRO_CONFIG"
    fi
}

# Clean up after tests
teardown_test_dirs() {
    if [[ -d "$BATS_TEST_TMPDIR" ]]; then
        rm -rf "$BATS_TEST_TMPDIR"
    fi
}

# Standard setup for most tests
common_setup() {
    setup_test_dirs
    setup_core_modules
    install_config
}

# Standard teardown for most tests
common_teardown() {
    teardown_test_dirs
}
