#!/usr/bin/env bash
# lifemaestro/adapters/ai/ollama.sh - Ollama adapter

OLLAMA_MODEL="${OLLAMA_MODEL:-$(maestro::config 'ai.ollama.default_model' 'llama3.2')}"

ai::available() {
    command -v ollama &>/dev/null && keepalive::check_ollama
}

ai::chat() {
    ollama run "$OLLAMA_MODEL" "$@"
}

ai::ask() {
    local question="$1"
    echo "$question" | ollama run "$OLLAMA_MODEL"
}

ai::stream() {
    local message="$1"
    echo "$message" | ollama run "$OLLAMA_MODEL"
}
