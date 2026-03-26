# LLU Agentic Coding

Agentic coding environment for LLU class using [Aider](https://aider.chat) + GLM-4.7-Flash on NRP.

## Quick Start

1. Log in to **https://llu-jupyter.nrp-nautilus.io** with your institutional credentials
2. Start a server (defaults: 0 GPUs, 4 cores, 16 GB RAM, Python image)
3. Open a **Terminal** in JupyterLab
4. Run:

```bash
git clone https://github.com/martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup.sh
```

5. Follow the prompts (enter your name and email for git)
6. **Restart your server once** for browser previews: File → Hub Control Panel → Stop → Start
7. Open a new terminal and start coding:

```bash
source ~/.bashrc
mkdir ~/my-project && cd ~/my-project && git init
aider
```

> **Note:** This is a private repo. See [Access Options](#access-options) below for how to grant student access.

## Access Options

### Option A: GitHub Collaborators (if students have GitHub accounts)

Add each student as a collaborator:

```bash
gh repo add-collaborator martinfrasch/llu-agentic-coding STUDENT_GITHUB_USERNAME
```

Students then clone normally with their GitHub credentials:

```bash
git clone https://github.com/martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup.sh
```

### Option B: Deploy Key (if students don't have GitHub accounts)

Generate a read-only deploy key and distribute it to students:

**Instructor setup (one-time):**

```bash
# Generate the key pair
ssh-keygen -t ed25519 -C "llu-class-deploy" -f llu_deploy_key -N ""

# Add public key to the repo (read-only)
gh repo deploy-key add llu_deploy_key.pub -R martinfrasch/llu-agentic-coding --title "LLU student access"

# Share llu_deploy_key (the private key) with students via secure channel
```

**Student one-liner:**

```bash
mkdir -p ~/.ssh && cat > ~/.ssh/llu_deploy << 'KEYEOF'
PASTE_PRIVATE_KEY_HERE
KEYEOF
chmod 600 ~/.ssh/llu_deploy && GIT_SSH_COMMAND="ssh -i ~/.ssh/llu_deploy -o StrictHostKeyChecking=no" git clone git@github.com:martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup.sh
```

The deploy key is read-only — students can clone but not push to this repo.

## What This Sets Up

| Component | Purpose |
|-----------|---------|
| **Aider** | CLI coding assistant — reads, edits, and creates files via LLM |
| **GLM-4.7-Flash** | 30B-parameter MoE LLM on a dedicated A100 GPU (in-cluster) |
| **Shell environment** | Pre-configured to connect Aider to the vLLM endpoint |
| **jupyter-server-proxy** | View web apps in your browser via JupyterHub |

The setup script automatically installs any missing dependencies (python3, pip, git, curl).

## Architecture

```
Student Terminal → Aider CLI → vLLM (http://vllm-glm-flash:8000/v1) → GLM-4.7-Flash (A100)
```

## Why Aider (not Claude Code)

This class uses **Aider** as the agentic coding harness, not Anthropic's Claude Code CLI. Here's why:

**Claude Code requires Anthropic-specific message protocols** — it sends and expects XML-structured tool calls (`<tool_use>`, `<tool_result>`) and Anthropic-specific message formatting. GLM-4.7-Flash (and other open-source models) do not produce correctly structured XML tool-call responses, which causes Claude Code's agentic loop to break with parse errors.

**Aider works with any OpenAI-compatible endpoint** — it uses a simpler `edit_format: whole` approach where the model returns complete file contents in plain text. No XML tool-call protocol is needed, so it works reliably with GLM-4.7-Flash served via vLLM's OpenAI-compatible API.

In short: Claude Code is tightly coupled to Anthropic's Claude models, while Aider is model-agnostic and works with our self-hosted open-source LLM.

## Documentation

- [Student Guide](student-guide.md) — full usage guide with examples, tips, and troubleshooting

## Infrastructure (instructor reference)

- **Model**: `zai-org/GLM-4.7-Flash` (MIT license, 30B MoE, ~3.6B active params)
- **Serving**: vLLM on NRP Nautilus (32 CPU / 256 Gi RAM / 1x A100-80GB)
- **Endpoint**: `http://vllm-glm-flash.llu-jupyter.svc.cluster.local:8000/v1`
- **Fallback**: NRP managed endpoint (`https://ellm.nrp-nautilus.io/v1`) with Qwen3
