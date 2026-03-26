#!/usr/bin/env bash
# LLU Class - Agentic Coding Environment Setup
# Run on your NRP JupyterHub terminal:
#   curl -sSL https://raw.githubusercontent.com/martinfrasch/llu-agentic-coding/main/student-setup.sh | bash
#
# What it does:
#   1. Checks and installs missing dependencies (python3, pip, git, curl)
#   2. Installs aider-chat and flask
#   3. Configures GLM-4.7-Flash model settings
#   4. Sets up shell environment for the in-cluster vLLM endpoint
#   5. Installs jupyter-server-proxy for browser previews
#   6. Runs a smoke test to verify everything works
#
# Supported: Ubuntu/Debian on NRP JupyterHub or standalone instances.

set -euo pipefail

# --- Configuration ---
VLLM_URL="http://vllm-glm-flash:8000/v1"
MODEL="openai/glm-4.7-flash"
FALLBACK_URL="https://ellm.nrp-nautilus.io/v1"
FALLBACK_MODEL="openai/qwen3"

echo "==========================================="
echo "  LLU Agentic Coding - Environment Setup"
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
            # Try without sudo (JupyterHub containers may allow apt without sudo)
            apt-get update -qq >/dev/null 2>&1 || true
            apt-get install -y -qq "$pkg" >/dev/null 2>&1 || {
                echo "  ERROR: Could not install $pkg. Please install manually: apt-get install $pkg"
                return 1
            }
        }
    elif command -v conda >/dev/null 2>&1; then
        conda install -y -q "$pkg" >/dev/null 2>&1 || {
            echo "  ERROR: Could not install $pkg via conda. Please install manually."
            return 1
        }
    else
        echo "  ERROR: No package manager found (apt-get or conda). Please install $pkg manually."
        return 1
    fi
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  Installed $pkg."
    else
        echo "  ERROR: $pkg installed but $cmd still not found."
        return 1
    fi
}

# --- Step 1: Check and install dependencies ---
echo "[1/6] Checking and installing dependencies..."

ensure_installed python3 python3
ensure_installed git git
ensure_installed curl curl

# pip may be pip or pip3 depending on the environment
if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
    echo "  pip not found, installing python3-pip..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y -qq python3-pip >/dev/null 2>&1 || \
            apt-get install -y -qq python3-pip >/dev/null 2>&1 || true
    fi
    # If still missing, try ensurepip
    if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
        python3 -m ensurepip --user 2>/dev/null || true
    fi
    if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
        echo "  ERROR: Could not install pip. Please install manually."
        exit 1
    fi
fi
PIP_CMD=$(command -v pip 2>/dev/null || command -v pip3)

echo "  Python: $(python3 --version 2>&1 | awk '{print $2}')"
echo "  pip:    $($PIP_CMD --version 2>&1 | awk '{print $2}')"
echo "  Git:    $(git --version 2>&1 | awk '{print $3}')"
echo "  curl:   $(curl --version 2>&1 | head -1 | awk '{print $2}')"

# --- Step 2: Install Python packages ---
echo ""
echo "[2/6] Installing aider-chat and flask..."
$PIP_CMD install --user --quiet aider-chat flask 2>&1 | tail -1

# Ensure ~/.local/bin is on PATH for the rest of this script
export PATH="$HOME/.local/bin:$PATH"

if command -v aider >/dev/null 2>&1; then
    echo "  aider $(aider --version 2>&1) installed."
else
    echo "  WARNING: aider installed but not on PATH yet."
    echo "           Will be available after sourcing ~/.bashrc"
fi

# --- Step 3: Configure git ---
echo ""
echo "[3/6] Configuring git..."
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

# --- Step 4: Configure aider model settings ---
echo ""
echo "[4/6] Configuring model settings..."
cat > ~/.aider.model.settings.yml << 'MODELEOF'
- name: openai/glm-4.7-flash
  reasoning_tag: think
  edit_format: whole
MODELEOF
echo "  Written to ~/.aider.model.settings.yml"

# --- Step 5: Set up shell environment ---
echo ""
echo "[5/6] Setting up shell environment..."
ENV_FILE="$HOME/.llu_env"
cat > "$ENV_FILE" << ENVEOF
# LLU Class - Agentic Coding Environment
export PATH="\$HOME/.local/bin:\$PATH"
export OPENAI_API_BASE="$VLLM_URL"
export OPENAI_API_KEY="not-needed"
export AIDER_MODEL="$MODEL"
export AIDER_FLAGS="--no-show-model-warnings --no-auto-commits"
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
echo "  Environment written to $ENV_FILE and sourced in $SHELL_RC"

# --- Step 6: Install jupyter-server-proxy for browser previews ---
echo ""
echo "[6/6] Installing jupyter-server-proxy..."
if command -v jupyter >/dev/null 2>&1; then
    $PIP_CMD install --quiet jupyter-server-proxy 2>&1 | tail -1
    jupyter server extension enable jupyter_server_proxy 2>/dev/null || true
    echo "  Installed. Restart your server once for browser previews to work:"
    echo "  File -> Hub Control Panel -> Stop My Server -> Start My Server"
else
    echo "  Skipped (jupyter not found - not running on JupyterHub?)"
fi

# --- Smoke test ---
echo ""
echo "Running smoke test..."

# Test endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "$VLLM_URL/models" 2>/dev/null) || HTTP_CODE="000"

if [ "$HTTP_CODE" = "200" ]; then
    echo "  Endpoint:   OK ($VLLM_URL)"
else
    echo "  WARNING:    Endpoint returned HTTP $HTTP_CODE"
    echo "              The vLLM server may still be loading. Try again in a few minutes."
    echo "              Fallback: export OPENAI_API_BASE=\"$FALLBACK_URL\""
fi

# Test aider
AIDER_BIN=$(command -v aider 2>/dev/null || echo "$HOME/.local/bin/aider")
if [ -x "$AIDER_BIN" ]; then
    echo "  Aider:      $($AIDER_BIN --version 2>&1)"
    if [ "$HTTP_CODE" = "200" ]; then
        RESULT=$("$AIDER_BIN" --model "$MODEL" --no-git --no-show-model-warnings \
            --message "Respond with exactly one word: WORKING" --yes 2>&1) || true
        if echo "$RESULT" | grep -qi "WORKING"; then
            echo "  Smoke test: PASSED"
        else
            echo "  Smoke test: Model responded but output was unexpected."
            echo "              This is OK - the connection works. Try: aider"
        fi
    fi
else
    echo "  WARNING: aider not found at $AIDER_BIN"
    echo "           Try: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# --- Done ---
echo ""
echo "==========================================="
echo "  Setup complete!"
echo ""
echo "  To start coding:"
echo "    source ~/.bashrc"
echo "    mkdir ~/my-project && cd ~/my-project && git init"
echo "    aider"
echo ""
echo "  Every new terminal, run: source ~/.bashrc"
echo "  For help inside aider:   /help"
echo "==========================================="
