#!/usr/bin/env bash
# setup-session-repos.sh - Set up session repositories for a zone
set -euo pipefail

MAESTRO_ROOT="${MAESTRO_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/lifemaestro}"
MAESTRO_CONFIG="${MAESTRO_CONFIG:-$MAESTRO_ROOT/config.toml}"

zone="${1:-}"

if [[ -z "$zone" ]]; then
    echo "Usage: setup-session-repos.sh <zone>" >&2
    exit 1
fi

# Get zone configuration
if ! command -v dasel &>/dev/null; then
    echo "Error: dasel required for configuration parsing" >&2
    exit 1
fi

if [[ ! -f "$MAESTRO_CONFIG" ]]; then
    echo "Error: Config not found at $MAESTRO_CONFIG" >&2
    exit 1
fi

# Verify zone exists
zone_name=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.name" 2>/dev/null || echo "")
if [[ -z "$zone_name" ]]; then
    echo "Error: Zone '$zone' not found in config" >&2
    exit 1
fi

# Get GitHub configuration
github_user=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.github.username" 2>/dev/null || echo "")
ssh_host=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.github.ssh_host" 2>/dev/null || echo "github.com")
git_user=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.git.user" 2>/dev/null || echo "$USER")
git_email=$(dasel -f "$MAESTRO_CONFIG" -r toml "zones.$zone.git.email" 2>/dev/null || echo "")

if [[ -z "$github_user" ]]; then
    echo "Error: GitHub username not configured for zone '$zone'" >&2
    exit 1
fi

# Get sessions base directory
sessions_base="${HOME}/ai-sessions"
sessions_base_config=$(dasel -f "$MAESTRO_CONFIG" -r toml 'sessions.base_dir' 2>/dev/null || echo "")
if [[ -n "$sessions_base_config" ]]; then
    sessions_base="${sessions_base_config/#\~/$HOME}"
fi

# Get repos for this zone
repos=$(dasel -f "$MAESTRO_CONFIG" -r toml "sessions.repos.$zone" -w json 2>/dev/null | jq -r 'to_entries[] | "\(.key)=\(.value)"')

if [[ -z "$repos" ]]; then
    echo "Error: No repositories configured for zone '$zone'" >&2
    echo "Configure in config.toml: sessions.repos.$zone.<category> = \"org/repo-name\"" >&2
    exit 1
fi

# Create zone directory
zone_dir="${sessions_base}/${zone}"
mkdir -p "$zone_dir"

echo "Setting up session repositories for zone: $zone"
echo "GitHub User: $github_user"
echo "SSH Host: $ssh_host"
echo "Base Directory: $zone_dir"
echo ""

# Process each repo
echo "$repos" | while IFS='=' read -r category repo_full; do
    repo_name="${repo_full##*/}"
    repo_path="${zone_dir}/${repo_name}"

    echo "[$category] $repo_full"

    if [[ -d "$repo_path/.git" ]]; then
        echo "  Already exists: $repo_path"
        continue
    fi

    # Check if repo exists on GitHub
    if gh repo view "$repo_full" &>/dev/null; then
        echo "  Cloning existing repo..."
        git clone "git@${ssh_host}:${repo_full}.git" "$repo_path"
    else
        echo "  Creating new repo..."
        mkdir -p "$repo_path"
        cd "$repo_path"
        git init

        # Create README
        cat > README.md << EOF
# ${repo_name}

Claude Code session repository for ${category} in ${zone} zone.

## Structure

Sessions are organized by date:
\`\`\`
YYYY-MM-DD-session-name/
├── CLAUDE.md
└── ...
\`\`\`

## Usage

Create sessions using LifeMaestro:
\`\`\`bash
session-create.sh ${zone} ${category} my-session "Session objective"
\`\`\`
EOF

        git add README.md
        git commit -m "Initial commit"

        # Create on GitHub
        gh repo create "$repo_full" --private --source=. --remote=origin --push

        # Fix remote URL
        git remote set-url origin "git@${ssh_host}:${repo_full}.git"
    fi

    # Configure git identity
    cd "$repo_path"
    git config user.name "$git_user"
    git config user.email "$git_email"

    echo "  Done: $repo_path"
done

echo ""
echo "Setup complete!"
echo "Session repos for zone '$zone' are ready at: $zone_dir"
