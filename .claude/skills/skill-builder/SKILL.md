---
name: skill-builder
description: |
  Build new skills following official Anthropic patterns. Use when user wants to
  create, design, scaffold, or improve a skill. Triggers: create skill, new skill,
  build skill, scaffold skill, improve skill, skill design.
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# Skill Builder

Meta-skill for creating skills following official Anthropic specifications (github.com/anthropics/skills).

## Variables
- enabled: true
- auto_scaffold: true

## Purpose
Help design and create new skills that follow official Anthropic patterns:
- Progressive disclosure (SKILL.md → references → scripts)
- Token-efficient architecture (description triggers, body routes)
- Official structure: scripts/, references/, assets/

## Instructions

### When user wants to CREATE a new skill:

1. **Gather requirements:**
   - What problem does this skill solve?
   - What are the trigger phrases? (crucial for description)
   - What scripts/references/assets are needed?

2. **Read the design guide:**
   - Read `references/skill-design.md` for official Anthropic patterns

3. **Design the skill:**
   - Plan: scripts/ (executable), references/ (docs), assets/ (templates)
   - Write description with ALL trigger information
   - Keep SKILL.md body concise (<500 lines)

4. **Scaffold the skill:**
   - Run `scripts/scaffold-skill.sh <name> [options]`
   - Creates official directory structure

5. **Implement:**
   - Edit SKILL.md - focus on clear description and instructions
   - Implement scripts/ - test that they work standalone
   - Write references/ - detailed docs loaded on demand

### When user wants to IMPROVE an existing skill:

1. Read the current skill files
2. Check against `references/skill-design.md` principles
3. For workflow issues: see `references/workflows.md`
4. For output issues: see `references/output-patterns.md`
5. For common patterns: see `references/skill-patterns.md`

### Key Official Principles:

- **Concise is key** - Context window is shared, only add what Claude doesn't know
- **Description is crucial** - It's the ONLY thing that triggers the skill
- **Progressive disclosure** - SKILL.md routes to references, don't dump everything

## Examples

- "Create a skill for fetching weather" → Design + scaffold weather skill
- "Build a code review skill" → Design + scaffold code-review skill
- "Help me improve the ticket-lookup skill" → Analyze and suggest improvements
- "What's wrong with this skill?" → Review against best practices
