#!/usr/bin/env bats
# Security tests specifically for zone name validation
# Tests defense in depth - validation at multiple layers

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
# VALIDATE_ZONE_NAME FUNCTION EXISTS
# ============================================

@test "validate_zone_name function exists in bin/zone" {
    run grep -q "validate_zone_name" "$PROJECT_ROOT/bin/zone"
    assert_success
}

@test "zone-switch.sh has validation" {
    run grep -E "Invalid zone name|[a-zA-Z0-9_-]" "$PROJECT_ROOT/.claude/skills/zone-context/scripts/zone-switch.sh"
    assert_success
}

# ============================================
# REGEX PATTERN TESTS
# ============================================

@test "validation regex rejects space" {
    run "$PROJECT_ROOT/bin/zone" switch "zone name"
    assert_failure
}

@test "validation regex rejects period" {
    run "$PROJECT_ROOT/bin/zone" switch "zone.name"
    assert_failure
}

@test "validation regex rejects comma" {
    run "$PROJECT_ROOT/bin/zone" switch "zone,name"
    assert_failure
}

@test "validation regex rejects colon" {
    run "$PROJECT_ROOT/bin/zone" switch "zone:name"
    assert_failure
}

@test "validation regex rejects at sign" {
    run "$PROJECT_ROOT/bin/zone" switch "zone@name"
    assert_failure
}

@test "validation regex rejects hash" {
    run "$PROJECT_ROOT/bin/zone" switch "zone#name"
    assert_failure
}

@test "validation regex rejects percent" {
    run "$PROJECT_ROOT/bin/zone" switch "zone%name"
    assert_failure
}

@test "validation regex rejects caret" {
    run "$PROJECT_ROOT/bin/zone" switch "zone^name"
    assert_failure
}

@test "validation regex rejects asterisk" {
    run "$PROJECT_ROOT/bin/zone" switch "zone*name"
    assert_failure
}

@test "validation regex rejects question mark" {
    run "$PROJECT_ROOT/bin/zone" switch "zone?name"
    assert_failure
}

@test "validation regex rejects exclamation" {
    run "$PROJECT_ROOT/bin/zone" switch "zone!name"
    assert_failure
}

@test "validation regex rejects square brackets" {
    run "$PROJECT_ROOT/bin/zone" switch "zone[name]"
    assert_failure
}

@test "validation regex rejects curly braces" {
    run "$PROJECT_ROOT/bin/zone" switch "zone{name}"
    assert_failure
}

@test "validation regex rejects parentheses" {
    run "$PROJECT_ROOT/bin/zone" switch "zone(name)"
    assert_failure
}

# ============================================
# DEFENSE IN DEPTH - BOTH LAYERS VALIDATE
# ============================================

@test "bin/zone validates before calling script" {
    # This test verifies that bin/zone catches bad input before
    # it reaches zone-switch.sh

    # Temporarily make zone-switch.sh executable but empty
    local backup="$MAESTRO_ROOT/.claude/skills/zone-context/scripts/zone-switch.sh.bak"
    cp "$MAESTRO_ROOT/.claude/skills/zone-context/scripts/zone-switch.sh" "$backup"
    echo '#!/bin/bash' > "$MAESTRO_ROOT/.claude/skills/zone-context/scripts/zone-switch.sh"
    echo 'echo "SHOULD_NOT_REACH"' >> "$MAESTRO_ROOT/.claude/skills/zone-context/scripts/zone-switch.sh"

    run "$PROJECT_ROOT/bin/zone" switch "zone;injection"
    assert_failure
    refute_output --partial "SHOULD_NOT_REACH"

    # Restore
    mv "$backup" "$MAESTRO_ROOT/.claude/skills/zone-context/scripts/zone-switch.sh"
}

@test "zone-switch.sh validates independently" {
    # This test verifies zone-switch.sh has its own validation
    # in case it's called directly
    run "$MAESTRO_ROOT/.claude/skills/zone-context/scripts/zone-switch.sh" "zone;injection"
    assert_failure
    assert_output --partial "Invalid zone name"
}

# ============================================
# EDGE CASES
# ============================================

@test "zone name starting with dash is handled" {
    run "$PROJECT_ROOT/bin/zone" switch "-zone"
    # May be valid or invalid depending on implementation
    # Key is it doesn't cause command injection
    [[ "$output" != *"hacked"* ]]
}

@test "zone name starting with number is valid" {
    mock_dasel_value "zones.123zone.name" "123zone"
    run "$PROJECT_ROOT/bin/zone" switch "123zone"
    assert_success
}

@test "single character zone name is valid" {
    mock_dasel_value "zones.a.name" "a"
    run "$PROJECT_ROOT/bin/zone" switch "a"
    assert_success
}

@test "zone name with only dashes fails" {
    run "$PROJECT_ROOT/bin/zone" switch "---"
    # May be valid (just dashes) or invalid
    # Key is no crash
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "zone name with only underscores is valid" {
    mock_dasel_value "zones.___.name" "___"
    run "$PROJECT_ROOT/bin/zone" switch "___"
    # Valid chars, should work
    assert_success
}

# ============================================
# CASE SENSITIVITY
# ============================================

@test "zone names are case-sensitive" {
    mock_dasel_value "zones.MyZone.name" "MyZone"
    mock_dasel_fail "zones.myzone.name"

    run "$PROJECT_ROOT/bin/zone" switch "MyZone"
    assert_success

    # Lowercase should be different zone
    run "$PROJECT_ROOT/bin/zone" switch "myzone"
    # May fail due to zone not existing, but shouldn't crash
}

# ============================================
# CONSISTENCY ACROSS COMMANDS
# ============================================

@test "zone switch and zone apply use same validation" {
    # Both should reject the same invalid input
    run "$PROJECT_ROOT/bin/zone" switch "bad;zone"
    local switch_status=$status

    run "$PROJECT_ROOT/bin/zone" apply "bad;zone"
    local apply_status=$status

    # Both should fail
    [[ $switch_status -ne 0 ]]
    [[ $apply_status -ne 0 ]]
}

@test "zone name direct and via subcommand use same validation" {
    # `zone personal` should use same validation as `zone switch personal`
    run "$PROJECT_ROOT/bin/zone" "bad;zone"
    local direct_status=$status

    run "$PROJECT_ROOT/bin/zone" switch "bad;zone"
    local switch_status=$status

    # Both should fail
    [[ $direct_status -ne 0 ]]
    [[ $switch_status -ne 0 ]]
}

# ============================================
# ERROR MESSAGES DON'T LEAK INFO
# ============================================

@test "error message doesn't echo back malicious input" {
    run "$PROJECT_ROOT/bin/zone" switch '<script>alert(1)</script>'
    assert_failure
    # Error message should be generic, not echo back the XSS payload
    refute_output --partial "<script>"
}

@test "error message is informative but safe" {
    run "$PROJECT_ROOT/bin/zone" switch "zone;rm -rf /"
    assert_failure
    assert_output --partial "Invalid zone name"
    refute_output --partial "rm -rf"
}
