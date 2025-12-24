#!/usr/bin/env bash
# lifemaestro/adapters/secrets/env.sh - Environment variable secrets adapter

secrets::get() {
    local key="$1"
    echo "${!key:-}"
}

secrets::set() {
    local key="$1"
    local value="$2"
    export "$key=$value"
}

secrets::exists() {
    local key="$1"
    [[ -n "${!key:-}" ]]
}
