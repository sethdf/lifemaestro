# LifeMaestro

Personal AI Operating System - A provider-agnostic framework for AI-assisted productivity with **skill-level AI integration**.

## Philosophy

LifeMaestro takes a **skills-first, tokens-conscious** approach to AI:

- **Skills > MCP**: Instead of loading 5000+ tokens of MCP tool definitions into every conversation, skills invoke AI surgically where needed
- **Token Budget Control**: Each skill defines its own AI level (none, light, medium, full)
- **Provider Agnostic**: Use Claude, OpenAI, Ollama, or any AI provider
- **12-Factor CLI**: Clean, composable commands with proper stdout/stderr separation
- **Zones**: Flexible namespaces for any context (personal, work, freelance)

## Features

- **Skill-Level AI Integration**: Each task gets exactly the AI it needs
- **AI Agnostic**: Supports Claude, OpenAI, Ollama, Aider, Amazon Q, GitHub Copilot, and more
- **Native CLI Integration**: Uses each provider's native CLI for full feature access
- **Credential Keepalive**: Automatic refresh of AWS SSO, OAuth, and other credentials
- **Zone Management**: Flexible context switching with per-zone features
- **Session Management**: Organized AI sessions with templates and safety rules
- **Claude Code Skills**: SKILL.md files with cookbook pattern for agent orchestration

## Quick Start

```bash
# Clone the repo
git clone https://github.com/yourusername/lifemaestro.git ~/.config/lifemaestro

# Run installer
~/.config/lifemaestro/install.sh

# Reload shell
source ~/.bashrc  # or ~/.zshrc

# Check status
maestro status
```

## Commands

### Main Commands

| Command | Description |
|---------|-------------|
| `maestro status` | Show system status |
| `ai` | Launch AI assistant |
| `creds status` | Show credential status |
| `session new` | Create new session |
| `skill list` | List available skills |
| `zone` | Show/switch zones |
| `ticket` | Fetch tickets from issue trackers |
| `vendor` | Manage external dependencies (PAI, Fabric) |

### Zone Commands

```bash
zone                      # Show current zone
zone list                 # List all configured zones
zone switch personal      # Output switch commands
eval "$(zone switch personal)"  # Apply zone switch

# Zones configure:
# - Git identity (user.name, user.email)
# - AWS profile
# - GitHub SSH host
# - AI provider preferences
# - Optional features (SDP, Jira, Linear)
```

### Ticket Commands

```bash
ticket sdp 12345          # Fetch from ServiceDesk Plus
ticket jira PROJ-123      # Fetch from Jira
ticket linear ENG-456     # Fetch from Linear
ticket github #123        # Fetch from GitHub Issues
ticket auto SDP-12345     # Auto-detect ticket type
```

### Skill Commands

```bash
skill list                    # List all skills with AI levels
skill run summarize "text"    # Run a skill
skill info categorize         # Show skill details

# Skills can be run directly
skill categorize "Important meeting tomorrow"
echo "Hello world" | skill summarize
```

### AI Commands

```bash
ai                      # Chat with default provider
ai chat ollama          # Chat with specific provider
ai ask "question"       # Quick question
ai code                 # Start coding assistant
ai list                 # List available providers
```

### Session Commands

```bash
session new exploration my-project    # Create session
session ticket 123 "bug fix"          # Work ticket
session explore my-idea               # Exploration session
session list                          # List sessions
session go                            # Jump to session (fzf)
session switch personal               # Switch zone
```

## Skill Architecture

LifeMaestro has two skill systems that share underlying tools:

### 1. Bash Skills (CLI)

For direct human invocation via `skill run <name>`:

| Level | Description | Token Cost | Example Skills |
|-------|-------------|------------|----------------|
| `none` | Pure bash, zero AI | 0 | creds, session-list, zone-switch |
| `light` | Single-shot AI | ~100-500 | categorize, extract-action, sentiment |
| `medium` | Multi-step AI | ~500-2000 | summarize, draft-reply, explain |
| `full` | Interactive session | Variable | code, chat |

### 2. Claude Code Skills (Agent)

For AI agent orchestration via SKILL.md files in `.claude/skills/`:

```
.claude/skills/ticket-lookup/
├── SKILL.md              # Routing logic (when to use which tool)
├── cookbook/             # Progressive disclosure (API docs)
│   ├── sdp-lookup.md
│   ├── jira-lookup.md
│   └── ...
└── tools/                # Actual scripts (zero tokens)
    ├── sdp-fetch.sh
    ├── jira-fetch.sh
    └── ...
```

**Key insight**: The tools are shared. CLI commands and Claude Code both invoke the same scripts.

```
CLI: ticket sdp 12345
         │
         └──▶ tools/sdp-fetch.sh ◀──┐
                                     │
Agent: "fetch that SDP ticket"      │
         │                          │
         └──▶ SKILL.md ──▶ cookbook ─┘
```

## Zones

Zones replace hardcoded work/home contexts with flexible namespaces:

```toml
# config.toml

[zones.personal]
description = "Personal projects"

[zones.personal.git]
user = "Your Name"
email = "you@personal.com"

[zones.personal.features]
tickets = false
sdp = false

[zones.acme-corp]
description = "Work projects"

[zones.acme-corp.git]
user = "Your Name"
email = "you@company.com"

[zones.acme-corp.features]
tickets = true
sdp = true
jira = false
```

Each zone can enable/disable features independently.

## Configuration

Edit `~/.config/lifemaestro/config.toml`:

```toml
[ai]
default_provider = "claude"
default_fast_provider = "ollama"  # For light AI skills

[zones.personal]
[zones.personal.git]
user = "Your Name"
email = "you@personal.com"

[zones.personal.aws]
profile = "personal-sso"

[zones.personal.features]
tickets = false

[zones.work]
[zones.work.git]
user = "Your Name"
email = "you@company.com"

[zones.work.aws]
profile = "work-sso"

[zones.work.features]
tickets = true
sdp = true

[skills.providers]
light = "ollama"    # Fast, cheap
medium = "claude"   # Better quality
full = "claude"     # Interactive
```

## External Dependencies (PAI, Fabric)

LifeMaestro supports external dependencies via the vendor system. This allows you to integrate your Personal AI Infrastructure (PAI) and keep it updated from GitHub.

### Setting Up PAI

1. Edit `vendor/vendor.yaml` and set your PAI repo URL:
   ```yaml
   vendors:
     pai:
       repo: "https://github.com/YOUR_USERNAME/pai.git"
       enabled: true
   ```

2. Sync PAI:
   ```bash
   vendor sync pai          # Clone PAI
   vendor update pai        # Update to latest
   vendor status            # Check status
   ```

3. Use PAI patterns:
   ```bash
   # List available patterns
   adapters/vendor/pai.sh patterns

   # Run a pattern
   echo "long text" | adapters/vendor/pai.sh run summarize
   ```

### Vendor Commands

```bash
vendor sync [name]      # Clone/sync all or specific vendor
vendor update [name]    # Force update to latest
vendor list             # List configured vendors
vendor status           # Show what's installed
vendor clean <name>     # Remove a vendor
```

### Fabric Integration

Fabric patterns work automatically via:
1. **Native Fabric CLI** (if installed) - preferred
2. **PAI patterns** (if PAI includes Fabric patterns)
3. **Standalone vendor/fabric** (if enabled in vendor.yaml)

```bash
# Check Fabric status
adapters/vendor/fabric.sh status

# Use Fabric patterns
adapters/vendor/fabric.sh list
echo "text" | adapters/vendor/fabric.sh run summarize
adapters/vendor/fabric.sh youtube "URL" extract_wisdom
```

## Directory Structure

```
~/.config/lifemaestro/
├── config.toml           # Main configuration
├── DESIGN.md             # Architecture principles
├── core/                 # Core functionality
│   ├── init.sh
│   ├── cli.sh            # 12-Factor CLI compliance
│   ├── utils.sh
│   ├── skills.sh         # Bash skill framework
│   └── keepalive.sh
├── .claude/              # Claude Code skills
│   └── skills/
│       ├── zone-context/
│       ├── ticket-lookup/
│       ├── session-manager/
│       └── repo-setup/
├── adapters/             # Provider adapters
│   ├── ai/
│   ├── mail/
│   └── secrets/
├── sessions/             # Session management
│   ├── session.sh
│   ├── templates/
│   └── rules/
├── bin/                  # User commands
│   ├── maestro
│   ├── ai
│   ├── creds
│   ├── session
│   ├── skill
│   ├── zone              # Zone management
│   ├── ticket            # Ticket lookup
│   └── vendor            # External dependency management
├── vendor/               # External dependencies (GitHub repos)
│   ├── vendor.yaml       # Dependency configuration
│   ├── sync.sh           # Sync/update script
│   ├── pai/              # Personal AI Infrastructure (cloned)
│   └── fabric/           # Fabric patterns (optional)
├── adapters/vendor/      # Vendor integrations
│   ├── pai.sh            # PAI adapter
│   └── fabric.sh         # Fabric adapter
└── secrets/              # Encrypted secrets
```

## Creating Custom Skills

### Bash Skills

Add to `~/.config/lifemaestro/skills/`:

```bash
# skills/my-skill.sh

_skill_my_custom() {
    local input="${1:-}"
    skill::ai_oneshot "Process this: $input"
}

skill::register "my-skill" "_skill_my_custom" "light" "My custom skill"
```

### Claude Code Skills

Create in `.claude/skills/my-skill/`:

```markdown
# SKILL.md
---
name: my-skill
description: Do something. Use when user asks about X.
---

## Variables
- enable_feature: true

## Instructions
If user requests X AND enable_feature is true:
- Read cookbook/feature.md
- Run tools/do-thing.sh
```

See `DESIGN.md` for full architecture documentation.

## Supported AI Providers

### API Providers
- Claude (Anthropic API / AWS Bedrock)
- OpenAI
- Google Gemini
- Mistral
- Groq

### Local Providers
- Ollama
- LM Studio

### Coding Assistants
- Claude Code
- Aider
- Amazon Q
- GitHub Copilot

### Utility Tools
- llm (Simon Willison)

## License

MIT
