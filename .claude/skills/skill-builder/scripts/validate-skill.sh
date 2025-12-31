#!/usr/bin/env bash
# validate-skill.sh - Validate a skill against agentskills.io specification
# Usage: validate-skill.sh <path/to/skill>

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}!${NC} $*"; WARNINGS=$((WARNINGS + 1)); }
info() { echo -e "${BLUE}▶${NC} $*"; }

ERRORS=0
WARNINGS=0

usage() {
    cat <<EOF
validate-skill.sh - Validate a skill against agentskills.io spec

Usage: validate-skill.sh <path/to/skill>

Checks:
  - SKILL.md exists and has valid frontmatter
  - name field: lowercase, hyphens, max 64 chars, matches directory
  - description field: 50-1024 chars, contains trigger information
  - SKILL.md body: under 500 lines
  - Referenced files exist
  - No prohibited files (README.md, CHANGELOG.md, etc.)

Exit codes:
  0 - All checks passed
  1 - Validation errors found
  2 - Usage error
EOF
}

# Extract YAML frontmatter field
get_frontmatter_field() {
    local file="$1"
    local field="$2"

    # Extract content between --- markers, then get field
    sed -n '/^---$/,/^---$/p' "$file" | grep -E "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//"
}

# Get multiline frontmatter field (for description with |)
get_multiline_field() {
    local file="$1"
    local field="$2"

    awk -v field="$field" '
        /^---$/ { in_front = !in_front; next }
        in_front && $0 ~ "^"field":" {
            if ($0 ~ /\|[[:space:]]*$/) {
                # Multiline - read until next field or end
                while ((getline line) > 0) {
                    if (line ~ /^[a-z-]+:/ || line ~ /^---$/) break
                    gsub(/^[[:space:]]+/, "", line)
                    printf "%s ", line
                }
            } else {
                # Single line
                sub("^"field":[[:space:]]*", "")
                print
            }
            exit
        }
    ' "$file"
}

# Count lines in SKILL.md body (after frontmatter)
count_body_lines() {
    local file="$1"
    awk '
        /^---$/ { front++; next }
        front >= 2 { count++ }
        END { print count + 0 }
    ' "$file"
}

# Main validation
validate_skill() {
    local skill_path="$1"

    # Normalize path
    skill_path="${skill_path%/}"

    local skill_dir
    skill_dir=$(basename "$skill_path")
    local skill_md="$skill_path/SKILL.md"

    echo -e "${BOLD}Validating skill: ${BLUE}$skill_dir${NC}"
    echo -e "${DIM}Path: $skill_path${NC}"
    echo ""

    # ==========================================
    # Check 1: SKILL.md exists
    # ==========================================
    if [[ ! -f "$skill_md" ]]; then
        fail "SKILL.md not found"
        echo ""
        echo -e "${RED}Cannot continue validation without SKILL.md${NC}"
        return 1
    fi
    pass "SKILL.md exists"

    # ==========================================
    # Check 2: Frontmatter exists
    # ==========================================
    if ! head -1 "$skill_md" | grep -q "^---$"; then
        fail "Missing YAML frontmatter (must start with ---)"
        return 1
    fi

    if ! sed -n '2,$p' "$skill_md" | grep -q "^---$"; then
        fail "Frontmatter not closed (missing second ---)"
        return 1
    fi
    pass "Valid YAML frontmatter structure"

    # ==========================================
    # Check 3: name field
    # ==========================================
    local name
    name=$(get_frontmatter_field "$skill_md" "name")

    if [[ -z "$name" ]]; then
        fail "Missing 'name' field in frontmatter"
    else
        # Check format: lowercase, alphanumeric, hyphens
        if [[ ! "$name" =~ ^[a-z][a-z0-9-]*[a-z0-9]$|^[a-z]$ ]]; then
            fail "name '$name' invalid (must be lowercase, alphanumeric, hyphens, not start/end with hyphen)"
        elif [[ ${#name} -gt 64 ]]; then
            fail "name '$name' too long (${#name} chars, max 64)"
        elif [[ "$name" != "$skill_dir" ]]; then
            fail "name '$name' doesn't match directory '$skill_dir'"
        else
            pass "name: '$name' (valid)"
        fi
    fi

    # ==========================================
    # Check 4: description field
    # ==========================================
    local description
    description=$(get_multiline_field "$skill_md" "description")

    if [[ -z "$description" ]]; then
        fail "Missing 'description' field in frontmatter"
    else
        local desc_len=${#description}

        if [[ $desc_len -lt 50 ]]; then
            fail "description too short ($desc_len chars, min 50)"
        elif [[ $desc_len -gt 1024 ]]; then
            fail "description too long ($desc_len chars, max 1024)"
        else
            pass "description: $desc_len chars (valid length)"
        fi

        # Check for trigger words
        local has_trigger=false
        if echo "$description" | grep -qiE "(use when|trigger|use this|invoke when|use for)"; then
            has_trigger=true
        fi

        if [[ "$has_trigger" == "true" ]]; then
            pass "description contains trigger information"
        else
            warn "description may lack trigger info (consider: 'Use when...', 'Triggers:')"
        fi
    fi

    # ==========================================
    # Check 5: No extra frontmatter fields
    # ==========================================
    local extra_fields
    extra_fields=$(sed -n '/^---$/,/^---$/p' "$skill_md" | grep -E "^[a-z-]+:" | grep -vE "^(name|description|license|compatibility|metadata|allowed-tools):" | head -5 || true)

    if [[ -n "$extra_fields" ]]; then
        warn "Non-standard frontmatter fields (Anthropic recommends only name/description):"
        echo "$extra_fields" | while read -r line; do
            echo -e "  ${DIM}$line${NC}"
        done
    fi

    # ==========================================
    # Check 6: Body length
    # ==========================================
    local body_lines
    body_lines=$(count_body_lines "$skill_md")

    if [[ $body_lines -gt 500 ]]; then
        fail "SKILL.md body too long ($body_lines lines, max 500)"
    elif [[ $body_lines -gt 400 ]]; then
        warn "SKILL.md body approaching limit ($body_lines/500 lines)"
    else
        pass "SKILL.md body: $body_lines lines (under 500)"
    fi

    # ==========================================
    # Check 7: Referenced files exist
    # ==========================================
    local refs
    refs=$(grep -oE '\[.*\]\((references/[^)]+|scripts/[^)]+|assets/[^)]+)\)' "$skill_md" 2>/dev/null | grep -oE '(references|scripts|assets)/[^)]+' || true)

    if [[ -n "$refs" ]]; then
        local missing=0
        while IFS= read -r ref; do
            if [[ ! -e "$skill_path/$ref" ]]; then
                fail "Referenced file not found: $ref"
                missing=$((missing + 1))
            fi
        done <<< "$refs"

        if [[ $missing -eq 0 ]]; then
            pass "All referenced files exist"
        fi
    fi

    # ==========================================
    # Check 8: No prohibited files
    # ==========================================
    local prohibited=("README.md" "INSTALLATION_GUIDE.md" "QUICK_REFERENCE.md" "CHANGELOG.md" "CONTRIBUTING.md")
    local found_prohibited=()

    for file in "${prohibited[@]}"; do
        if [[ -f "$skill_path/$file" ]]; then
            found_prohibited+=("$file")
        fi
    done

    if [[ ${#found_prohibited[@]} -gt 0 ]]; then
        warn "Prohibited files found (skills shouldn't have auxiliary docs):"
        for file in "${found_prohibited[@]}"; do
            echo -e "  ${DIM}$file${NC}"
        done
    else
        pass "No prohibited auxiliary files"
    fi

    # ==========================================
    # Check 9: Directory structure
    # ==========================================
    local has_scripts=false
    local has_references=false
    local has_assets=false

    [[ -d "$skill_path/scripts" ]] && has_scripts=true
    [[ -d "$skill_path/references" ]] && has_references=true
    [[ -d "$skill_path/assets" ]] && has_assets=true

    echo ""
    echo -e "${BOLD}Structure:${NC}"
    echo -e "  SKILL.md       ✓"
    [[ "$has_scripts" == "true" ]] && echo -e "  scripts/       ✓" || echo -e "  scripts/       ${DIM}(none)${NC}"
    [[ "$has_references" == "true" ]] && echo -e "  references/    ✓" || echo -e "  references/    ${DIM}(none)${NC}"
    [[ "$has_assets" == "true" ]] && echo -e "  assets/        ✓" || echo -e "  assets/        ${DIM}(none)${NC}"

    # ==========================================
    # Summary
    # ==========================================
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}PASSED${NC} - Skill is valid"
    elif [[ $ERRORS -eq 0 ]]; then
        echo -e "${YELLOW}${BOLD}PASSED WITH WARNINGS${NC} - $WARNINGS warning(s)"
    else
        echo -e "${RED}${BOLD}FAILED${NC} - $ERRORS error(s), $WARNINGS warning(s)"
    fi
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    return $ERRORS
}

# Main
if [[ $# -lt 1 ]]; then
    usage
    exit 2
fi

case "${1:-}" in
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        validate_skill "$1"
        exit $?
        ;;
esac
