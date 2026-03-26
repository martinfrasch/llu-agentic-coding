# LLU Agentic Coding

Agentic coding environment for LLU class on NRP. Two setups available:

| Setup | Agent | Model | Tool Calling | Best For |
|-------|-------|-------|-------------|----------|
| **Claude Code** (recommended) | Claude Code CLI | Qwen3-Coder-30B | Full agentic (file create/edit/run) | Rich coding experience |
| **Aider** (fallback) | Aider CLI | GLM-4.7-Flash | Text-based (whole file edits) | Simpler, proven reliable |

## Quick Start — Claude Code (recommended)

1. Log in to **https://llu-jupyter.nrp-nautilus.io** with your institutional credentials
2. Start a server (defaults: 0 GPUs, 4 cores, 16 GB RAM, Python image)
3. Open a **Terminal** in JupyterLab
4. Run:

```bash
git clone https://github.com/martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup-claude-code.sh
```

5. Follow the prompts (enter your name and email for git)
6. **Restart your server once** for browser previews: File → Hub Control Panel → Stop → Start
7. Open a new terminal and start coding:

```bash
source ~/.bashrc
mkdir ~/my-project && cd ~/my-project && git init
claude
```

## Quick Start — Aider (fallback)

```bash
git clone https://github.com/martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup.sh
```

Then: `source ~/.bashrc && mkdir ~/my-project && cd ~/my-project && git init && aider`

> **Note:** This is a private repo. See [Access Options](#access-options) below for how to grant student access.

## Access Options

### Option A: GitHub Collaborators (if students have GitHub accounts)

```bash
gh repo add-collaborator martinfrasch/llu-agentic-coding STUDENT_GITHUB_USERNAME
```

### Option B: Deploy Key (if students don't have GitHub accounts)

**Instructor setup (one-time):**

```bash
ssh-keygen -t ed25519 -C "llu-class-deploy" -f llu_deploy_key -N ""
gh repo deploy-key add llu_deploy_key.pub -R martinfrasch/llu-agentic-coding --title "LLU student access"
# Share llu_deploy_key (private key) with students via secure channel
```

**Student one-liner:**

```bash
mkdir -p ~/.ssh && cat > ~/.ssh/llu_deploy << 'KEYEOF'
PASTE_PRIVATE_KEY_HERE
KEYEOF
chmod 600 ~/.ssh/llu_deploy && GIT_SSH_COMMAND="ssh -i ~/.ssh/llu_deploy -o StrictHostKeyChecking=no" git clone git@github.com:martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup-claude-code.sh
```

## Architecture

```
Claude Code setup:
  Student Terminal → Claude Code CLI → vLLM Anthropic API → Qwen3-Coder-30B (A100)
                                       http://vllm-qwen3-coder:8000/v1/messages

Aider setup (fallback):
  Student Terminal → Aider CLI → vLLM OpenAI API → GLM-4.7-Flash (A100)
                                 http://vllm-glm-flash:8000/v1
```

## How Claude Code Works With Open-Source Models

Claude Code normally requires Anthropic's Claude models and an Anthropic API key. This setup requires **neither**:

- **No Anthropic account or API key needed.** The setup script sets `ANTHROPIC_API_KEY="not-needed"` — a dummy value that satisfies Claude Code's startup check. Our vLLM server doesn't validate API keys. No cost, no Anthropic subscription.
- **No OAuth login needed.** Claude Code v2.1+ tries to open a browser for Anthropic OAuth login by default. The setup script creates a shell alias that bypasses this: `ANTHROPIC_API_KEY=not-needed DISABLE_AUTOUPDATER=1 claude --model qwen3-coder`. Students just type `claude` and it works.
- **No LiteLLM proxy needed.** vLLM (v0.18+) natively implements the Anthropic Messages API at `/v1/messages`. Claude Code talks directly to vLLM and doesn't know it's hitting an open-source model.

The key is **Qwen3-Coder-30B-A3B-Instruct**, which has:
- Native tool calling with a dedicated vLLM parser (`qwen3_coder`)
- 256K context support (Claude Code needs large context for auto-compacting)
- MoE efficiency (only 3B active params per token) — fast inference on a single A100

GLM-4.7-Flash cannot be used with Claude Code because its vLLM tool-call parser has multiple open bugs that cause tool calls to silently fail. See [research report](litellm-vllm-research.md) for details.

## Documentation

- [Claude Code Student Guide](student-guide-claude-code.md) — setup, usage, examples, troubleshooting
- [Aider Student Guide](student-guide.md) — fallback setup with GLM-4.7-Flash
- [Open Model Research](litellm-vllm-research.md) — technical analysis of LiteLLM, model options, tool-call reliability

## Infrastructure (instructor reference)

### Claude Code stack (primary)
- **Model**: `Qwen/Qwen3-Coder-30B-A3B-Instruct` (Apache 2.0, 30B MoE, 3B active)
- **Serving**: vLLM 0.18.0 on NRP Nautilus (32 CPU / 256Gi RAM / 1x A100-80GB)
- **Endpoint**: `http://vllm-qwen3-coder.llu-jupyter.svc.cluster.local:8000`
- **API**: Anthropic Messages API (native vLLM) + OpenAI API
- **Tool parser**: `qwen3_coder`

### Aider stack (fallback)
- **Model**: `zai-org/GLM-4.7-Flash` (MIT, 30B MoE, 3.6B active)
- **Endpoint**: `http://vllm-glm-flash.llu-jupyter.svc.cluster.local:8000/v1`
- **Fallback**: NRP managed endpoint (`https://ellm.nrp-nautilus.io/v1`) with Qwen3
