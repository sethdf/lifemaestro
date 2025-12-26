# Setting Up Session Repositories

## Overview

Each zone needs category repositories where sessions are stored. These are git repos hosted on GitHub.

## Repository Structure

```
GitHub Account (zone-specific):
├── work-tickets          # Ticket-based sessions
├── work-explorations     # Open-ended work investigations
├── explorations          # Personal explorations
└── learning              # Learning/tutorial sessions
```

## Setup Steps

### 1. Switch to Zone Context

```bash
eval "$(zone-switch.sh <zone>)"
```

This sets:
- `MAESTRO_ZONE` environment variable
- `AWS_PROFILE` for the zone
- Git identity (applied per-repo)

### 2. Get Zone GitHub Configuration

From config.toml:
```toml
[zones.acme-corp.github]
ssh_host = "github.com-work"
username = "your-work-username"
```

### 3. Create Session Directory Structure

```bash
mkdir -p ~/ai-sessions/<zone>
```

### 4. For Each Category Repository

```bash
repo_name="tickets"  # or explorations, learning
github_user="your-username"
ssh_host="github.com-work"
repo_path="~/ai-sessions/<zone>/$repo_name"

# Check if repo exists on GitHub
if gh repo view "${github_user}/${repo_name}" &>/dev/null; then
    # Clone existing
    git clone "git@${ssh_host}:${github_user}/${repo_name}.git" "$repo_path"
else
    # Create new
    mkdir -p "$repo_path"
    cd "$repo_path"
    git init
    echo "# ${repo_name}" > README.md
    echo "Claude Code session repository" >> README.md
    git add README.md
    git commit -m "Initial commit"

    # Create on GitHub
    gh repo create "${github_user}/${repo_name}" --private --source=. --remote=origin --push

    # Fix remote to use SSH host alias
    git remote set-url origin "git@${ssh_host}:${github_user}/${repo_name}.git"
fi
```

### 5. Configure Git Identity Per-Repo

```bash
cd "$repo_path"
git config user.name "$(dasel ... zones.$zone.git.user)"
git config user.email "$(dasel ... zones.$zone.git.email)"
```

## Verification

After setup, verify:
```bash
# Check directory structure
ls -la ~/ai-sessions/<zone>/

# Check git remotes use correct SSH host
cd ~/ai-sessions/<zone>/tickets
git remote -v
# Should show: git@github.com-work:username/tickets.git

# Check git identity
git config user.email
# Should show zone email
```
