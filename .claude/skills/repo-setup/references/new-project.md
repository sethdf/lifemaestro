# Creating Standalone Projects

## Overview

Standalone projects are independent repositories (not session repos) for larger efforts that don't fit the session model.

## Creation Flow

### 1. Select Zone

```bash
# Ask user or detect from current directory
zone="acme-corp"
```

### 2. Get GitHub Configuration

```bash
github_user=$(dasel ... zones.$zone.github.username)
ssh_host=$(dasel ... zones.$zone.github.ssh_host)
```

### 3. Create Project Directory

```bash
project_name="api-gateway"
project_dir="${HOME}/projects/${project_name}"
```

### 4. Create GitHub Repository

```bash
# Create repo on GitHub and clone
gh repo create "${project_name}" --private --clone

# Move to projects directory
mv "${project_name}" "${project_dir}"
cd "${project_dir}"
```

### 5. Configure Git Remote

```bash
# Update remote to use zone's SSH host
git remote set-url origin "git@${ssh_host}:${github_user}/${project_name}.git"
```

### 6. Set Git Identity

```bash
git config user.name "$(dasel ... zones.$zone.git.user)"
git config user.email "$(dasel ... zones.$zone.git.email)"
```

### 7. Create Initial CLAUDE.md

Generate from exploration template with zone rules:

```markdown
# {{NAME}}

**Date:** {{DATE}}
**Zone:** {{CC_CONTEXT}}
**Engineer:** {{CC_ENGINEER}}

## Goal

{{GOAL}}

## Rules

{{RULES}}

## Progress

<!-- Document progress here -->
```

### 8. Initial Commit

```bash
git add CLAUDE.md
git commit -m "feat: initialize project with CLAUDE.md"
git push -u origin main
```

## Result

Project is ready at `~/projects/<name>` with:
- GitHub repo under zone's account
- Correct SSH configuration for the zone
- CLAUDE.md with zone-appropriate rules
- Ready for `claude` command
