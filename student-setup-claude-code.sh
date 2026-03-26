#!/usr/bin/env bash
# LLU Class - Claude Code + Qwen3-Coder Setup
# Run on your NRP JupyterHub terminal:
#   git clone https://github.com/martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup-claude-code.sh
#
# This sets up Claude Code CLI pointing at a self-hosted Qwen3-Coder-30B
# model served via vLLM with native Anthropic API compatibility.

set -euo pipefail

# --- Configuration ---
VLLM_URL="http://vllm-qwen3-coder:8000"
MODEL_NAME="qwen3-coder"

echo "==========================================="
echo "  LLU Class - Claude Code Setup"
echo "==========================================="
echo ""

# --- Helper: install a system package if missing ---
ensure_installed() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    echo "  $cmd not found, installing $pkg..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq >/dev/null 2>&1 || true
        sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1 || {
            apt-get update -qq >/dev/null 2>&1 || true
            apt-get install -y -qq "$pkg" >/dev/null 2>&1 || {
                echo "  ERROR: Could not install $pkg."
                return 1
            }
        }
    elif command -v conda >/dev/null 2>&1; then
        conda install -y -q "$pkg" >/dev/null 2>&1 || {
            echo "  ERROR: Could not install $pkg via conda."
            return 1
        }
    else
        echo "  ERROR: No package manager found. Please install $pkg manually."
        return 1
    fi
}

# --- Step 1: Dependencies ---
echo "[1/5] Checking and installing dependencies..."
ensure_installed git git
ensure_installed curl curl
ensure_installed node nodejs || ensure_installed node node || true

# Install Claude Code via npm
if command -v node >/dev/null 2>&1; then
    echo "  Node.js: $(node --version 2>&1)"
else
    echo "  Installing Node.js..."
    if command -v apt-get >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash - 2>/dev/null || \
            curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 2>/dev/null || true
        sudo apt-get install -y -qq nodejs 2>/dev/null || apt-get install -y -qq nodejs 2>/dev/null || true
    elif command -v conda >/dev/null 2>&1; then
        conda install -y -q -c conda-forge nodejs 2>/dev/null || true
    fi
    if ! command -v node >/dev/null 2>&1; then
        echo "  ERROR: Could not install Node.js. Please install manually."
        exit 1
    fi
    echo "  Node.js: $(node --version 2>&1)"
fi

# --- Step 2: Install Claude Code CLI ---
echo ""
echo "[2/5] Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code 2>&1 | tail -3
if command -v claude >/dev/null 2>&1; then
    echo "  Claude Code: $(claude --version 2>&1 | head -1)"
else
    # Try with npx path
    export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
    if command -v claude >/dev/null 2>&1; then
        echo "  Claude Code: $(claude --version 2>&1 | head -1)"
    else
        echo "  WARNING: claude not found on PATH. Try: npx @anthropic-ai/claude-code"
    fi
fi

# --- Step 3: Configure git ---
echo ""
echo "[3/5] Configuring git..."
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    if [ -t 0 ]; then
        read -rp "  Enter your name (for git commits): " GIT_NAME
        git config --global user.name "$GIT_NAME"
    else
        echo "  WARNING: git user.name not set. Run: git config --global user.name \"Your Name\""
    fi
fi
if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
    if [ -t 0 ]; then
        read -rp "  Enter your email (for git commits): " GIT_EMAIL
        git config --global user.email "$GIT_EMAIL"
    else
        echo "  WARNING: git user.email not set. Run: git config --global user.email \"you@example.edu\""
    fi
fi
GIT_USER=$(git config --global user.name 2>/dev/null || echo "(not set)")
GIT_MAIL=$(git config --global user.email 2>/dev/null || echo "(not set)")
echo "  Git user: $GIT_USER <$GIT_MAIL>"

# --- Step 4: Configure Claude Code environment ---
echo ""
echo "[4/5] Setting up Claude Code environment..."
ENV_FILE="$HOME/.llu_env"
cat > "$ENV_FILE" << ENVEOF
# LLU Class - Claude Code + Qwen3-Coder Environment
export PATH="\$HOME/.local/bin:\$HOME/.npm-global/bin:/usr/local/bin:\$PATH"

# Point Claude Code at in-cluster vLLM (Anthropic-compatible API)
export ANTHROPIC_BASE_URL="$VLLM_URL"
export ANTHROPIC_API_KEY="not-needed"

# Map all Claude model slots to our Qwen3-Coder
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL_NAME"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL_NAME"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL_NAME"
ENVEOF

# Add to .bashrc if not already there
SHELL_RC="$HOME/.bashrc"
[ ! -f "$SHELL_RC" ] && touch "$SHELL_RC"
if ! grep -q "llu_env" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# LLU Class agentic coding environment" >> "$SHELL_RC"
    echo '[ -f ~/.llu_env ] && source ~/.llu_env' >> "$SHELL_RC"
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
echo "  Environment written to $ENV_FILE"

# --- Step 5: Smoke test ---
echo ""
echo "[5/5] Running smoke test..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "$VLLM_URL/health" 2>/dev/null) || HTTP_CODE="000"

if [ "$HTTP_CODE" = "200" ]; then
    echo "  vLLM endpoint: OK ($VLLM_URL)"
else
    echo "  WARNING: vLLM returned HTTP $HTTP_CODE"
    echo "           The model may still be loading. Try again in a few minutes."
fi

# Test Anthropic Messages API
MODELS_RESPONSE=$(curl -s --max-time 10 "$VLLM_URL/v1/models" 2>/dev/null) || true
if echo "$MODELS_RESPONSE" | grep -q "$MODEL_NAME"; then
    echo "  Model:        $MODEL_NAME available"
else
    echo "  WARNING: Model $MODEL_NAME not found in endpoint response"
fi

# --- Done ---
echo ""
echo "==========================================="
echo "  Setup complete!"
echo ""
echo "  To start coding:"
echo "    source ~/.bashrc"
echo "    mkdir ~/my-project && cd ~/my-project && git init"
echo "    claude"
echo ""
echo "  Every new terminal, run: source ~/.bashrc"
echo "  Claude Code uses Qwen3-Coder-30B via the"
echo "  in-cluster vLLM Anthropic API."
echo "==========================================="
