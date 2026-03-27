#!/usr/bin/env bash
# LLU Class - Claude Code + Qwen3-Coder Setup
# Run on your NRP JupyterHub terminal:
#   git clone https://github.com/martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup-claude-code.sh
#
# This sets up Claude Code CLI pointing at a self-hosted Qwen3-Coder-30B
# model served via vLLM with native Anthropic API compatibility.
# No Anthropic account or API key needed.

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

# Ensure Node.js is available
if ! command -v node >/dev/null 2>&1; then
    echo "  Node.js not found, installing..."
    if command -v conda >/dev/null 2>&1; then
        conda install -y -q -c conda-forge nodejs 2>&1 | tail -1
    elif command -v apt-get >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash - 2>/dev/null || \
            curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 2>/dev/null || true
        sudo apt-get install -y -qq nodejs 2>/dev/null || apt-get install -y -qq nodejs 2>/dev/null || true
    fi
    if ! command -v node >/dev/null 2>&1; then
        echo "  ERROR: Could not install Node.js. Please install manually."
        exit 1
    fi
fi
echo "  Node.js: $(node --version 2>&1)"
echo "  npm:     $(npm --version 2>&1)"

# --- Step 2: Install Claude Code CLI ---
echo ""
echo "[2/5] Installing Claude Code CLI..."

# Try global install first, then user-prefix fallback
INSTALL_LOG=$(mktemp)
CLAUDE_INSTALLED=false

# Attempt 1: global install
if npm install -g @anthropic-ai/claude-code >"$INSTALL_LOG" 2>&1; then
    if command -v claude >/dev/null 2>&1; then
        CLAUDE_INSTALLED=true
    fi
fi

# Attempt 2: user-prefix install (if global failed or claude not on PATH)
if [ "$CLAUDE_INSTALLED" = false ]; then
    echo "  Global install failed or claude not on PATH, trying user install..."
    mkdir -p "$HOME/.local"
    if npm install --prefix "$HOME/.local" @anthropic-ai/claude-code >"$INSTALL_LOG" 2>&1; then
        export PATH="$HOME/.local/bin:$PATH"
        if command -v claude >/dev/null 2>&1; then
            CLAUDE_INSTALLED=true
        fi
    fi
fi

# Attempt 3: npx as last resort
if [ "$CLAUDE_INSTALLED" = false ]; then
    echo "  User install also failed, trying npx..."
    if npx --yes @anthropic-ai/claude-code --version >/dev/null 2>&1; then
        echo "  Claude Code available via npx (run with: npx @anthropic-ai/claude-code)"
        CLAUDE_INSTALLED=true
    fi
fi

if [ "$CLAUDE_INSTALLED" = true ] && command -v claude >/dev/null 2>&1; then
    echo "  Claude Code $(claude --version 2>&1 | head -1) installed."
elif [ "$CLAUDE_INSTALLED" = true ]; then
    echo "  Claude Code installed (available via npx)."
else
    echo ""
    echo "  ERROR: Claude Code installation failed."
    echo "  Install log:"
    cat "$INSTALL_LOG"
    echo ""
    echo "  Try manually: npm install -g @anthropic-ai/claude-code"
    rm -f "$INSTALL_LOG"
    exit 1
fi
rm -f "$INSTALL_LOG"

# --- Step 3: Bypass Claude Code OAuth login ---
# Claude Code v2.1+ requires OAuth login for interactive mode even with
# ANTHROPIC_API_KEY set. Pre-seeding ~/.claude.json skips this entirely.
# See: https://github.com/anthropics/claude-code/issues/27900
echo ""
echo "[3/7] Configuring Claude Code auth bypass..."
mkdir -p ~/.claude
cat > ~/.claude.json << 'AUTHEOF'
{
  "hasCompletedOnboarding": true,
  "primaryApiKey": "not-needed",
  "customApiKeyResponses": {
    "approved": ["not-needed"],
    "rejected": []
  }
}
AUTHEOF
echo "  Auth bypass configured (~/.claude.json)"

# --- Step 4: Configure git ---
echo ""
echo "[4/7] Configuring git..."
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
echo "[5/7] Setting up Claude Code environment..."

# Find where claude was installed and ensure it's on PATH
CLAUDE_DIR=$(dirname "$(command -v claude 2>/dev/null)" 2>/dev/null || echo "")

ENV_FILE="$HOME/.llu_env"
cat > "$ENV_FILE" << ENVEOF
# LLU Class - Claude Code + Qwen3-Coder Environment
# No Anthropic account or API key needed — ANTHROPIC_API_KEY is a dummy value.
# vLLM doesn't validate it; Claude Code just requires it to be set.
export PATH="\$HOME/.local/bin:\$HOME/.npm-global/bin:/usr/local/bin:/opt/conda/bin:\$PATH"

# Point Claude Code at in-cluster vLLM (Anthropic-compatible API)
export ANTHROPIC_BASE_URL="$VLLM_URL"
export ANTHROPIC_API_KEY="not-needed"
export DISABLE_AUTOUPDATER=1

# Map all Claude model slots to our Qwen3-Coder
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL_NAME"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL_NAME"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL_NAME"

# Convenience alias: launch claude with correct model (bypasses OAuth login)
alias claude="ANTHROPIC_API_KEY=not-needed DISABLE_AUTOUPDATER=1 claude --model $MODEL_NAME"

# Browser preview URL (if running on JupyterHub)
if [ -n "\${JUPYTERHUB_USER:-}" ]; then
    export LLU_PROXY_URL="https://llu-jupyter.nrp-nautilus.io/user/\${JUPYTERHUB_USER}/proxy"
fi
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

# --- Step 5: Install jupyter-server-proxy for browser previews ---
echo ""
echo "[6/7] Installing jupyter-server-proxy for browser previews..."
if command -v jupyter >/dev/null 2>&1; then
    JUPYTER_DIR=$(dirname "$(command -v jupyter)")
    JUPYTER_PIP=""
    if [ -x "$JUPYTER_DIR/pip" ]; then
        JUPYTER_PIP="$JUPYTER_DIR/pip"
    elif [ -x "/opt/conda/bin/pip" ]; then
        JUPYTER_PIP="/opt/conda/bin/pip"
    fi

    if [ -n "$JUPYTER_PIP" ]; then
        $JUPYTER_PIP install --quiet jupyter-server-proxy 2>&1 | tail -1
        jupyter server extension enable jupyter_server_proxy 2>/dev/null || true
        if jupyter server extension list 2>&1 | grep -q "jupyter_server_proxy"; then
            echo "  jupyter-server-proxy: installed and enabled"
        else
            echo "  WARNING: installed but not detected — try restarting your server"
        fi
    else
        echo "  WARNING: could not find jupyter's pip"
    fi
    echo ""
    echo "  *** Restart your server once for browser previews to work ***"
    echo "  File -> Hub Control Panel -> Stop My Server -> Start My Server"
else
    echo "  Skipped (jupyter not found)"
fi

# --- Step 6: Verify everything works ---
echo ""
echo "[7/7] Verifying installation..."

# Check claude is on PATH
ERRORS=0
if command -v claude >/dev/null 2>&1; then
    echo "  claude CLI:   $(claude --version 2>&1 | head -1)"
else
    echo "  ERROR: claude not found on PATH after install"
    ERRORS=$((ERRORS + 1))
fi

# Check endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "$VLLM_URL/health" 2>/dev/null) || HTTP_CODE="000"

if [ "$HTTP_CODE" = "200" ]; then
    echo "  vLLM endpoint: OK ($VLLM_URL)"
else
    echo "  WARNING: vLLM returned HTTP $HTTP_CODE (model may still be loading)"
fi

# Check model is available
MODELS_RESPONSE=$(curl -s --max-time 10 "$VLLM_URL/v1/models" 2>/dev/null) || true
if echo "$MODELS_RESPONSE" | grep -q "$MODEL_NAME"; then
    echo "  Model:         $MODEL_NAME available"
else
    echo "  WARNING: Model $MODEL_NAME not found (vLLM may still be loading)"
fi

# Check env vars
if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
    echo "  ANTHROPIC_BASE_URL: $ANTHROPIC_BASE_URL"
else
    echo "  ERROR: ANTHROPIC_BASE_URL not set"
    ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "  $ERRORS error(s) detected. Please fix before continuing."
    exit 1
fi

# --- Build proxy URL for browser preview ---
PROXY_BASE=""
if [ -n "${JUPYTERHUB_USER:-}" ]; then
    PROXY_BASE="https://llu-jupyter.nrp-nautilus.io/user/${JUPYTERHUB_USER}/proxy"
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
echo "  Then just type 'claude' — the alias handles"
echo "  model selection and skips Anthropic login."
echo "  No Anthropic account or API key needed."
if [ -n "$PROXY_BASE" ]; then
    echo ""
    echo "  ┌─────────────────────────────────────────┐"
    echo "  │  BROWSER PREVIEW (open this tab now!)    │"
    echo "  │                                          │"
    echo "  │  ${PROXY_BASE}/8080/  │"
    echo "  └─────────────────────────────────────────┘"
    echo ""
    echo "  Open the URL above in a new browser tab."
    echo "  When your Flask app runs on port 8080,"
    echo "  just switch to that tab to see it live."
    echo "  (For other ports, change 8080 in the URL.)"
fi
echo "==========================================="
