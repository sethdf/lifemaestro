#!/usr/bin/env bash
# lifemaestro/adapters/ai/claude.sh - Claude adapter

ai::available() {
    command -v claude &>/dev/null
}

ai::chat() {
    claude "$@"
}

ai::ask() {
    local question="$1"
    claude --print "$question"
}

ai::stream() {
    local message="$1"
    echo "$message" | claude
}
