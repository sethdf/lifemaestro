---
name: session-close
description: Close and categorize an AI session with intelligent metadata extraction. Use when user says "close session", "session close", or wants to finalize and categorize their current work session.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# Session Close

Close and categorize an AI session with intelligent metadata extraction.

## Overview

This skill analyzes the current session's CLAUDE.md to extract:
- **Category**: AI-determined based on content (e.g., bugs, features, learning, research)
- **Tags**: 3-5 relevant keywords for filtering/search
- **Outcome**: Session result (success, partial, abandoned, ongoing)
- **Summary**: 1-2 sentence description
- **Learnings**: Key insights, gotchas, patterns discovered

## Requirements

- Must be run inside Claude Code (requires AI analysis)
- Session must have a CLAUDE.md file
- Optionally have .session.json (will create if missing)

## Workflow

### Step 1: Pre-flight Checks

1. Verify CLAUDE.md exists in current directory
2. Check for uncommitted changes:
   ```bash
   git status --porcelain
   ```
3. If uncommitted changes exist, ask user to commit first or auto-commit

### Step 2: Read Session Content

Read the CLAUDE.md file to analyze:
```bash
cat CLAUDE.md
```

Also check for existing .session.json:
```bash
cat .session.json 2>/dev/null || echo "No existing metadata"
```

### Step 3: Analyze and Categorize

Based on the CLAUDE.md content, determine:

1. **Category** (pick ONE that best fits):
   - Work categories: `tickets`, `features`, `bugs`, `infra`, `investigation`, `docs`, `meetings`, `planning`
   - Home categories: `projects`, `learning`, `health`, `finance`, `hobbies`, `maintenance`, `family`
   - Universal: `research`, `experiment`, `poc`, `support`

2. **Tags** (3-5 keywords):
   - Extract from technologies, tools, concepts mentioned
   - Use lowercase, hyphenated format (e.g., `kubernetes`, `api-design`, `react-hooks`)

3. **Outcome**:
   - `success` - Objective achieved
   - `partial` - Some progress, not complete
   - `abandoned` - Stopped without completing
   - `ongoing` - Work continues in future sessions

4. **Summary**:
   - 1-2 sentences describing what was done
   - Focus on outcomes, not process

5. **Learnings** (for learning/research sessions):
   - Technical insights discovered
   - Tools/commands learned
   - Patterns to remember
   - Gotchas/pitfalls to avoid

### Step 4: Present for Confirmation

Show the user your analysis:

```
## Session Analysis

**Category:** bugs
**Tags:** react, state-management, race-condition
**Outcome:** success
**Summary:** Fixed race condition in user profile component by implementing proper cleanup in useEffect hook.

**Learnings:**
- Always return cleanup function from useEffect when dealing with async operations
- Race conditions often appear as "state update on unmounted component" warnings

Confirm these values? (yes/edit/cancel)
```

### Step 5: Update Metadata

Update .session.json with the confirmed values:

```bash
# Source schema helpers
source "$MAESTRO_ROOT/sessions/schema.sh"

# Update fields
session::metadata_set "." "category" "bugs"
session::metadata_set_tags "." "react" "state-management" "race-condition"
session::metadata_set "." "outcome" "success"
session::metadata_set "." "summary" "Fixed race condition in user profile component"
session::metadata_close "." "success" "Fixed race condition in user profile component"
```

Or use jq directly:
```bash
jq '.category = "bugs" | .tags = ["react", "state-management", "race-condition"] | .outcome = "success" | .summary = "Fixed race condition" | .status = "closed" | .closed = "2024-12-30T12:00:00Z"' .session.json > tmp.$$ && mv tmp.$$ .session.json
```

### Step 6: Optional Archive

Ask if user wants to archive CLAUDE.md:
```bash
mkdir -p .claude-archives
cp CLAUDE.md ".claude-archives/CLAUDE_$(date +%Y%m%d_%H%M%S).md"
```

### Step 7: Commit and Finish

```bash
git add -A
git commit -m "session: close - ${summary}"
```

## Deep Extraction Mode

For learning/research sessions, offer deep extraction:

```
This appears to be a learning session. Would you like deep extraction using extract_wisdom?
(This provides comprehensive IDEAS, INSIGHTS, QUOTES, RECOMMENDATIONS)
```

If yes, invoke:
```
/pai-fabric extract_wisdom
```

And append results to `~/ai-sessions/learnings/<year>.md`

## Quick Mode

For `--quick` flag, skip confirmation and use AI suggestions directly:
- Still requires AI analysis
- Automatically accepts suggestions
- Useful for batch closing sessions

## Error Handling

- **No CLAUDE.md**: "No CLAUDE.md found. Is this a session directory?"
- **No AI context**: "Session close requires Claude Code for AI analysis. Run inside Claude Code."
- **Already closed**: "Session already closed on {date}. Reopen? (yes/no)"

## Files Modified

- `.session.json` - Updated with category, tags, outcome, summary, learnings, closed timestamp
- `CLAUDE.md` - Optional: "Session closed" marker appended
- `.claude-archives/` - Optional: Archived CLAUDE.md copy

## References

- [categories.md](references/categories.md) - Full category definitions and examples
