#!/usr/bin/env bash
# Additional test helper functions

# Assert exit code matches expected value
assert_exit_code() {
    local expected="$1"
    assert_equal "$status" "$expected" "Expected exit code $expected, got $status"
}

# Assert output contains all provided patterns
assert_output_contains_all() {
    for pattern in "$@"; do
        assert_output --partial "$pattern"
    done
}

# Set mock response for curl
mock_curl_response() {
    local response_file="$1"
    export MOCK_CURL_RESPONSE="$response_file"
}

# Set mock config value for dasel
mock_dasel_value() {
    local key="$1"
    local value="$2"
    local mock_file="${BATS_TEST_TMPDIR}/mock_dasel_${key//\./_}"
    mkdir -p "$(dirname "$mock_file")"
    echo "$value" > "$mock_file"
}

# Set mock to make dasel fail for a key
mock_dasel_fail() {
    local key="$1"
    local mock_file="${BATS_TEST_TMPDIR}/mock_dasel_${key//\./_}"
    mkdir -p "$(dirname "$mock_file")"
    echo "__MOCK_FAIL__" > "$mock_file"
}

# Reset all mocks
reset_mocks() {
    unset MOCK_CURL_RESPONSE
    unset MOCK_GIT_RESPONSE
    rm -f "${BATS_TEST_TMPDIR}"/mock_* 2>/dev/null || true
}

# Get mock call log for a command
get_mock_calls() {
    local cmd="$1"
    local log_file="${BATS_TEST_TMPDIR}/${cmd}.calls"
    if [[ -f "$log_file" ]]; then
        cat "$log_file"
    fi
}

# Assert a mock was called with specific args
assert_mock_called_with() {
    local cmd="$1"
    shift
    local pattern="$*"
    local calls
    calls=$(get_mock_calls "$cmd")
    if [[ "$calls" != *"$pattern"* ]]; then
        fail "Expected $cmd to be called with '$pattern', got: $calls"
    fi
}

# Create a temporary file with content
create_temp_file() {
    local content="$1"
    local filename="${2:-temp_file}"
    local filepath="${BATS_TEST_TMPDIR}/${filename}"
    echo "$content" > "$filepath"
    echo "$filepath"
}

# Skip test if command not available (for real integration tests)
skip_if_missing() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        skip "$cmd not available"
    fi
}
