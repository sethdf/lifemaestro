#!/usr/bin/env bash
# lifemaestro/adapters/secrets/pass.sh - Pass (password-store) adapter

PASS_PREFIX="${PASS_PREFIX:-lifemaestro}"

secrets::get() {
    local key="$1"
    pass show "$PASS_PREFIX/$key" 2>/dev/null
}

secrets::set() {
    local key="$1"
    local value="$2"
    echo "$value" | pass insert -m "$PASS_PREFIX/$key"
}

secrets::exists() {
    local key="$1"
    pass show "$PASS_PREFIX/$key" &>/dev/null
}
