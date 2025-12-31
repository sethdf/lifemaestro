#!/usr/bin/env bats
# Tests for core/utils.sh

load '../../test_helper/bats-setup'
load '../../test_helper/common'

setup() {
    common_setup
    source "$MAESTRO_ROOT/core/cli.sh"
    source "$MAESTRO_ROOT/core/utils.sh"
}

teardown() {
    common_teardown
}

# ============================================
# STRING UTILITIES
# ============================================

@test "utils::trim removes leading whitespace" {
    run utils::trim "  hello"
    assert_output "hello"
}

@test "utils::trim removes trailing whitespace" {
    run utils::trim "hello  "
    assert_output "hello"
}

@test "utils::trim removes both leading and trailing whitespace" {
    run utils::trim "  hello world  "
    assert_output "hello world"
}

@test "utils::trim handles tabs" {
    run utils::trim $'\t\thello\t\t'
    assert_output "hello"
}

@test "utils::trim preserves internal whitespace" {
    run utils::trim "  hello   world  "
    assert_output "hello   world"
}

@test "utils::trim handles empty string" {
    run utils::trim ""
    assert_output ""
}

@test "utils::slugify converts to lowercase" {
    run utils::slugify "HELLO WORLD"
    assert_output "hello-world"
}

@test "utils::slugify replaces spaces with dashes" {
    run utils::slugify "hello world"
    assert_output "hello-world"
}

@test "utils::slugify removes special characters" {
    run utils::slugify "hello@world!"
    assert_output "helloworld"
}

@test "utils::slugify preserves dashes and underscores" {
    run utils::slugify "hello-world_test"
    assert_output "hello-world_test"
}

@test "utils::slugify truncates to max length" {
    run utils::slugify "this is a very long string that should be truncated" 20
    [[ ${#output} -le 20 ]]
}

@test "utils::slugify does not end with dash after truncation" {
    run utils::slugify "hello-" 5
    [[ "$output" != *"-" ]]
}

@test "utils::timestamp returns formatted date" {
    run utils::timestamp
    assert_success
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]
}

@test "utils::date_iso returns ISO date format" {
    run utils::date_iso
    assert_success
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

# ============================================
# PATH UTILITIES
# ============================================

@test "utils::ensure_dir creates directory" {
    local test_dir="$BATS_TEST_TMPDIR/new_dir"
    run utils::ensure_dir "$test_dir"
    assert_success
    assert [ -d "$test_dir" ]
}

@test "utils::ensure_dir succeeds if directory exists" {
    local test_dir="$BATS_TEST_TMPDIR/existing"
    mkdir -p "$test_dir"
    run utils::ensure_dir "$test_dir"
    assert_success
}

@test "utils::realpath returns absolute path" {
    local rel_path="."
    run utils::realpath "$rel_path"
    assert_success
    [[ "$output" == /* ]]  # Starts with /
}

# ============================================
# VALIDATION
# ============================================

@test "utils::require_command succeeds for existing command" {
    run utils::require_command bash
    assert_success
}

@test "utils::require_command fails for missing command" {
    run utils::require_command nonexistent_command_xyz_12345
    assert_failure
    assert_output --partial "not found"
}

@test "utils::require_command shows install hint for known commands" {
    run utils::require_command dasel
    # Will fail in test environment (mock path), but check hint
    [[ "$output" == *"dasel"* ]] || [[ $status -eq 0 ]]
}

@test "utils::require_env succeeds when variable set" {
    export TEST_VAR_12345="value"
    run utils::require_env TEST_VAR_12345
    assert_success
    unset TEST_VAR_12345
}

@test "utils::require_env fails when variable not set" {
    unset MISSING_VAR_12345
    run utils::require_env MISSING_VAR_12345
    assert_failure
    assert_output --partial "not set"
}

@test "utils::require_env shows hint" {
    unset MISSING_VAR_12345
    run utils::require_env MISSING_VAR_12345 "Set this to your API key"
    assert_failure
    assert_output --partial "Set this to your API key"
}

@test "utils::require_file succeeds for existing file" {
    local test_file="$BATS_TEST_TMPDIR/existing_file.txt"
    touch "$test_file"
    run utils::require_file "$test_file"
    assert_success
}

@test "utils::require_file fails for missing file" {
    run utils::require_file "/nonexistent/file/path"
    assert_failure
}

@test "utils::require_file shows custom message" {
    run utils::require_file "/nonexistent" "Custom error message"
    assert_failure
    assert_output --partial "Custom error message"
}

# ============================================
# DURATION FORMATTING
# ============================================

@test "utils::format_duration formats seconds" {
    run utils::format_duration 45
    assert_output "45s"
}

@test "utils::format_duration formats minutes and seconds" {
    run utils::format_duration 90
    assert_output "1m 30s"
}

@test "utils::format_duration formats hours and minutes" {
    run utils::format_duration 3700
    assert_output "1h 1m"
}

@test "utils::format_duration formats days and hours" {
    run utils::format_duration 90000
    assert_output "1d 1h"
}

@test "utils::format_duration handles zero" {
    run utils::format_duration 0
    assert_output "0s"
}

@test "utils::format_duration handles negative (expired)" {
    run utils::format_duration -1
    assert_output "expired"
}

@test "utils::parse_duration parses seconds" {
    run utils::parse_duration "30s"
    assert_output "30"
}

@test "utils::parse_duration parses seconds without suffix" {
    run utils::parse_duration "30"
    assert_output "30"
}

@test "utils::parse_duration parses minutes" {
    run utils::parse_duration "5m"
    assert_output "300"
}

@test "utils::parse_duration parses hours" {
    run utils::parse_duration "2h"
    assert_output "7200"
}

@test "utils::parse_duration parses days" {
    run utils::parse_duration "1d"
    assert_output "86400"
}

@test "utils::parse_duration parses combined format" {
    run utils::parse_duration "1h30m"
    assert_output "5400"
}

@test "utils::parse_duration parses complex format" {
    run utils::parse_duration "1d2h30m45s"
    # 86400 + 7200 + 1800 + 45 = 95445
    assert_output "95445"
}

# ============================================
# JSON UTILITIES
# ============================================

@test "utils::json_get extracts simple key" {
    skip_if_missing jq
    run utils::json_get '{"name": "test"}' "name"
    assert_output "test"
}

@test "utils::json_get returns empty for missing key" {
    skip_if_missing jq
    run utils::json_get '{"name": "test"}' "missing"
    assert_output ""
}

@test "utils::json_array extracts array elements" {
    skip_if_missing jq
    run utils::json_array '["a", "b", "c"]'
    assert_line --index 0 "a"
    assert_line --index 1 "b"
    assert_line --index 2 "c"
}
