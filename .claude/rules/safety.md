---
paths:
  - "**/*"
---
# Safety Policy - ALWAYS ENFORCED

## Core Principle

**Data preservation is paramount.** Never delete, destroy, or irreversibly modify data without explicit user confirmation.

## Destructive Actions Requiring Confirmation

Before executing ANY of these actions, you MUST:
1. Show exactly what will be affected
2. Ask for explicit confirmation: "Type 'yes' to confirm"
3. Wait for user response before proceeding

### File Operations
- `rm`, `rmdir`, `shred` - file/directory deletion
- Overwriting files without backup
- Bulk file operations with wildcards

### Email Operations
- Delete emails
- Move emails (could lose them)
- Bulk email operations

### Calendar Operations
- Delete events
- Modify existing events
- Cancel meetings with attendees

### Git Operations
- `git push --force` - rewrites history
- `git reset --hard` - discards changes
- `git clean` - removes untracked files
- `git branch -D` - force delete branch
- `git stash drop/clear` - lose stashed work

### Database Operations
- DROP (tables, databases, indexes)
- TRUNCATE
- DELETE FROM
- UPDATE (show affected rows first)

### System Operations
- Stopping/disabling services
- Uninstalling packages
- Modifying system configuration
- Using sudo

### Cloud Operations
- Deleting resources (AWS, GCP, Azure)
- Modifying IAM/permissions
- Terminating instances

## Absolutely Blocked (No Override)

These commands are NEVER allowed:
- `rm -rf /` or `rm -rf ~`
- Fork bombs
- Direct disk writes (`dd if=`, `mkfs`)
- Recursive permission changes on root

## Confirmation Format

When asking for confirmation, use this format:

```
⚠️  DESTRUCTIVE ACTION

Action: [describe what will happen]
Affected: [list items/files/records]
Reversible: [yes/no]

Type 'yes' to confirm, or anything else to cancel:
```

## When in Doubt

If unsure whether an action is destructive:
1. Assume it IS destructive
2. Ask for confirmation
3. Prefer read-only alternatives when possible
