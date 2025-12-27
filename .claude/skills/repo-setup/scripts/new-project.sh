#!/usr/bin/env bash
# new-project.sh - Create a new standalone project repository
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

name="${1:-}"
zone="${2:-}"

if [[ -z "$name" ]]; then
    echo "Usage: new-project.sh <project-name> [zone]" >&2
    exit 1
fi

# Get zone if not specified
if [[ -z "$zone" ]]; then
    zone=$("$MAESTRO_ROOT/.claude/skills/zone-context/tools/zone-detect.sh" | grep "^zone:" | cut -d' ' -f2)
fi

# Get zone configuration
if ! command -v dasel &>/dev/null; then
    echo "Error: dasel required for configuration parsing" >&2
    exit 1
fi

github_user=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.github.username" 2>/dev/null || echo "")
ssh_host=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.github.ssh_host" 2>/dev/null || echo "github.com")
git_user=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.git.user" 2>/dev/null || echo "$USER")
git_email=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.git.email" 2>/dev/null || echo "")
safety_level=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.rules.safety" 2>/dev/null || echo "relaxed")

if [[ -z "$github_user" ]]; then
    echo "Error: GitHub username not configured for zone '$zone'" >&2
    exit 1
fi

project_dir="${HOME}/projects/${name}"

if [[ -d "$project_dir" ]]; then
    echo "Error: Project directory already exists: $project_dir" >&2
    exit 1
fi

echo "Creating project: $name"
echo "Zone: $zone"
echo "GitHub: ${github_user}/${name}"
echo ""

# Create GitHub repo and clone
echo "Creating GitHub repository..."
gh repo create "${name}" --private --clone

# Move to projects directory
mkdir -p "${HOME}/projects"
mv "${name}" "${project_dir}"
cd "${project_dir}"

# Update remote URL
git remote set-url origin "git@${ssh_host}:${github_user}/${name}.git"

# Configure git identity
git config user.name "$git_user"
git config user.email "$git_email"

# Get rules
rules=""
[[ -f "$MAESTRO_ROOT/rules/base.md" ]] && rules=$(cat "$MAESTRO_ROOT/rules/base.md")
[[ -f "$MAESTRO_ROOT/rules/safety-${safety_level}.md" ]] && rules+=$'\n\n'$(cat "$MAESTRO_ROOT/rules/safety-${safety_level}.md")

# Create CLAUDE.md
date_str=$(date +%Y-%m-%d)
cat > CLAUDE.md << EOF
# ${name}

**Date:** ${date_str}
**Zone:** ${zone}
**Engineer:** ${git_user}

## Goal

New project: ${name}

## Rules

${rules:-No specific rules configured.}

## Progress

<!-- Document progress here -->

EOF

# Initial commit
git add CLAUDE.md
git commit -m "feat: initialize project with CLAUDE.md"
git push -u origin main

echo ""
echo "Project created!"
echo "path: $project_dir"
echo "repo: git@${ssh_host}:${github_user}/${name}.git"
echo ""
echo "# Run: cd $project_dir && claude"
