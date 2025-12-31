#!/usr/bin/env bash
# session-create.sh - Create a new Claude Code session
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

zone="${1:-}"
category="${2:-explorations}"
name="${3:-}"
objective="${4:-}"

if [[ -z "$zone" ]] || [[ -z "$name" ]]; then
    echo "Usage: session-create.sh <zone> <category> <name> [objective]" >&2
    echo "Categories: explorations, tickets, learning" >&2
    exit 1
fi

# Get sessions base directory
sessions_base="${HOME}/ai-sessions"
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    sessions_base=$(dasel -f "$MAESTRO_CONFIG" -r toml 'sessions.base_dir' 2>/dev/null || echo "$sessions_base")
    sessions_base="${sessions_base/#\~/$HOME}"
fi

# Get repo name for this zone/category
repo_name=""
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    repo_name=$(dasel -f "$MAESTRO_CONFIG" -r toml "sessions.repos.$zone.$category" 2>/dev/null || echo "")
fi

if [[ -z "$repo_name" ]]; then
    echo "Error: No repository configured for zone '$zone' category '$category'" >&2
    echo "Configure in config.toml: sessions.repos.$zone.$category = \"org/repo-name\"" >&2
    exit 1
fi

# Build paths
repo_path="${sessions_base}/${zone}/${repo_name##*/}"
date_prefix=$(date +%Y-%m-%d)
session_name="${date_prefix}-${name}"
session_dir="${repo_path}/${session_name}"

# Check if repo exists
if [[ ! -d "$repo_path/.git" ]]; then
    echo "Error: Repository not found at $repo_path" >&2
    echo "Run repo-setup to initialize: repo-setup.sh $zone $category" >&2
    exit 1
fi

# Check if session already exists
if [[ -d "$session_dir" ]]; then
    echo "Session already exists: $session_dir" >&2
    echo "path: $session_dir"
    exit 0
fi

# Switch zone context
eval "$("$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-switch.sh" "$zone")"

# Create session directory
mkdir -p "$session_dir"

# Get template
template_file="$MAESTRO_ROOT/templates/${category}.md"
if [[ ! -f "$template_file" ]]; then
    template_file="$MAESTRO_ROOT/templates/exploration.md"
fi

# Get zone rules
rules_file="$MAESTRO_ROOT/rules/base.md"
safety_level=""
if command -v dasel &>/dev/null && [[ -f "$MAESTRO_CONFIG" ]]; then
    safety_level=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.rules.safety" 2>/dev/null || echo "relaxed")
fi

rules=""
[[ -f "$rules_file" ]] && rules=$(cat "$rules_file")
[[ -f "$MAESTRO_ROOT/rules/safety-${safety_level}.md" ]] && rules+=$'\n\n'$(cat "$MAESTRO_ROOT/rules/safety-${safety_level}.md")

# Get user info
git_user=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.git.user" 2>/dev/null || echo "$USER")

# Generate CONTEXT.md (master context file for all clients)
if [[ -f "$template_file" ]]; then
    # Template-based generation
    sed -e "s|{{NAME}}|$name|g" \
        -e "s|{{OBJECTIVE}}|${objective:-Exploration}|g" \
        -e "s|{{DATE}}|$date_prefix|g" \
        -e "s|{{CC_ENGINEER}}|$git_user|g" \
        -e "s|{{CC_CONTEXT}}|$zone|g" \
        "$template_file" > "$session_dir/CONTEXT.md"

    # Append rules if placeholder exists
    if grep -q "{{RULES}}" "$session_dir/CONTEXT.md"; then
        sed -i "s|{{RULES}}|$rules|g" "$session_dir/CONTEXT.md"
    fi
else
    # Default CONTEXT.md
    cat > "$session_dir/CONTEXT.md" << EOF
# ${name}

**Date:** ${date_prefix}
**Zone:** ${zone}
**Engineer:** ${git_user}

## Objective

${objective:-Exploration and investigation.}

## Rules

${rules}

## Progress

<!-- Document progress here -->

EOF
fi

# Create symlinks for each AI client
# Claude Code uses CLAUDE.md, Gemini CLI uses GEMINI.md, etc.
cd "$session_dir"
ln -sf CONTEXT.md CLAUDE.md
ln -sf CONTEXT.md GEMINI.md
ln -sf CONTEXT.md AGENTS.md       # Codex CLI
ln -sf CONTEXT.md CONVENTIONS.md  # Aider
cd - > /dev/null

# Create transcripts directory for conversation logs
mkdir -p "$session_dir/transcripts"

# Initialize session metadata (.session.json)
created_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$session_dir/.session.json" << EOF
{
  "id": "$session_name",
  "created": "$created_timestamp",
  "closed": null,
  "status": "active",
  "zone": "$zone",
  "type": "$category",
  "tags": [],
  "category": null,
  "outcome": null,
  "learnings": [],
  "skills_used": [],
  "models_used": [],
  "clients_used": [],
  "primary_model": null,
  "primary_client": null,
  "summary": null
}
EOF

# Git operations
cd "$repo_path"
git add "$session_name"
git commit -m "feat: create session ${session_name}"
git push 2>/dev/null || echo "Warning: Could not push to remote" >&2

# Output result
echo "created: true"
echo "path: $session_dir"
echo "zone: $zone"
echo "category: $category"
echo "name: $session_name"
