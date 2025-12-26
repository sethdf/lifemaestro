#!/usr/bin/env bash
# skills/scaffold.sh - Create new skill from templates
# Usage: scaffold.sh <skill-name> [--type cli|agent|both] [--description "..."]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAESTRO_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
scaffold.sh - Create new LifeMaestro skill

Usage: scaffold.sh <skill-name> [options]

Options:
    --type TYPE         Skill type: cli, agent, or both (default: both)
    --description DESC  Short description of the skill
    --trigger TRIGGER   When to activate (e.g., "user requests X")
    -h, --help          Show this help

Types:
    cli     - Bash skill only (bin/skill run <name>)
    agent   - Claude Code skill only (.claude/skills/)
    both    - Both CLI and agent skill (shared tools)

Examples:
    scaffold.sh ticket-tracker
    scaffold.sh api-tester --type cli --description "Test API endpoints"
    scaffold.sh code-review --type agent --trigger "code review requested"

Structure Created (--type both):
    .claude/skills/<name>/
    ├── SKILL.md
    ├── cookbook/
    │   └── <name>.md
    └── tools/
        └── <name>.sh
EOF
    exit 0
}

# Slugify a string
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-'
}

# Replace template variables
render_template() {
    local template="$1"
    local output="$2"
    local today
    today=$(date '+%Y-%m-%d')

    sed -e "s/{{SKILL_NAME}}/$SKILL_NAME/g" \
        -e "s/{{SKILL_SLUG}}/$SKILL_SLUG/g" \
        -e "s/{{SKILL_DESCRIPTION}}/$SKILL_DESCRIPTION/g" \
        -e "s/{{SKILL_TRIGGER}}/$SKILL_TRIGGER/g" \
        -e "s/{{SKILL_PURPOSE}}/$SKILL_PURPOSE/g" \
        -e "s/{{EXAMPLE_1}}/$EXAMPLE_1/g" \
        -e "s/{{EXAMPLE_2}}/$EXAMPLE_2/g" \
        -e "s/{{DATE}}/$today/g" \
        "$template" > "$output"
}

create_agent_skill() {
    local skill_dir="$MAESTRO_ROOT/.claude/skills/$SKILL_SLUG"

    log_info "Creating Claude Code skill: $skill_dir"

    mkdir -p "$skill_dir/cookbook"
    mkdir -p "$skill_dir/tools"

    # SKILL.md
    render_template "$TEMPLATES_DIR/SKILL.md.tmpl" "$skill_dir/SKILL.md"
    log_ok "Created SKILL.md"

    # Cookbook
    render_template "$TEMPLATES_DIR/cookbook.md.tmpl" "$skill_dir/cookbook/$SKILL_SLUG.md"
    log_ok "Created cookbook/$SKILL_SLUG.md"

    # Tool
    render_template "$TEMPLATES_DIR/tool.sh.tmpl" "$skill_dir/tools/$SKILL_SLUG.sh"
    chmod +x "$skill_dir/tools/$SKILL_SLUG.sh"
    log_ok "Created tools/$SKILL_SLUG.sh"

    echo ""
    log_ok "Agent skill created at: $skill_dir"
}

create_cli_skill() {
    local skills_file="$MAESTRO_ROOT/core/skills.sh"

    log_info "Adding CLI skill registration to: $skills_file"

    # Check if skill already exists
    if grep -q "skill::register \"$SKILL_SLUG\"" "$skills_file" 2>/dev/null; then
        log_warn "CLI skill '$SKILL_SLUG' already registered in skills.sh"
        return
    fi

    # Generate skill function
    local skill_func="_skill_${SKILL_SLUG//-/_}"

    cat >> "$skills_file" <<EOF

# ============================================
# SKILL: $SKILL_NAME
# ============================================

$skill_func() {
    local input="\${1:-}"
    [[ -z "\$input" ]] && { echo "Usage: skill $SKILL_SLUG <input>" >&2; return 1; }

    # TODO: Implement skill logic
    echo "$SKILL_NAME executed with: \$input"
}

skill::register "$SKILL_SLUG" "$skill_func" "light" "$SKILL_DESCRIPTION"
EOF

    log_ok "Added skill registration to skills.sh"
    echo ""
    log_ok "CLI skill registered: skill run $SKILL_SLUG <input>"
}

main() {
    local skill_name=""
    local skill_type="both"

    # Defaults for template variables
    SKILL_DESCRIPTION="A new LifeMaestro skill"
    SKILL_TRIGGER="this skill is needed"
    SKILL_PURPOSE="Provide functionality for the user"
    EXAMPLE_1="Do something with X"
    EXAMPLE_2="Process Y"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            --type)
                skill_type="$2"
                shift 2
                ;;
            --description)
                SKILL_DESCRIPTION="$2"
                shift 2
                ;;
            --trigger)
                SKILL_TRIGGER="$2"
                shift 2
                ;;
            --purpose)
                SKILL_PURPOSE="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                skill_name="$1"
                shift
                ;;
        esac
    done

    # Validate
    if [[ -z "$skill_name" ]]; then
        log_error "Skill name required"
        echo "Usage: scaffold.sh <skill-name> [options]"
        exit 1
    fi

    # Set skill variables
    SKILL_NAME="$skill_name"
    SKILL_SLUG=$(slugify "$skill_name")

    echo ""
    echo "Creating skill: $SKILL_NAME"
    echo "  Slug: $SKILL_SLUG"
    echo "  Type: $skill_type"
    echo "  Description: $SKILL_DESCRIPTION"
    echo ""

    case "$skill_type" in
        agent)
            create_agent_skill
            ;;
        cli)
            create_cli_skill
            ;;
        both)
            create_agent_skill
            create_cli_skill
            ;;
        *)
            log_error "Unknown type: $skill_type (use: cli, agent, or both)"
            exit 1
            ;;
    esac

    echo ""
    echo "Next steps:"
    echo "  1. Edit the generated files to implement your skill"
    echo "  2. Update SKILL.md with proper routing logic"
    echo "  3. Implement tool script logic"
    echo "  4. Test with: skill run $SKILL_SLUG <input>"
    echo ""
    echo "Files to edit:"
    if [[ "$skill_type" == "agent" || "$skill_type" == "both" ]]; then
        echo "  .claude/skills/$SKILL_SLUG/SKILL.md"
        echo "  .claude/skills/$SKILL_SLUG/cookbook/$SKILL_SLUG.md"
        echo "  .claude/skills/$SKILL_SLUG/tools/$SKILL_SLUG.sh"
    fi
    if [[ "$skill_type" == "cli" || "$skill_type" == "both" ]]; then
        echo "  core/skills.sh (skill function)"
    fi
}

main "$@"
