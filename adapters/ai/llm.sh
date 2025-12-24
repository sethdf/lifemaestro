#!/usr/bin/env bash
# lifemaestro/adapters/ai/llm.sh - Simon Willison's llm tool adapter

ai::available() {
    command -v llm &>/dev/null
}

ai::chat() {
    llm chat "$@"
}

ai::ask() {
    local question="$1"
    echo "$question" | llm
}

ai::stream() {
    local message="$1"
    echo "$message" | llm
}
