# LifeMaestro

Personal AI Operating System for managing contexts, sessions, and skills across Claude Code, Codex CLI, and Gemini CLI.

## Core Principles

1. **Concise is key** - Context window is shared. Only add what Claude doesn't know.
2. **Description triggers skills** - SKILL.md body loads AFTER triggering.
3. **Progressive disclosure** - Route to references/, don't dump everything.

## Architecture

```
.claude/
├── skills/           # SKILL.md format (agentskills.io spec)
├── rules/            # Path-specific rules
└── settings.json     # Permissions and hooks

vendor/               # External dependencies (PAI, Anthropic skills)
```

## Zones

Flexible namespaces for different work contexts:

```toml
[zones.work]
git.user = "John Doe"
git.email = "john@company.com"
aws.profile = "company-sso"
features.jira = true

[zones.personal]
git.user = "johnd"
git.email = "john@personal.com"
features.github_issues = true
```

## Shared Tools Pattern

CLI and skills share the same scripts:

```
CLI: maestro ticket 12345
       └──▶ scripts/fetch.sh ◀──┐
                                 │
Agent: "fetch ticket 12345"     │
       └──▶ SKILL.md → refs ────┘
```

## Vendor Skills

```bash
vendor/sync.sh update    # Pull PAI + Anthropic skills
bin/skills               # List all available skills
```

Skills from vendors are symlinked into `.claude/skills/` with prefixes:
- `pai-*` - Personal AI Infrastructure
- `anthropic-*` - Official Anthropic examples

## Development Workflow

1. **Plan first** - What's the simplest working version?
2. **Start simple** - Proof of concept, then iterate
3. **Test in loop** - Observe results, encode learnings
4. **Blame yourself first** - Check prompts before blaming the model

## References

- [agentskills.io](https://agentskills.io) - Skill specification
- [vendor/pai/](vendor/pai/) - PAI patterns
- [vendor/anthropic-skills/](vendor/anthropic-skills/) - Official examples
