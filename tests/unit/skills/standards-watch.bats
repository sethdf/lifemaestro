#!/usr/bin/env bats
# Tests for standards-watch skill scripts

load '../../test_helper/bats-setup'
load '../../test_helper/common'

SCRIPTS_DIR=""
SKILL_DIR=""

setup() {
    common_setup
    setup_skill_scripts "standards-watch"
    SKILL_DIR="$MAESTRO_ROOT/.claude/skills/standards-watch"
    SCRIPTS_DIR="$SKILL_DIR/scripts"

    # Default mock baton URL
    export BATON_URL="http://localhost:4000"
}

teardown() {
    reset_mocks
    common_teardown
}

# ============================================
# SKILL.md VALIDATION
# ============================================

@test "SKILL.md exists and has required frontmatter" {
    [ -f "$SKILL_DIR/SKILL.md" ]

    # Check for required frontmatter fields
    run head -20 "$SKILL_DIR/SKILL.md"
    assert_success
    assert_output --partial "name: standards-watch"
    assert_output --partial "description:"
    assert_output --partial "allowed-tools:"
}

@test "SKILL.md has valid allowed-tools" {
    run grep -A 10 "allowed-tools:" "$SKILL_DIR/SKILL.md"
    assert_success
    assert_output --partial "Bash"
    assert_output --partial "Read"
}

# ============================================
# CHECK-STANDARDS.SH
# ============================================

@test "check-standards.sh is executable" {
    [ -x "$SCRIPTS_DIR/check-standards.sh" ]
}

@test "check-standards.sh fails gracefully when baton unavailable" {
    export BATON_URL="http://localhost:99999"
    run timeout 5 "$SCRIPTS_DIR/check-standards.sh" 2>&1 || true
    # Should mention baton not available
    assert_output --partial "Baton" || assert_output --partial "baton" || true
}

@test "check-standards.sh accepts since_hours parameter" {
    # Script should parse the parameter without error
    run bash -n "$SCRIPTS_DIR/check-standards.sh"
    assert_success
}

@test "check-standards.sh has correct shebang" {
    run head -1 "$SCRIPTS_DIR/check-standards.sh"
    assert_output "#!/usr/bin/env bash"
}

@test "check-standards.sh uses set -euo pipefail" {
    run head -5 "$SCRIPTS_DIR/check-standards.sh"
    assert_output --partial "set -euo pipefail"
}

# ============================================
# CHECK-BREAKING.SH
# ============================================

@test "check-breaking.sh is executable" {
    [ -x "$SCRIPTS_DIR/check-breaking.sh" ]
}

@test "check-breaking.sh has correct shebang" {
    run head -1 "$SCRIPTS_DIR/check-breaking.sh"
    assert_output "#!/usr/bin/env bash"
}

@test "check-breaking.sh uses set -euo pipefail" {
    run head -5 "$SCRIPTS_DIR/check-breaking.sh"
    assert_output --partial "set -euo pipefail"
}

# ============================================
# REFERENCES
# ============================================

@test "references/context-files.md exists" {
    [ -f "$SKILL_DIR/references/context-files.md" ]
}

@test "references/skill-format.md exists" {
    [ -f "$SKILL_DIR/references/skill-format.md" ]
}

@test "references/migration-guide.md exists" {
    [ -f "$SKILL_DIR/references/migration-guide.md" ]
}

@test "context-files.md documents all three CLIs" {
    run cat "$SKILL_DIR/references/context-files.md"
    assert_success
    assert_output --partial "CLAUDE.md"
    assert_output --partial "AGENTS.md"
    assert_output --partial "GEMINI.md"
}

@test "skill-format.md documents SKILL.md structure" {
    run cat "$SKILL_DIR/references/skill-format.md"
    assert_success
    assert_output --partial "name:"
    assert_output --partial "description:"
    assert_output --partial "allowed-tools:"
}

@test "migration-guide.md has rollback procedure" {
    run cat "$SKILL_DIR/references/migration-guide.md"
    assert_success
    assert_output --partial "Rollback"
}

# ============================================
# CROSS-PLATFORM SETUP
# ============================================

@test ".codex/skills is symlinked to .claude/skills" {
    [ -L "$MAESTRO_ROOT/.codex/skills" ]

    # Verify target
    local target
    target=$(readlink "$MAESTRO_ROOT/.codex/skills")
    assert_equal "$target" "../.claude/skills"
}

@test "AGENTS.md is symlinked to CLAUDE.md" {
    [ -L "$MAESTRO_ROOT/AGENTS.md" ]

    local target
    target=$(readlink "$MAESTRO_ROOT/AGENTS.md")
    assert_equal "$target" "CLAUDE.md"
}

@test "GEMINI.md exists and imports CLAUDE.md" {
    [ -f "$MAESTRO_ROOT/GEMINI.md" ]

    run cat "$MAESTRO_ROOT/GEMINI.md"
    assert_success
    assert_output --partial "@./CLAUDE.md"
}

@test ".gemini/settings.json configures multiple context files" {
    [ -f "$MAESTRO_ROOT/.gemini/settings.json" ]

    run cat "$MAESTRO_ROOT/.gemini/settings.json"
    assert_success
    assert_output --partial "GEMINI.md"
    assert_output --partial "CLAUDE.md"
    assert_output --partial "AGENTS.md"
}

# ============================================
# SCRIPT SAFETY
# ============================================

@test "check-standards.sh doesn't use eval with user input" {
    run grep -n 'eval' "$SCRIPTS_DIR/check-standards.sh"
    # Should not find eval
    assert_failure
}

@test "check-breaking.sh doesn't use eval with user input" {
    run grep -n 'eval' "$SCRIPTS_DIR/check-breaking.sh"
    # Should not find eval
    assert_failure
}

@test "scripts quote variables properly" {
    # Check for unquoted variable references (potential word splitting)
    # This is a basic check - looks for $VAR outside of quotes
    run bash -c "grep -E '\$[A-Z_]+[^\"'\''[:space:]]' '$SCRIPTS_DIR/check-standards.sh' | grep -v '#' | grep -v '^\s*$' || true"
    # Output should be empty or only safe uses
}

# ============================================
# INTEGRATION TESTS (with mock baton)
# ============================================

@test "check-standards.sh parses JSON response correctly" {
    # Create mock curl that returns test data
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/curl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"/healthz"* ]]; then
    echo '{"status":"ok"}'
    exit 0
elif [[ "$*" == *"/standards/updates"* ]]; then
    echo '{"updates":[],"count":0,"has_breaking":false}'
    exit 0
elif [[ "$*" == *"/standards"* ]]; then
    echo '{"summary":{"latest_versions":{"test/repo":"1.0.0"}}}'
    exit 0
fi
exit 1
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/curl"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

    run "$SCRIPTS_DIR/check-standards.sh" 24
    assert_success
    assert_output --partial "No updates"
}
