# LifeMaestro

Personal AI Operating System - A provider-agnostic framework for AI-assisted productivity with **skill-level AI integration**.

## Philosophy

LifeMaestro takes a **skills-first, tokens-conscious** approach to AI:

- **Skills > MCP**: Instead of loading 5000+ tokens of MCP tool definitions into every conversation, skills invoke AI surgically where needed
- **Token Budget Control**: Each skill defines its own AI level (none, light, medium, full)
- **Provider Agnostic**: Use Claude, OpenAI, Ollama, or any AI provider
- **12-Factor CLI**: Clean, composable commands with proper stdout/stderr separation

## Features

- **Skill-Level AI Integration**: Each task gets exactly the AI it needs
- **AI Agnostic**: Supports Claude, OpenAI, Ollama, Aider, Amazon Q, GitHub Copilot, and more
- **Native CLI Integration**: Uses each provider's native CLI for full feature access
- **Credential Keepalive**: Automatic refresh of AWS SSO, OAuth, and other credentials
- **Context Switching**: Seamless work/home identity and credential management
- **Session Management**: Organized AI sessions with templates and safety rules

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

### Credential Commands

```bash
creds status            # Show all credentials
creds start             # Start keepalive daemon
creds stop              # Stop daemon
creds refresh           # Force refresh all
creds watch             # Live status display
```

### Session Commands

```bash
session new exploration my-project    # Create session
session ticket 123 "bug fix"          # Work ticket
session work investigation            # Work exploration
session home my-idea                  # Home exploration
session list                          # List sessions
session go                            # Jump to session (fzf)
session switch work                   # Switch context
```

## Skill Levels

Each skill declares its AI usage level:

| Level | Description | Token Cost | Example Skills |
|-------|-------------|------------|----------------|
| `none` | Pure bash, zero AI | 0 | creds, session-list, context-switch |
| `light` | Single-shot AI | ~100-500 | categorize, extract-action, sentiment |
| `medium` | Multi-step AI | ~500-2000 | summarize, draft-reply, explain |
| `full` | Interactive session | Variable | code, chat |

```bash
skill list
# Output:
#   ○ creds (none)
#   ○ session-list (none)
#   ◐ categorize (light)
#   ◐ sentiment (light)
#   ◑ summarize (medium)
#   ◑ draft-reply (medium)
#   ● code (full)
#   ● chat (full)
```

## Why Skills > MCP

MCP (Model Context Protocol) loads ALL tool definitions into EVERY conversation:
- 20 tools = 5000+ tokens overhead per message
- You pay for tool definitions whether used or not
- Tools compete for context window space

LifeMaestro Skills:
- Zero tokens for non-AI operations
- Minimal tokens for light AI tasks
- AI invoked only when needed
- User controls exactly where tokens are spent

## Configuration

Edit `~/.config/lifemaestro/config.toml`:

```toml
[ai]
default_provider = "claude"
default_fast_provider = "ollama"  # For light AI skills

[contexts.work]
[contexts.work.git]
user = "Your Name"
email = "you@company.com"

[contexts.work.aws]
profile = "work-sso"

[contexts.home]
[contexts.home.git]
user = "Your Name"
email = "you@personal.com"

[skills.providers]
light = "ollama"    # Fast, cheap
medium = "claude"   # Better quality
full = "claude"     # Interactive
```

## Directory Structure

```
~/.config/lifemaestro/
├── config.toml           # Main configuration
├── core/                 # Core functionality
│   ├── init.sh
│   ├── cli.sh            # 12-Factor CLI compliance
│   ├── utils.sh
│   ├── skills.sh         # Skill framework
│   └── keepalive.sh
├── adapters/             # Provider adapters
│   ├── ai/
│   ├── mail/
│   └── secrets/
├── sessions/             # Session management
│   ├── session.sh
│   ├── templates/
│   └── rules/
├── skills/               # Custom skills (*.sh)
├── bin/                  # User commands
│   ├── maestro
│   ├── ai
│   ├── creds
│   ├── session
│   └── skill
└── secrets/              # Encrypted secrets
```

## Creating Custom Skills

Add skills to `~/.config/lifemaestro/skills/`:

```bash
# skills/my-skill.sh

_skill_my_custom() {
    local input="${1:-}"

    # Your skill logic here
    skill::ai_oneshot "Process this: $input"
}

# Register with name, function, AI level, description
skill::register "my-skill" "_skill_my_custom" "light" "My custom skill"
```

## Supported AI Providers

### API Providers
- Claude (Anthropic API / AWS Bedrock)
- OpenAI
- Google Gemini
- Mistral
- Groq
- Cohere

### Local Providers
- Ollama
- LM Studio
- llama.cpp

### Coding Assistants
- Claude Code
- Aider
- Amazon Q
- GitHub Copilot

### Utility Tools
- llm (Simon Willison)
- Fabric

## Future: LifeLibretto

LifeMaestro will integrate with **LifeLibretto**, an immutable archive:
- Automatic archival of completed sessions
- Searchable history of past work
- AI-assisted recall and context restoration

## License

MIT
