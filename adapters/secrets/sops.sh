#!/usr/bin/env bash
# lifemaestro/adapters/secrets/sops.sh - SOPS encrypted secrets adapter

SOPS_FILE="${SOPS_FILE:-$MAESTRO_ROOT/secrets/secrets.yaml}"

secrets::get() {
    local key="$1"
    [[ -f "$SOPS_FILE" ]] || return 1
    sops -d "$SOPS_FILE" 2>/dev/null | yq -r ".$key // empty"
}

secrets::set() {
    local key="$1"
    local value="$2"

    if [[ ! -f "$SOPS_FILE" ]]; then
        echo "{}" > "$SOPS_FILE"
        sops -e -i "$SOPS_FILE"
    fi

    sops -d "$SOPS_FILE" | yq -y ".$key = \"$value\"" | sops -e /dev/stdin > "$SOPS_FILE.tmp"
    mv "$SOPS_FILE.tmp" "$SOPS_FILE"
}

secrets::exists() {
    local key="$1"
    [[ -n "$(secrets::get "$key")" ]]
}
