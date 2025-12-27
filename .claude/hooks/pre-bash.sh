#!/usr/bin/env bash
# Pre-Bash hook - validate commands before execution
# Usage: echo '{"tool_input":{"command":"rm -rf /"}}' | pre-bash.sh
# Input: JSON on stdin with tool_input.command
# Output: JSON with decision (approve/block/ask) and optional reason
# Note: Omits -e flag for fault tolerance (grep returns 1 on no match)

set -uo pipefail

# Read input
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Skip if no command
[[ -z "$command" ]] && echo '{"decision": "approve"}' && exit 0

# =============================================================================
# BLOCK: Absolutely dangerous commands (no override)
# =============================================================================
BLOCK_PATTERNS=(
    'rm -rf /'
    'rm -rf ~'
    'rm -rf \*'
    ':(){:|:&};:'           # Fork bomb
    '>\s*/dev/sd'           # Overwrite disk
    'mkfs\.'                # Format filesystem
    'dd if=.*/dev/'         # Raw disk write
    'chmod -R 777 /'        # Recursive permission destruction
    'chown -R .* /'         # Recursive ownership change on root
    '>\s*/dev/null\s*2>&1\s*&\s*disown'  # Background + detach (hiding)
)

for pattern in "${BLOCK_PATTERNS[@]}"; do
    if echo "$command" | grep -qE "$pattern"; then
        echo '{"decision": "block", "reason": "BLOCKED: Potentially catastrophic command"}'
        exit 0
    fi
done

# =============================================================================
# ASK: Destructive commands requiring explicit confirmation
# =============================================================================
ASK_PATTERNS=(
    # File/directory deletion
    'rm -rf'
    'rm -r'
    'rm .*\*'               # rm with wildcard
    'rmdir'
    'trash'
    'shred'

    # Git destructive operations
    'git push.*--force'
    'git push.*-f'
    'git reset --hard'
    'git clean -fd'
    'git checkout.*--force'
    'git branch -D'
    'git stash drop'
    'git stash clear'
    'git rebase'            # Can lose commits if interrupted

    # Database destructive operations
    'DROP\s+(TABLE|DATABASE|INDEX|VIEW)'
    'TRUNCATE'
    'DELETE\s+FROM'
    'UPDATE\s+.*\s+SET'     # Updates can be destructive

    # Email destructive operations (himalaya)
    'himalaya.*delete'
    'himalaya.*move'        # Moving can lose emails
    'mail\.sh\s+delete'
    'mail\.sh\s+move'

    # Calendar destructive operations
    'gcalcli\s+delete'
    'thallo.*delete'
    'cal\.sh\s+delete'

    # Password manager write operations (Bitwarden)
    'bw\s+create'
    'bw\s+edit'
    'bw\s+delete'
    'secrets::set'
    'secrets::update'
    'secrets::delete'

    # System/config changes
    'systemctl\s+(stop|disable|mask)'
    'launchctl\s+(unload|remove)'
    'chmod\s+-R'
    'chown\s+-R'
    'sudo'

    # Package removal
    'apt\s+(remove|purge|autoremove)'
    'brew\s+(uninstall|remove)'
    'pip\s+uninstall'
    'npm\s+uninstall'
    'cargo\s+uninstall'

    # Docker destructive
    'docker\s+(rm|rmi|prune|system\s+prune)'
    'docker-compose\s+down'

    # Kubernetes destructive
    'kubectl\s+delete'

    # Cloud destructive
    'aws\s+.*\s+delete'
    'gcloud\s+.*\s+delete'
    'az\s+.*\s+delete'

    # Force flags
    '--force'
    '--hard'
    '-f\s'
    '--delete'
    '--purge'
)

for pattern in "${ASK_PATTERNS[@]}"; do
    if echo "$command" | grep -qiE "$pattern"; then
        echo "{\"decision\": \"ask\", \"reason\": \"CONFIRM: This command may delete or modify data. Pattern matched: $pattern\"}"
        exit 0
    fi
done

# =============================================================================
# APPROVE: Safe commands
# =============================================================================
echo '{"decision": "approve"}'
