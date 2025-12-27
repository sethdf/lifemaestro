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
export PATH="$HOME/.local/bin:$HOME/go/bin:$MAESTRO_ROOT/bin:$PATH"
source "$MAESTRO_ROOT/core/init.sh" 2>/dev/null && maestro::init 2>/dev/null || true
'

if ! grep -q "MAESTRO_ROOT" "$RC_FILE" 2>/dev/null; then
    echo "$SHELL_INIT" >> "$RC_FILE"
    echo "Added LifeMaestro to $RC_FILE"
else
    echo "LifeMaestro already in $RC_FILE"
fi

# Sync vendor dependencies (if configured)
echo ""
echo "Checking vendor dependencies..."
if [[ -f "$INSTALL_DIR/vendor/sync.sh" ]]; then
    if "$INSTALL_DIR/vendor/sync.sh" sync 2>/dev/null; then
        echo "Vendor dependencies synced"
    else
        echo "Note: Configure vendor repos in vendor/vendor.yaml"
    fi
fi

# =============================================================================
# Install CLI dependencies
# =============================================================================
echo ""
echo "Installing CLI dependencies..."

# Helper: detect OS and architecture
detect_platform() {
    local os arch
    case "$(uname -s)" in
        Linux*)  os="linux" ;;
        Darwin*) os="darwin" ;;
        *)       os="unknown" ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)            arch="unknown" ;;
    esac
    echo "$os-$arch"
}

PLATFORM=$(detect_platform)
BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"

# Install Go (needed for fabric)
if ! command -v go &>/dev/null; then
    echo "  Installing Go..."
    GO_VERSION="1.23.4"
    case "$PLATFORM" in
        linux-amd64)  GO_ARCH="linux-amd64" ;;
        linux-arm64)  GO_ARCH="linux-arm64" ;;
        darwin-amd64) GO_ARCH="darwin-amd64" ;;
        darwin-arm64) GO_ARCH="darwin-arm64" ;;
        *) echo "    Unsupported platform for Go: $PLATFORM"; GO_ARCH="" ;;
    esac
    if [[ -n "$GO_ARCH" ]]; then
        curl -fsSL "https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz" | sudo tar -C /usr/local -xz 2>/dev/null || \
        curl -fsSL "https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz" | tar -C "$HOME" -xz
        if [[ -d "$HOME/go" ]]; then
            export PATH="$HOME/go/bin:$PATH"
            export GOPATH="$HOME/go"
        else
            export PATH="/usr/local/go/bin:$PATH"
        fi
        echo "    Go installed"
    fi
else
    echo "  Go already installed"
fi

# Install fabric (AI prompt patterns)
if ! command -v fabric &>/dev/null; then
    if command -v go &>/dev/null; then
        echo "  Installing fabric..."
        go install github.com/danielmiessler/fabric@latest 2>/dev/null && echo "    fabric installed" || echo "    fabric install failed"
    else
        echo "  Skipping fabric (Go not available)"
    fi
else
    echo "  fabric already installed"
fi

# Install delta (git pager)
if ! command -v delta &>/dev/null; then
    echo "  Installing delta..."
    DELTA_VERSION=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    case "$PLATFORM" in
        linux-amd64)  DELTA_ARCH="delta-${DELTA_VERSION}-x86_64-unknown-linux-musl" ;;
        linux-arm64)  DELTA_ARCH="delta-${DELTA_VERSION}-aarch64-unknown-linux-gnu" ;;
        darwin-amd64) DELTA_ARCH="delta-${DELTA_VERSION}-x86_64-apple-darwin" ;;
        darwin-arm64) DELTA_ARCH="delta-${DELTA_VERSION}-aarch64-apple-darwin" ;;
        *) echo "    Unsupported platform for delta: $PLATFORM"; DELTA_ARCH="" ;;
    esac
    if [[ -n "$DELTA_ARCH" ]]; then
        curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/${DELTA_ARCH}.tar.gz" | tar xz -C /tmp
        mv "/tmp/${DELTA_ARCH}/delta" "$BIN_DIR/"
        rm -rf "/tmp/${DELTA_ARCH}"
        echo "    delta installed"
    fi
else
    echo "  delta already installed"
fi

# Install dasel (TOML/JSON/YAML parser)
if ! command -v dasel &>/dev/null; then
    echo "  Installing dasel..."
    DASEL_VERSION=$(curl -s "https://api.github.com/repos/TomWright/dasel/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
    case "$PLATFORM" in
        linux-amd64)  DASEL_URL="https://github.com/TomWright/dasel/releases/download/v${DASEL_VERSION}/dasel_linux_amd64" ;;
        linux-arm64)  DASEL_URL="https://github.com/TomWright/dasel/releases/download/v${DASEL_VERSION}/dasel_linux_arm64" ;;
        darwin-amd64) DASEL_URL="https://github.com/TomWright/dasel/releases/download/v${DASEL_VERSION}/dasel_darwin_amd64" ;;
        darwin-arm64) DASEL_URL="https://github.com/TomWright/dasel/releases/download/v${DASEL_VERSION}/dasel_darwin_arm64" ;;
        *) echo "    Unsupported platform for dasel: $PLATFORM"; DASEL_URL="" ;;
    esac
    if [[ -n "$DASEL_URL" ]]; then
        curl -fsSL "$DASEL_URL" -o "$BIN_DIR/dasel"
        chmod +x "$BIN_DIR/dasel"
        echo "    dasel installed"
    fi
else
    echo "  dasel already installed"
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
echo "Optional: Configure PAI (Personal AI Infrastructure)"
echo "  1. Edit vendor/vendor.yaml"
echo "  2. Set your PAI repo URL under 'pai: repo:'"
echo "  3. Run: vendor sync pai"
echo "  4. Update anytime: vendor update pai"
echo ""
echo "Optional: Install additional AI tools"
echo "  - Claude:  npm install -g @anthropic-ai/claude-code"
echo "  - Ollama:  curl -fsSL https://ollama.ai/install.sh | sh"
echo "  - Aider:   pip install aider-chat"
echo "  - llm:     pip install llm"
