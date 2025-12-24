#!/usr/bin/env bash
# LifeMaestro Installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${MAESTRO_ROOT:-$HOME/.config/lifemaestro}"

echo "LifeMaestro Installer"
echo "====================="
echo ""

# Check if already installed elsewhere
if [[ -d "$INSTALL_DIR" ]] && [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    echo "LifeMaestro already installed at: $INSTALL_DIR"
    read -p "Replace with this installation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    rm -rf "$INSTALL_DIR"
fi

# Create symlink if not running from install dir
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    echo "Creating symlink: $INSTALL_DIR -> $SCRIPT_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    ln -sf "$SCRIPT_DIR" "$INSTALL_DIR"
fi

# Create state directories
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/lifemaestro"
mkdir -p "${XDG_RUNTIME_DIR:-/tmp}/maestro-$USER"

# Create config from template if not exists
if [[ ! -f "$INSTALL_DIR/config.toml" ]] || [[ ! -s "$INSTALL_DIR/config.toml" ]]; then
    if [[ -f "$SCRIPT_DIR/config.toml.example" ]]; then
        cp "$SCRIPT_DIR/config.toml.example" "$INSTALL_DIR/config.toml"
        echo "Created config.toml from template"
    fi
fi

# Detect shell and add to rc file
SHELL_NAME=$(basename "$SHELL")
RC_FILE=""

case "$SHELL_NAME" in
    bash) RC_FILE="$HOME/.bashrc" ;;
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    *)    RC_FILE="$HOME/.profile" ;;
esac

# Add to PATH and source init
SHELL_INIT='
# LifeMaestro
export MAESTRO_ROOT="$HOME/.config/lifemaestro"
export PATH="$MAESTRO_ROOT/bin:$PATH"
source "$MAESTRO_ROOT/core/init.sh" 2>/dev/null && maestro::init 2>/dev/null || true
'

if ! grep -q "MAESTRO_ROOT" "$RC_FILE" 2>/dev/null; then
    echo "$SHELL_INIT" >> "$RC_FILE"
    echo "Added LifeMaestro to $RC_FILE"
else
    echo "LifeMaestro already in $RC_FILE"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Reload your shell: source $RC_FILE"
echo "  2. Edit config: maestro config"
echo "  3. Check status: maestro status"
echo "  4. List skills: skill list"
echo ""
echo "Optional: Install AI tools"
echo "  - Claude:  npm install -g @anthropic-ai/claude-code"
echo "  - Ollama:  curl -fsSL https://ollama.ai/install.sh | sh"
echo "  - Aider:   pip install aider-chat"
echo "  - llm:     pip install llm"
