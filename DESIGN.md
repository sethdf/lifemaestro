# LifeMaestro Design Principles

This document outlines the architectural principles, patterns, and philosophies that guide LifeMaestro's design.

## Core Philosophy

LifeMaestro is a **Personal AI Operating System** that orchestrates AI tools, credentials, and workflows across multiple contexts (zones). It follows battle-tested software engineering principles while embracing the new paradigm of AI-assisted development.

---

## Unix Philosophy

### 1. Do One Thing Well

Each component has a single, focused responsibility:

```
zone-context/     → Zone detection and switching
ticket-lookup/    → Fetch tickets from issue trackers
session-manager/  → Create and navigate sessions
repo-setup/       → Initialize GitHub repositories
```

Tools are small, composable scripts that can be combined:
```bash
zone-detect.sh | zone-switch.sh | session-create.sh
```

### 2. Everything is Text

- Configuration in human-readable TOML
- Skills defined in Markdown
- Output as structured text (YAML-like format)
- Tools communicate via stdout/stderr

### 3. Compose Small Programs

Tools are designed to pipe together:
```bash
# Detect zone, switch context, create session
zone=$(zone-detect.sh | grep "^zone:" | cut -d' ' -f2)
eval "$(zone-switch.sh $zone)"
session-create.sh "$zone" explorations my-session
```

### 4. Silence is Golden

Tools produce no output on success unless explicitly requested:
- Exit code 0 = success
- stderr for errors
- stdout for data that will be consumed by other tools

### 5. Fail Fast and Loud

```bash
set -euo pipefail  # Every script starts with this

# Check preconditions early
if [[ -z "$zone" ]]; then
    echo "Error: Zone not specified" >&2
    exit 1
fi
```

---

## 12-Factor CLI Principles

LifeMaestro adapts the [12-Factor App](https://12factor.net/) methodology for CLI tools.

### I. Codebase

One codebase tracked in Git, deployed to multiple environments (personal machines, servers).

### II. Dependencies

Explicitly declare all dependencies:
```bash
# Check for required tools
command -v dasel &>/dev/null || { echo "dasel required"; exit 1; }
command -v jq &>/dev/null || { echo "jq required"; exit 1; }
```

### III. Config

Store config in the environment and files, never in code:
```toml
# config.toml - all configuration externalized
[zones.personal]
git.email = "you@personal.com"

[zones.acme-corp]
git.email = "you@company.com"
```

Configuration precedence:
1. Command-line flags (highest)
2. Environment variables (`MAESTRO_*`)
3. Config file (`config.toml`)
4. Hardcoded defaults (lowest)

### IV. Backing Services

Treat external services as attached resources:
- GitHub API
- ServiceDesk Plus API
- Jira API
- Linear API
- AWS services

All accessed through adapters that can be swapped.

### V. Build, Release, Run

Strictly separate build and run stages:
- Installation creates symlinks and directories
- Configuration is applied at runtime
- No compilation step required

### VI. Processes

Execute tools as stateless processes:
- No shared state between invocations
- State stored in filesystem or external services
- Each tool invocation is independent

### VII. Port Binding (N/A for CLI)

Not applicable to CLI tools, but keepalive daemon could expose status port.

### VIII. Concurrency

Scale out via multiple processes:
- Multiple terminal sessions
- Parallel agent invocations
- Background keepalive daemon

### IX. Disposability

Fast startup and graceful shutdown:
```bash
# Tools start instantly
# Cleanup on exit
trap cleanup EXIT
```

### X. Dev/Prod Parity

Keep development and production as similar as possible:
- Same scripts run locally and in automation
- Same config format everywhere

### XI. Logs

Treat logs as event streams:
```bash
maestro::log() {
    echo "[$timestamp] [$level] $msg" >> "$MAESTRO_STATE/maestro.log"
}
```

### XII. Admin Processes

Run admin/management tasks as one-off processes:
```bash
# One-off setup
setup-session-repos.sh acme-corp

# One-off credential refresh
maestro creds refresh aws
```

---

## Claude Code Skill Patterns

Based on [IndyDevDan's skill architecture](https://www.youtube.com/watch?v=...), LifeMaestro implements these patterns:

### 1. Pivot File Pattern

Every skill centers around a `SKILL.md` file that:
- Defines metadata (name, description, trigger conditions)
- Contains variables for feature flags
- Routes to cookbook documentation conditionally

```markdown
---
name: ticket-lookup
description: Look up tickets. Use when user mentions ticket number.
---

## Variables
- enable_sdp: true
- enable_jira: true

## Instructions
If ticket is SDP type AND enable_sdp is true:
- Read cookbook/sdp-lookup.md
```

### 2. Cookbook Pattern (Progressive Disclosure)

Don't load all documentation at once. Conditionally disclose based on the request:

```
.claude/skills/ticket-lookup/
├── SKILL.md              # Entry point with routing logic
├── cookbook/
│   ├── sdp-lookup.md     # Only loaded for SDP tickets
│   ├── jira-lookup.md    # Only loaded for Jira tickets
│   ├── linear-lookup.md  # Only loaded for Linear issues
│   └── github-issues-lookup.md
└── tools/
    └── *.sh              # Scripts the agent invokes
```

This reduces context window bloat and improves agent focus.

### 3. Variables Section

Skills define tunable parameters:

```markdown
## Variables
- enable_sdp: true
- enable_jira: false
- fast_model: haiku
- base_model: sonnet
```

These act as feature flags that:
- Enable/disable capabilities per zone
- Configure model selection
- Control behavior without code changes

### 4. Tools Directory

Each skill has executable scripts the agent can invoke:

```
tools/
├── zone-detect.sh
├── zone-switch.sh
└── zone-list.sh
```

Scripts follow these conventions:
- Executable (`chmod +x`)
- Self-contained (source only what's needed)
- Return structured output for parsing
- Exit with meaningful codes

### 5. Prompts Directory

Reusable prompt templates:

```
prompts/
└── fork-summary-user-prompt.md
```

These are metaprompts that agents fill out and pass to other agents.

---

## Core Four Pattern

From IndyDevDan: Every AI interaction reduces to four components:

```
Context + Model + Prompt + Tools = Agent Capability
```

### Context
- Zone configuration (git identity, AWS profile, enabled features)
- Session history (CLAUDE.md files)
- Cookbook documentation (progressively disclosed)

### Model
- Configurable per zone and task
- Fast models for simple queries (Haiku, GPT-4o-mini)
- Base models for complex work (Sonnet, GPT-4o)
- Heavy models for critical tasks (Opus)

### Prompt
- SKILL.md defines the interaction structure
- Cookbook provides domain-specific knowledge
- Template variables enable customization

### Tools
- Bash scripts extend agent capabilities
- External APIs accessed through adapters
- Structured output for parsing

---

## Adapter Pattern

LifeMaestro uses adapters to abstract external services:

```
adapters/
├── ai/
│   ├── claude.sh
│   ├── ollama.sh
│   └── openai.sh
├── tickets/
│   ├── sdp.sh
│   ├── jira.sh
│   └── linear.sh
└── secrets/
    ├── sops.sh
    └── env.sh
```

### Priority-Based Selection

Adapters are tried in order of preference:

```bash
# AI providers: native CLI → llm tool → direct API
if command -v claude &>/dev/null; then
    # Use Claude CLI
elif skill::_has_llm; then
    # Use llm tool
elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    # Use direct API
fi
```

### Interface Consistency

All adapters for a module expose the same interface:

```bash
# All ticket adapters implement:
ticket_fetch <id>  # Returns structured ticket data
```

---

## Zone Architecture

Zones are flexible namespaces that replace hardcoded contexts:

### Zone Structure

```toml
[zones.acme-corp]
name = "acme-corp"
description = "Work projects"

[zones.acme-corp.git]
user = "Your Name"
email = "you@company.com"

[zones.acme-corp.features]
tickets = true
sdp = true
jira = false
```

### Zone Detection

Priority-based zone detection:

1. Explicit `MAESTRO_ZONE` environment variable
2. Pattern matching against current directory
3. Fallback to default zone

```toml
[zones.detection]
patterns = [
    { pattern = "~/work", zone = "acme-corp" },
    { pattern = "~/personal", zone = "personal" },
]
```

### Feature Flags per Zone

Each zone enables specific features:

```toml
[zones.acme-corp.features]
tickets = true      # Enable ticket integration
sdp = true          # ServiceDesk Plus API
jira = false        # Jira (disabled for this zone)
github_issues = true
```

Skills check these flags before executing:

```bash
sdp_enabled=$(dasel ... "zones.$zone.features.sdp")
if [[ "$sdp_enabled" != "true" ]]; then
    echo "SDP not enabled for zone '$zone'" >&2
    exit 1
fi
```

---

## Session Management

Sessions are git-tracked working directories:

```
~/ai-sessions/
├── <zone>/
│   ├── <category-repo>/
│   │   └── <date>-<name>/
│   │       └── CLAUDE.md
```

### Session Lifecycle

1. **Create**: Generate from template, commit to repo
2. **Work**: Claude Code operates in session directory
3. **Compact**: Archive history when CLAUDE.md grows large
4. **Complete**: Mark session done, push final state

### Templates

Templates define session structure with placeholders:

```markdown
# {{NAME}}

**Date:** {{DATE}}
**Zone:** {{CC_CONTEXT}}

## Objective
{{OBJECTIVE}}

## Rules
{{RULES}}
```

---

## Begin with the End in Mind

From IndyDevDan's methodology:

> "If you don't actually fully understand what you want to see... Those who plan the future tend to create it."

### Planning Before Prompting

1. Define the concrete output structures
2. Understand what assets you'll generate
3. Write out the file structure
4. Then start prompting

### Incremental Development

1. **Proof of Concept**: Verify the idea works
2. **Minimum Viable Product**: First usable version
3. **Iteration**: Improve based on feedback

### Blame Yourself First

> "Don't assume it's the model's fault. First assume it's your fault... More cases than not, the limitation is not the models, it's you and I."

Debug order:
1. Your prompt
2. Your instructions
3. Your skill structure
4. Then consider model limitations

---

## Information Dense Keywords

Use specific keywords that carry embedded meaning:

```markdown
# Bad: vague
Update the file

# Good: information dense
Update using Astral UV single file script
```

Keywords like "Astral UV", "subprocess", "YAML format" carry rich semantic information that models understand.

---

## Agentic Code Principles

Code written for agents to consume and operate:

### 1. Clear Output

```bash
# Return structured, parseable output
echo "zone: $zone"
echo "source: pattern_match"
echo "path: $session_dir"
```

### 2. Error Visibility

```bash
# Capture and report errors
if [[ -z "$response" ]]; then
    echo "Error: API returned empty response" >&2
    exit 1
fi
```

### 3. Self-Documenting

```bash
if [[ -z "$1" ]]; then
    echo "Usage: session-create.sh <zone> <category> <name>" >&2
    exit 1
fi
```

---

## Summary

LifeMaestro combines:

| Principle | Application |
|-----------|-------------|
| Unix Philosophy | Small, composable tools |
| 12-Factor CLI | Config externalization, stateless processes |
| Cookbook Pattern | Progressive disclosure of documentation |
| Pivot File | Central skill.md with routing logic |
| Core Four | Context + Model + Prompt + Tools |
| Adapter Pattern | Swappable external service integrations |
| Zone Architecture | Flexible, feature-flagged namespaces |
| Begin with End | Plan before prompting |

These principles create a system that is:
- **Modular**: Easy to extend with new skills
- **Portable**: Works across machines and contexts
- **Maintainable**: Clear separation of concerns
- **AI-Native**: Designed for agent interaction
