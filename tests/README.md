# LifeMaestro Test Suite

BATS-based test suite for the LifeMaestro CLI project.

## Prerequisites

```bash
# Install bats-core
npm install -g bats

# Or via package manager
brew install bats-core  # macOS
apt install bats        # Ubuntu/Debian
```

## Quick Setup

```bash
# From project root
cd tests

# Install bats support libraries
git clone --depth 1 https://github.com/bats-core/bats-support test_helper/bats-support
git clone --depth 1 https://github.com/bats-core/bats-assert test_helper/bats-assert

# Or use the setup script
../bin/test --setup
```

## Running Tests

```bash
# Run all tests
bats tests/

# Run specific category
bats tests/unit/
bats tests/integration/
bats tests/security/

# Run specific test file
bats tests/unit/core/cli.bats

# Run tests matching pattern
bats -f "validates zone name" tests/

# Run with verbose output
bats --verbose-run tests/

# Run tests in parallel (faster)
bats -j 4 tests/
```

## Using bin/test

```bash
# Run all tests
bin/test

# Setup dependencies
bin/test --setup

# Run specific category
bin/test unit
bin/test integration
bin/test security

# Run with options
bin/test --parallel        # Run in parallel
bin/test --verbose         # Verbose output
bin/test -f "zone"         # Filter by name
```

## Test Structure

```
tests/
├── test_helper/
│   ├── bats-setup.bash     # Common setup, env vars, helpers
│   ├── common.bash         # Shared assertion helpers
│   ├── mocks/              # Mock commands
│   │   ├── dasel           # Mock TOML parser
│   │   ├── curl            # Mock HTTP client
│   │   ├── git             # Mock git operations
│   │   ├── jq              # Mock/passthrough JSON processor
│   │   ├── gh              # Mock GitHub CLI
│   │   └── fzf             # Mock interactive picker
│   ├── bats-support/       # bats-support library (git submodule)
│   └── bats-assert/        # bats-assert library (git submodule)
├── fixtures/
│   ├── config/             # Test configuration files
│   │   ├── config.toml
│   │   ├── config-minimal.toml
│   │   └── config-multizone.toml
│   └── api_responses/      # Mock API responses
│       ├── jira/
│       ├── sdp/
│       ├── github/
│       └── linear/
├── unit/
│   ├── core/               # Core module tests
│   │   ├── cli.bats
│   │   ├── utils.bats
│   │   └── init.bats
│   └── skills/             # Skill script tests
│       ├── zone-context.bats
│       ├── session-manager.bats
│       └── ticket-lookup.bats
├── integration/            # CLI binary tests
│   ├── zone.bats
│   ├── session.bats
│   ├── ticket.bats
│   ├── maestro.bats
│   └── skills.bats
└── security/               # Security-focused tests
    ├── input-validation.bats
    └── zone-validation.bats
```

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bats

load '../test_helper/bats-setup'
load '../test_helper/common'

setup() {
    common_setup
    # Additional setup...
}

teardown() {
    common_teardown
}

@test "description of what is being tested" {
    run some_command args
    assert_success
    assert_output --partial "expected output"
}
```

### Using Mocks

```bash
@test "test with mock API response" {
    # Set mock curl response
    mock_curl_response "${FIXTURES_DIR}/api_responses/jira/issue-success.json"

    run some_command_that_uses_curl
    assert_success
}

@test "test with mock config value" {
    # Set mock dasel value
    mock_dasel_value "zones.work.name" "work"

    run "$PROJECT_ROOT/bin/zone" switch work
    assert_success
}
```

### Common Assertions

```bash
# Exit status
assert_success          # Exit code 0
assert_failure          # Exit code non-zero
assert_failure 64       # Specific exit code

# Output
assert_output "exact"           # Exact match
assert_output --partial "text"  # Contains text
refute_output --partial "text"  # Does not contain
assert_line --index 0 "first"   # Specific line

# Files
assert [ -f "$file" ]   # File exists
assert [ -d "$dir" ]    # Directory exists
```

## Test Categories

### Unit Tests (`tests/unit/`)
Tests for individual functions and modules in isolation.
- Core modules: `cli.sh`, `utils.sh`, `init.sh`
- Skill scripts: zone detection, ticket fetching, session management

### Integration Tests (`tests/integration/`)
Tests for CLI binaries end-to-end.
- `bin/zone` - Zone management
- `bin/session` - Session management
- `bin/ticket` - Ticket lookup
- `bin/maestro` - System commands

### Security Tests (`tests/security/`)
Tests for input validation and security.
- Command injection prevention
- Path traversal prevention
- Defense in depth verification

## Mock System

Tests use mock commands in `test_helper/mocks/` that:
- Log all invocations to `$BATS_TEST_TMPDIR/<cmd>.calls`
- Return predefined or configurable responses
- Can be configured per-test with `mock_*` helpers

### Checking Mock Calls

```bash
@test "verify curl was called correctly" {
    run some_command

    # Check curl was called
    run cat "${BATS_TEST_TMPDIR}/curl.calls"
    assert_output --partial "expected_url"
}
```

## Debugging

```bash
# Print debug info during test
@test "debugging example" {
    echo "Debug: $some_var" >&3
    run command
    echo "Output: $output" >&3
}

# Run single test with debug output
bats --verbose-run tests/unit/core/cli.bats -f "specific test"
```

## CI Integration

```yaml
# GitHub Actions example
- name: Install bats
  run: npm install -g bats

- name: Setup test dependencies
  run: bin/test --setup

- name: Run tests
  run: bats tests/
```
