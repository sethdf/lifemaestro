#!/usr/bin/env bash
# LifeMaestro Installer
# Does NOT use set -e - handles errors gracefully per tool

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${MAESTRO_ROOT:-$HOME/.config/lifemaestro}"
FAILED_TOOLS=""

# Logging helpers
log() { echo "[$(date '+%H:%M:%S')] $*"; }
log_success() { log "✓ $*"; }
log_error() { log "✗ $*"; FAILED_TOOLS="$FAILED_TOOLS $1"; }
log_skip() { log "○ $* (already installed)"; }

echo ""
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

# Install jq (JSON processor)
if ! command -v jq &>/dev/null; then
    echo "  Installing jq..."
    JQ_VERSION=$(curl -s "https://api.github.com/repos/jqlang/jq/releases/latest" | grep '"tag_name"' | sed -E 's/.*"jq-([^"]+)".*/\1/')
    case "$PLATFORM" in
        linux-amd64)  JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" ;;
        linux-arm64)  JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-arm64" ;;
        darwin-amd64) JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-macos-amd64" ;;
        darwin-arm64) JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-macos-arm64" ;;
        *) echo "    Unsupported platform for jq: $PLATFORM"; JQ_URL="" ;;
    esac
    if [[ -n "$JQ_URL" ]]; then
        curl -fsSL "$JQ_URL" -o "$BIN_DIR/jq"
        chmod +x "$BIN_DIR/jq"
        echo "    jq installed"
    fi
else
    echo "  jq already installed"
fi

# Install fzf (fuzzy finder)
if ! command -v fzf &>/dev/null; then
    echo "  Installing fzf..."
    FZF_VERSION=$(curl -s "https://api.github.com/repos/junegunn/fzf/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
    case "$PLATFORM" in
        linux-amd64)  FZF_ARCH="fzf-${FZF_VERSION}-linux_amd64" ;;
        linux-arm64)  FZF_ARCH="fzf-${FZF_VERSION}-linux_arm64" ;;
        darwin-amd64) FZF_ARCH="fzf-${FZF_VERSION}-darwin_amd64" ;;
        darwin-arm64) FZF_ARCH="fzf-${FZF_VERSION}-darwin_arm64" ;;
        *) echo "    Unsupported platform for fzf: $PLATFORM"; FZF_ARCH="" ;;
    esac
    if [[ -n "$FZF_ARCH" ]]; then
        curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${FZF_ARCH}.tar.gz" | tar xz -C "$BIN_DIR"
        echo "    fzf installed"
    fi
else
    echo "  fzf already installed"
fi

# Install gh (GitHub CLI)
if ! command -v gh &>/dev/null; then
    echo "  Installing gh..."
    GH_VERSION=$(curl -s "https://api.github.com/repos/cli/cli/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
    case "$PLATFORM" in
        linux-amd64)  GH_ARCH="gh_${GH_VERSION}_linux_amd64" ;;
        linux-arm64)  GH_ARCH="gh_${GH_VERSION}_linux_arm64" ;;
        darwin-amd64) GH_ARCH="gh_${GH_VERSION}_macOS_amd64" ;;
        darwin-arm64) GH_ARCH="gh_${GH_VERSION}_macOS_arm64" ;;
        *) echo "    Unsupported platform for gh: $PLATFORM"; GH_ARCH="" ;;
    esac
    if [[ -n "$GH_ARCH" ]]; then
        curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_ARCH}.tar.gz" | tar xz -C /tmp
        mv "/tmp/${GH_ARCH}/bin/gh" "$BIN_DIR/"
        rm -rf "/tmp/${GH_ARCH}"
        echo "    gh installed"
    fi
else
    echo "  gh already installed"
fi

# Install himalaya (email client)
if ! command -v himalaya &>/dev/null; then
    echo "  Installing himalaya..."
    HIMALAYA_VERSION=$(curl -s "https://api.github.com/repos/pimalaya/himalaya/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
    case "$PLATFORM" in
        linux-amd64)  HIMALAYA_ARCH="himalaya.x86_64-linux" ;;
        linux-arm64)  HIMALAYA_ARCH="himalaya.aarch64-linux" ;;
        darwin-amd64) HIMALAYA_ARCH="himalaya.x86_64-darwin" ;;
        darwin-arm64) HIMALAYA_ARCH="himalaya.aarch64-darwin" ;;
        *) echo "    Unsupported platform for himalaya: $PLATFORM"; HIMALAYA_ARCH="" ;;
    esac
    if [[ -n "$HIMALAYA_ARCH" ]]; then
        curl -fsSL "https://github.com/pimalaya/himalaya/releases/download/v${HIMALAYA_VERSION}/${HIMALAYA_ARCH}.tgz" | tar xz -C "$BIN_DIR"
        echo "    himalaya installed"
    fi
else
    echo "  himalaya already installed"
fi

# Install bun (JavaScript runtime)
if ! command -v bun &>/dev/null; then
    echo "  Installing bun..."
    curl -fsSL https://bun.sh/install | bash 2>/dev/null && echo "    bun installed" || echo "    bun install failed"
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
else
    echo "  bun already installed"
fi

# Install Node.js/npm if not present (needed for some npm packages)
if ! command -v npm &>/dev/null && ! command -v bun &>/dev/null; then
    echo "  Installing Node.js..."
    case "$PLATFORM" in
        linux-*)
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - 2>/dev/null && \
            sudo apt-get install -y nodejs 2>/dev/null || \
            echo "    Node.js install failed - install manually"
            ;;
        darwin-*)
            if command -v brew &>/dev/null; then
                brew install node 2>/dev/null && echo "    Node.js installed" || echo "    Node.js install failed"
            else
                echo "    Install Node.js manually or install Homebrew first"
            fi
            ;;
    esac
else
    echo "  Node.js/npm already installed"
fi

# Install Bitwarden CLI
if ! command -v bw &>/dev/null; then
    echo "  Installing Bitwarden CLI..."
    if command -v bun &>/dev/null; then
        bun install -g @bitwarden/cli 2>/dev/null && echo "    bw installed (bun)" || echo "    bw install failed"
    elif command -v npm &>/dev/null; then
        npm install -g @bitwarden/cli 2>/dev/null && echo "    bw installed (npm)" || echo "    bw install failed"
    else
        echo "    Skipping bw (npm/bun not available)"
    fi
else
    echo "  bw already installed"
fi

# Install AI CLI tools
echo ""
echo "Installing AI CLI tools..."

# Helper function for npm installs
npm_install() {
    local cmd="$1"
    local pkg="$2"
    local name="$3"

    if ! command -v "$cmd" &>/dev/null; then
        echo "  Installing $name..."
        if command -v bun &>/dev/null; then
            bun install -g "$pkg" 2>/dev/null && echo "    $cmd installed (bun)" || echo "    $cmd install failed"
        elif command -v npm &>/dev/null; then
            npm install -g "$pkg" 2>/dev/null && echo "    $cmd installed (npm)" || echo "    $cmd install failed"
        else
            echo "    Skipping $cmd (npm/bun not available)"
        fi
    else
        echo "  $cmd already installed"
    fi
}

# Claude Code (Anthropic)
npm_install "claude" "@anthropic-ai/claude-code" "Claude Code"

# Gemini CLI (Google)
npm_install "gemini" "@google/gemini-cli" "Gemini CLI"

# Codex CLI (OpenAI)
npm_install "codex" "@openai/codex" "Codex CLI"

# Aider (Python)
if ! command -v aider &>/dev/null; then
    echo "  Installing Aider..."
    if command -v pipx &>/dev/null; then
        pipx install aider-chat 2>/dev/null && echo "    aider installed (pipx)" || echo "    aider install failed"
    elif command -v pip &>/dev/null; then
        pip install --user aider-chat 2>/dev/null && echo "    aider installed (pip)" || echo "    aider install failed"
    else
        echo "    Skipping aider (pip not available)"
    fi
else
    echo "  aider already installed"
fi

# Summary
echo ""
if [[ -n "$FAILED_TOOLS" ]]; then
    log_error "Some tools failed to install:$FAILED_TOOLS"
    echo "  Re-run install.sh to retry, or install manually"
else
    log_success "All tools installed successfully"
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
echo "Optional: Install additional tools"
echo "  - Ollama (local models): curl -fsSL https://ollama.ai/install.sh | sh"
echo "  - llm (Simon Willison):  pip install llm"
echo ""
echo "Keep AI tools updated:"
echo "  ai-update              # Update all AI CLI tools"
