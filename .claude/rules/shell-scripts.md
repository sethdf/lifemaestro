---
paths:
  - "**/*.sh"
  - "scripts/**/*"
  - "bin/*"
---
# Shell Script Standards

- Start with `#!/usr/bin/env bash`
- Use `set -euo pipefail` for safety
- Include usage comment: `# Usage: script.sh <arg1> [arg2]`
- Validate inputs before processing
- Output to stdout, errors to stderr
- Use meaningful exit codes
