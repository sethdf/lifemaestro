# Git Configuration for Zones

## Per-Repository Configuration

When working in a zone, configure git identity for the current repository:

```bash
# Get zone settings
zone=$(~/.config/lifemaestro/.claude/skills/zone-context/tools/zone-detect.sh | grep "^zone:" | cut -d' ' -f2)

# Apply git config from zone (requires dasel)
git_user=$(dasel -f ~/.config/lifemaestro/config.toml -r toml "zones.$zone.git.user")
git_email=$(dasel -f ~/.config/lifemaestro/config.toml -r toml "zones.$zone.git.email")

git config user.name "$git_user"
git config user.email "$git_email"
```

## Global Git Configuration with Conditional Includes

For automatic zone detection based on directory, add to `~/.gitconfig`:

```ini
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work

[includeIf "gitdir:~/personal/"]
    path = ~/.gitconfig-personal
```

Then create zone-specific configs:

**~/.gitconfig-work**:
```ini
[user]
    name = Your Work Name
    email = you@company.com
```

**~/.gitconfig-personal**:
```ini
[user]
    name = Your Name
    email = you@personal.com
```

## SSH Configuration for Multiple GitHub Accounts

In `~/.ssh/config`:

```
Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes

Host github.com-home
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
```

## Verifying Configuration

```bash
# Check current git identity
git config user.name
git config user.email

# Check remote URL uses correct SSH host
git remote -v

# Test SSH connection
ssh -T git@github.com-work
ssh -T git@github.com-home
```
