# Skills TODO

## Completed

- [x] Decided: Use SKILL.md directly (industry standard)
- [x] Removed generic format / build system experiment
- [x] Renamed cookbook/ → references/ in all skills
- [x] Added allowed-tools to all skill frontmatter
- [x] Created .claude/rules/ for path-specific rules
- [x] Created .claude/settings.json with permissions
- [x] Trimmed CLAUDE.md (169 → 74 lines)
- [x] Simplified skills/SPEC.md (680 → 82 lines)
- [x] Added `bin/skill-validate` for SKILL.md validation
- [x] Documented Gemini CLI skillz setup (docs/gemini-setup.md)
- [x] Added MCP server configuration (.claude/mcp.json, docs/mcp-setup.md)
- [x] Created hooks for common workflows (.claude/hooks/, docs/hooks.md)

## Future

- [ ] **Step 6 Automation (Iterate)** - Currently just guidance, could automate:
  - Track skill usage (which skills triggered, frequency)
  - Log skill failures or poor results
  - Suggest improvements based on usage patterns
  - Requires: hooks into skill invocation, feedback mechanism, analytics

- [ ] **Data Loss Prevention Guardrails** - System-wide guardrails to prevent data loss:
  - Require explicit approval before destructive operations
  - Show exactly what will be changed/deleted before proceeding
  - Where to implement? Hooks? Rules? Core safety layer?
  - See `.claude/rules/safety.md` for current approach

- [ ] **Tailscale Network Switching by Context** - Different networks for work vs home:
  - Auto-switch Tailscale network when zone changes
  - Work zone → work tailnet, home zone → personal tailnet
  - Integrate with zone-context skill

- [ ] **OpenSpec/SpecKit for Software Projects** - Spec-driven development:
  - Clone latest Fission-AI/OpenSpec for code projects
  - `openspec/specs/` for system truth, `openspec/changes/` for proposals
  - Native Claude Code slash command support
  - Investigate: SpecKit (fragmented, unclear primary source)

- [ ] **Self-Healing Skills & Friction Reduction** - Skills that improve themselves:
  - Detect when skills fail or produce poor results
  - Auto-suggest improvements to SKILL.md or scripts
  - Track friction points and propose fixes
  - Related to Step 6 automation above

- [ ] **AI Coding with Self-Healing** - Methodologies where AI watches errors:
  - Monitor test failures, lint errors, build failures
  - Auto-fix common patterns without user intervention
  - Learn from repeated fixes to prevent future issues
  - Explore: error pattern recognition, fix libraries

- [ ] **Multi-Model Query (Best Response Selection)** - Query multiple models, pick best:
  - PAI has a skill for this (investigate: pai-research or similar)
  - Send same prompt to Claude/Gemini/GPT, compare responses
  - Quality scoring: accuracy, completeness, code correctness
  - Use case: critical decisions, complex analysis

- [ ] **LSP Support via lsp-ai** - Language Server Protocol integration:
  - https://github.com/SilasMarvin/lsp-ai
  - Better code intelligence for AI assistants
  - Go-to-definition, find-references, hover info
  - Could improve code navigation and understanding

## Architecture Complete

```
.claude/
├── skills/          # SKILL.md format skills
├── rules/           # Path-specific rules
├── hooks/           # Pre/post tool hooks
├── settings.json    # Permissions
└── mcp.json         # External API integrations

bin/
├── skills           # List available skills
└── skill-validate   # Validate SKILL.md format

docs/
├── gemini-setup.md  # Gemini CLI integration
├── mcp-setup.md     # MCP configuration guide
└── hooks.md         # Hooks documentation
```
