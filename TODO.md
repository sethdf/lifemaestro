# LifeMaestro TODO

## High Impact Additions

- [ ] **Time/Context Tracking**
  - Auto-log time spent per session/zone
  - Track which skills get used most
  - Weekly summaries of AI-assisted work

- [ ] **Smart Session Templates**
  - Auto-detect project type (Node, Python, Go) and load relevant context
  - Pre-populate CLAUDE.md with project-specific rules from detected stack

- [ ] **Conversation Memory**
  - Store key decisions/learnings from sessions
  - `maestro recall "how did we handle auth?"` to search past sessions
  - Link related sessions together

## Medium Impact Improvements

- [ ] **Finish AI Provider Adapters**
  - Flesh out stubs in `adapters/ai/`
  - Add cost tracking per provider
  - Smart routing based on task complexity (haiku for simple, opus for complex)

- [ ] **Session Repository Auto-Creation**
  - `repo-setup` skill assumes repos are pre-created
  - Auto-provision GitHub repos on `session new`

- [ ] **Notification Integration**
  - Hook into system notifications for long-running tasks
  - Slack/Discord alerts when AI sessions complete

- [ ] **Dotfile Sync Across Zones**
  - Auto-switch `.gitconfig`, SSH keys, AWS credentials per zone
  - Currently partial—make more seamless

## Quality of Life

- [ ] **`maestro status` Dashboard**
  - Current zone
  - Active sessions
  - Credential health
  - Recent activity

- [ ] **Skill Marketplace/Discovery**
  - Browse community skills beyond PAI/Anthropic
  - `maestro skill search "kubernetes"`

- [ ] **Shell Completions**
  - Tab completion for `maestro`, `session`, `zone` commands
  - Fish/Zsh/Bash support

- [ ] **Test Suite**
  - BATS or shunit2 for shell scripts
  - Focus on zone switching and credential logic
