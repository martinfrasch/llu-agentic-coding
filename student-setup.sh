#!/usr/bin/env bash
# LLU Class - Agentic Coding Environment Setup
# Run on your NRP JupyterHub terminal:
#   curl -sSL https://raw.githubusercontent.com/martinfrasch/llu-agentic-coding/main/student-setup.sh | bash
#
# What it does:
#   1. Installs aider-chat and flask
#   2. Configures GLM-4.7-Flash model settings
#   3. Sets up shell environment for the in-cluster vLLM endpoint
#   4. Installs jupyter-server-proxy for browser previews
#   5. Runs a smoke test to verify everything works

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

# --- Check prerequisites ---
echo "[1/6] Checking prerequisites..."
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found."; exit 1; }
command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1 || { echo "ERROR: pip not found."; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found."; exit 1; }
PIP_CMD=$(command -v pip || command -v pip3)
echo "  Python: $(python3 --version 2>&1 | awk '{print $2}')"
echo "  Git:    $(git --version 2>&1 | awk '{print $3}')"

# --- Install packages ---
echo ""
echo "[2/6] Installing aider-chat and flask..."
$PIP_CMD install --user --quiet aider-chat flask 2>&1 | tail -1
echo "  Done."

# --- Configure git (prompt for name/email if not set) ---
echo ""
echo "[3/6] Configuring git..."
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    read -rp "  Enter your name (for git commits): " GIT_NAME
    git config --global user.name "$GIT_NAME"
fi
if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
    read -rp "  Enter your email (for git commits): " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi
echo "  Git user: $(git config --global user.name) <$(git config --global user.email)>"

# --- Configure aider model settings ---
echo ""
echo "[4/6] Configuring model settings..."
cat > ~/.aider.model.settings.yml << 'MODELEOF'
- name: openai/glm-4.7-flash
  reasoning_tag: think
  edit_format: whole
MODELEOF
echo "  Model config written to ~/.aider.model.settings.yml"

# --- Set up shell environment ---
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
if ! grep -q "llu_env" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# LLU Class agentic coding environment" >> "$SHELL_RC"
    echo '[ -f ~/.llu_env ] && source ~/.llu_env' >> "$SHELL_RC"
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
echo "  Environment written to $ENV_FILE and sourced in $SHELL_RC"

# --- Install jupyter-server-proxy for browser previews ---
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
    echo "              The vLLM server may be loading. Try again in a few minutes."
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
