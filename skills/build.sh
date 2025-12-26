#!/usr/bin/env bash
# skills/build.sh - Build vendor-specific skills from universal source
# Usage: skills/build.sh [--vendor <claude|codex|gemini>] [--list] [--validate] [skill-name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
DIST_DIR="$SCRIPT_DIR/dist"
MAESTRO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ============================================
# METADATA PARSING
# ============================================

# Parse metadata from blockquote in skill.md
parse_metadata() {
    local skill_file="$1"
    local field="$2"

    # Extract blockquote lines, find field, get value
    # Blockquote may start after title line
    awk -v field="$field" '
        /^>/ {
            in_blockquote = 1
            line = $0
            sub(/^> */, "", line)
            regex = "^\\*\\*" field "\\*\\*:"
            if (line ~ regex) {
                sub(/^\*\*[^*]+\*\*: */, "", line)
                print line
                exit
            }
            next
        }
        in_blockquote && /^[^>]/ { exit }
    ' "$skill_file"
}

# Extract skill name from directory or metadata
get_skill_name() {
    local skill_dir="$1"
    basename "$skill_dir"
}

# ============================================
# VALIDATION
# ============================================

validate_skill() {
    local skill_dir="$1"
    local skill_file="$skill_dir/skill.md"
    local errors=0

    if [[ ! -f "$skill_file" ]]; then
        error "Missing skill.md in $skill_dir"
        return 1
    fi

    # Check required metadata
    local purpose use_when triggers
    purpose=$(parse_metadata "$skill_file" "Purpose")
    use_when=$(parse_metadata "$skill_file" "Use when")
    triggers=$(parse_metadata "$skill_file" "Triggers")

    [[ -z "$purpose" ]] && { error "Missing Purpose in metadata"; ((errors++)); }
    [[ -z "$use_when" ]] && { error "Missing 'Use when' in metadata"; ((errors++)); }
    [[ -z "$triggers" ]] && { error "Missing Triggers in metadata"; ((errors++)); }

    # Check @ref markers point to existing files
    # Only check markers outside of code blocks (lines not starting with spaces or backticks)
    while IFS= read -r ref; do
        # Skip generic examples like @ref:name
        [[ "$ref" == "name" || "$ref" == "topic-name" || "$ref" == "x" ]] && continue
        local ref_file="$skill_dir/refs/${ref}.md"
        if [[ ! -f "$ref_file" ]]; then
            error "Reference not found: refs/${ref}.md (referenced as @ref:${ref})"
            ((errors++))
        fi
    done < <(grep -v '^\s' "$skill_file" | grep -v '^```' | grep -oP '@ref:\K[a-z0-9-]+' 2>/dev/null || true)

    # Check @script markers point to existing files
    while IFS= read -r script; do
        # Skip generic examples
        [[ "$script" == "name.sh" || "$script" == "do-x.sh" ]] && continue
        local script_file="$skill_dir/scripts/${script}"
        if [[ ! -f "$script_file" ]]; then
            error "Script not found: scripts/${script}"
            ((errors++))
        fi
    done < <(grep -v '^\s' "$skill_file" | grep -v '^```' | grep -oP '@script:\K[a-z0-9-]+\.sh' 2>/dev/null || true)

    [[ $errors -eq 0 ]] && return 0 || return 1
}

# ============================================
# BUILD FOR CLAUDE CODE
# ============================================

build_claude() {
    local skill_dir="$1"
    local skill_name
    skill_name=$(get_skill_name "$skill_dir")
    local skill_file="$skill_dir/skill.md"
    local out_dir="$DIST_DIR/claude/$skill_name"

    info "Building Claude: $skill_name"

    # Create output structure
    rm -rf "$out_dir"
    mkdir -p "$out_dir"/{references,scripts,assets}

    # Parse metadata
    local purpose use_when triggers
    purpose=$(parse_metadata "$skill_file" "Purpose")
    use_when=$(parse_metadata "$skill_file" "Use when")
    triggers=$(parse_metadata "$skill_file" "Triggers")

    # Build description for YAML frontmatter
    local description="$purpose
Use when: $use_when
Triggers: $triggers"

    # Extract title from first H1
    local title
    title=$(grep -m1 '^# ' "$skill_file" | sed 's/^# //')

    # Transform skill.md to SKILL.md with YAML frontmatter
    {
        echo "---"
        echo "name: $skill_name"
        echo "description: |"
        echo "$description" | sed 's/^/  /'
        echo "---"
        echo ""

        # Process body: skip metadata blockquote, transform @ref and @script markers
        awk '
            BEGIN { in_meta = 1 }
            /^>/ && in_meta { next }
            /^[^>]/ && in_meta { in_meta = 0 }
            !in_meta {
                # Transform @ref:name to references/name.md
                while (match($0, /@ref:[a-z0-9-]+/)) {
                    ref = substr($0, RSTART+5, RLENGTH-5)
                    $0 = substr($0, 1, RSTART-1) "`references/" ref ".md`" substr($0, RSTART+RLENGTH)
                }
                # Transform @script:name.sh to scripts/name.sh
                while (match($0, /@script:[a-z0-9-]+\.sh/)) {
                    script = substr($0, RSTART+8, RLENGTH-8)
                    $0 = substr($0, 1, RSTART-1) "`scripts/" script "`" substr($0, RSTART+RLENGTH)
                }
                print
            }
        ' "$skill_file"
    } > "$out_dir/SKILL.md"

    # Copy refs/ to references/
    if [[ -d "$skill_dir/refs" ]]; then
        cp -r "$skill_dir/refs"/* "$out_dir/references/" 2>/dev/null || true
    fi

    # Copy scripts/
    if [[ -d "$skill_dir/scripts" ]]; then
        cp -r "$skill_dir/scripts"/* "$out_dir/scripts/" 2>/dev/null || true
        chmod +x "$out_dir/scripts"/*.sh 2>/dev/null || true
    fi

    # Copy assets/
    if [[ -d "$skill_dir/assets" ]]; then
        cp -r "$skill_dir/assets"/* "$out_dir/assets/" 2>/dev/null || true
    fi

    # Clean up empty directories
    rmdir "$out_dir/references" 2>/dev/null || true
    rmdir "$out_dir/scripts" 2>/dev/null || true
    rmdir "$out_dir/assets" 2>/dev/null || true

    ok "Claude: $skill_name → dist/claude/$skill_name/"
}

# ============================================
# BUILD FOR CODEX CLI
# ============================================

build_codex() {
    local skill_dir="$1"
    local skill_name
    skill_name=$(get_skill_name "$skill_dir")
    local skill_file="$skill_dir/skill.md"
    local out_file="$DIST_DIR/codex/$skill_name.md"

    info "Building Codex: $skill_name"

    mkdir -p "$DIST_DIR/codex"

    # Parse metadata
    local purpose use_when triggers
    purpose=$(parse_metadata "$skill_file" "Purpose")
    use_when=$(parse_metadata "$skill_file" "Use when")
    triggers=$(parse_metadata "$skill_file" "Triggers")

    # Extract title
    local title
    title=$(grep -m1 '^# ' "$skill_file" | sed 's/^# //')

    {
        echo "<!-- SKILL: $skill_name -->"
        echo "## $title"
        echo ""
        echo "**Purpose**: $purpose"
        echo "**Use when**: $use_when"
        echo "**Triggers**: $triggers"
        echo ""

        # Process body: skip metadata, inline references and scripts
        awk -v skill_dir="$skill_dir" '
            BEGIN { in_meta = 1 }
            /^>/ && in_meta { next }
            /^[^>]/ && in_meta { in_meta = 0 }
            !in_meta {
                # Check for @ref markers and inline content
                if (match($0, /@ref:([a-z0-9-]+)/)) {
                    ref_name = substr($0, RSTART+5, RLENGTH-5)
                    ref_file = skill_dir "/refs/" ref_name ".md"

                    # Print line with marker replaced by header
                    gsub(/@ref:[a-z0-9-]+/, "")
                    if ($0 !~ /^[[:space:]]*$/) print

                    # Inline the reference content
                    print ""
                    print "#### " ref_name
                    print ""
                    while ((getline line < ref_file) > 0) {
                        # Skip H1 headers in inlined content
                        if (line !~ /^# /) print line
                    }
                    close(ref_file)
                    print ""
                }
                # Check for @script markers and inline content
                else if (match($0, /@script:([a-z0-9-]+\.sh)/)) {
                    script_name = substr($0, RSTART+8, RLENGTH-8)
                    script_file = skill_dir "/scripts/" script_name

                    # Print line with marker replaced
                    gsub(/@script:[a-z0-9-]+\.sh/, "`" script_name "`")
                    print

                    # Inline the script
                    print ""
                    print "```bash"
                    while ((getline line < script_file) > 0) {
                        print line
                    }
                    close(script_file)
                    print "```"
                    print ""
                }
                else {
                    print
                }
            }
        ' "$skill_file"

        echo "<!-- END SKILL: $skill_name -->"
    } > "$out_file"

    ok "Codex: $skill_name → dist/codex/$skill_name.md"
}

# ============================================
# BUILD FOR GEMINI CLI
# ============================================

build_gemini() {
    local skill_dir="$1"
    local skill_name
    skill_name=$(get_skill_name "$skill_dir")
    local skill_file="$skill_dir/skill.md"
    local out_file="$DIST_DIR/gemini/$skill_name.md"

    info "Building Gemini: $skill_name"

    mkdir -p "$DIST_DIR/gemini"

    # Parse metadata
    local purpose use_when triggers
    purpose=$(parse_metadata "$skill_file" "Purpose")
    use_when=$(parse_metadata "$skill_file" "Use when")
    triggers=$(parse_metadata "$skill_file" "Triggers")

    # Extract title
    local title
    title=$(grep -m1 '^# ' "$skill_file" | sed 's/^# //')

    {
        echo "## $title"
        echo ""
        echo "**Purpose**: $purpose"
        echo "**Use when**: $use_when"
        echo "**Triggers**: $triggers"
        echo ""

        # Process body: skip metadata, use @import for refs, inline scripts
        awk -v skill_dir="$skill_dir" '
            BEGIN { in_meta = 1 }
            /^>/ && in_meta { next }
            /^[^>]/ && in_meta { in_meta = 0 }
            !in_meta {
                # Transform @ref to @import syntax
                if (match($0, /@ref:([a-z0-9-]+)/)) {
                    ref_name = substr($0, RSTART+5, RLENGTH-5)
                    gsub(/@ref:[a-z0-9-]+/, "@" ref_name ".md")
                    print
                }
                # Inline scripts (Gemini doesnt have script execution)
                else if (match($0, /@script:([a-z0-9-]+\.sh)/)) {
                    script_name = substr($0, RSTART+8, RLENGTH-8)
                    script_file = skill_dir "/scripts/" script_name

                    gsub(/@script:[a-z0-9-]+\.sh/, "")
                    if ($0 !~ /^[[:space:]]*$/) print

                    print ""
                    print "```bash"
                    while ((getline line < script_file) > 0) {
                        print line
                    }
                    close(script_file)
                    print "```"
                    print ""
                }
                else {
                    print
                }
            }
        ' "$skill_file"
    } > "$out_file"

    # Also copy refs for @import to work
    if [[ -d "$skill_dir/refs" ]]; then
        cp -r "$skill_dir/refs"/* "$DIST_DIR/gemini/" 2>/dev/null || true
    fi

    ok "Gemini: $skill_name → dist/gemini/$skill_name.md"
}

# ============================================
# LINK TO VENDOR LOCATIONS
# ============================================

link_claude_skills() {
    local claude_skills_dir="$MAESTRO_ROOT/.claude/skills"

    info "Linking Claude skills..."

    for skill_dir in "$DIST_DIR/claude"/*/; do
        if [[ -d "$skill_dir" ]]; then
            local skill_name
            skill_name=$(basename "$skill_dir")
            local link_path="$claude_skills_dir/$skill_name"

            # Remove existing (could be symlink or directory)
            rm -rf "$link_path"

            # Create symlink
            ln -sf "../../skills/dist/claude/$skill_name" "$link_path"
        fi
    done

    ok "Claude skills linked to .claude/skills/"
}

# ============================================
# MAIN
# ============================================

list_skills() {
    echo "Available skills in src/:"
    echo ""
    for skill_dir in "$SRC_DIR"/*/; do
        if [[ -d "$skill_dir" ]]; then
            local name
            name=$(basename "$skill_dir")
            local purpose
            purpose=$(parse_metadata "$skill_dir/skill.md" "Purpose" 2>/dev/null || echo "(no description)")
            printf "  %-20s %s\n" "$name" "${purpose:0:50}"
        fi
    done
}

build_skill() {
    local skill_name="$1"
    local vendor="${2:-all}"
    local skill_dir="$SRC_DIR/$skill_name"

    if [[ ! -d "$skill_dir" ]]; then
        error "Skill not found: $skill_name"
        return 1
    fi

    if ! validate_skill "$skill_dir"; then
        error "Validation failed for $skill_name"
        return 1
    fi

    case "$vendor" in
        claude)
            build_claude "$skill_dir"
            ;;
        codex)
            build_codex "$skill_dir"
            ;;
        gemini)
            build_gemini "$skill_dir"
            ;;
        all)
            build_claude "$skill_dir"
            build_codex "$skill_dir"
            build_gemini "$skill_dir"
            ;;
    esac
}

build_all() {
    local vendor="${1:-all}"

    for skill_dir in "$SRC_DIR"/*/; do
        if [[ -d "$skill_dir" ]]; then
            local skill_name
            skill_name=$(basename "$skill_dir")
            build_skill "$skill_name" "$vendor" || warn "Failed: $skill_name"
        fi
    done

    # Link Claude skills
    if [[ "$vendor" == "all" || "$vendor" == "claude" ]]; then
        link_claude_skills
    fi

    ok "Build complete"
}

usage() {
    cat <<EOF
skills/build.sh - Build vendor-specific skills from universal source

Usage: skills/build.sh [options] [skill-name]

Options:
  --vendor <name>    Build for specific vendor (claude, codex, gemini)
  --list             List available skills
  --validate <name>  Validate skill without building
  --help             Show this help

Examples:
  skills/build.sh                      # Build all skills for all vendors
  skills/build.sh my-skill             # Build specific skill for all vendors
  skills/build.sh --vendor claude      # Build all skills for Claude only
  skills/build.sh --validate my-skill  # Validate skill format
EOF
}

main() {
    local vendor="all"
    local action="build"
    local skill_name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vendor)
                vendor="$2"
                shift 2
                ;;
            --list)
                action="list"
                shift
                ;;
            --validate)
                action="validate"
                skill_name="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                skill_name="$1"
                shift
                ;;
        esac
    done

    case "$action" in
        list)
            list_skills
            ;;
        validate)
            if [[ -z "$skill_name" ]]; then
                error "Specify skill to validate"
                exit 1
            fi
            if validate_skill "$SRC_DIR/$skill_name"; then
                ok "Validation passed: $skill_name"
            else
                exit 1
            fi
            ;;
        build)
            if [[ -n "$skill_name" ]]; then
                build_skill "$skill_name" "$vendor"
            else
                build_all "$vendor"
            fi
            ;;
    esac
}

main "$@"
