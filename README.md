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

## Endpoint Options

Three endpoint paths available, in order of preference:

| Endpoint | URL | Backend | When to use |
|----------|-----|---------|-------------|
| **vLLM direct** (primary) | `http://vllm-qwen3-coder:8000` | Qwen3-Coder-30B on our A100-80GB | Default — best latency, native tool calling |
| **Qwen proxy** (fallback) | `http://qwen-proxy:4000` | Qwen3.5-397B via NRP Envoy | When our A100 is unavailable (GPU shortage) |
| **LiteLLM proxy** (legacy) | `http://litellm-proxy:4000` | Qwen3.5-397B via NRP Envoy | Legacy — use qwen-proxy instead |

### Switching endpoints

```bash
# Check which endpoint you're using
echo $ANTHROPIC_BASE_URL

# Switch to qwen-proxy fallback
sed -i 's|http://vllm-qwen3-coder:8000|http://qwen-proxy:4000|' ~/.llu_env
source ~/.bashrc

# Switch back to vLLM direct
sed -i 's|http://qwen-proxy:4000|http://vllm-qwen3-coder:8000|' ~/.llu_env
source ~/.bashrc
```

### Known issues with the proxy fallback

- **Initial pause**: The Qwen3.5-397B model has a "thinking" mode that runs silently before producing visible output. Expect a 5–15 second pause before text starts streaming. This is normal.
- **Longer responses**: The 397B model is more verbose than Qwen3-Coder-30B. Responses may take longer but are often higher quality.

## Architecture

```
Claude Code setup (primary):
  Student Terminal → Claude Code CLI → vLLM Anthropic API → Qwen3-Coder-30B (A100)
                                       http://vllm-qwen3-coder:8000/v1/messages

Claude Code setup (fallback):
  Student Terminal → Claude Code CLI → qwen-proxy → NRP Envoy → Qwen3.5-397B (shared)
                                       http://qwen-proxy:4000/v1/messages
  The proxy rewrites max_tokens, strips reasoning tokens, and translates
  Anthropic Messages API ↔ OpenAI Chat Completions API.

Aider setup (fallback):
  Student Terminal → Aider CLI → vLLM OpenAI API → GLM-4.7-Flash (A100)
                                 http://vllm-glm-flash:8000/v1
```

## How Claude Code Works With Open-Source Models

Claude Code normally requires Anthropic's Claude models and an Anthropic API key. This setup requires **neither**:

- **No Anthropic account or API key needed.** The setup script sets `ANTHROPIC_API_KEY="not-needed"` — a dummy value that satisfies Claude Code's startup check. Our vLLM server doesn't validate API keys. No cost, no Anthropic subscription.
- **No OAuth login needed.** Claude Code v2.1+ normally requires Anthropic OAuth login. The setup script pre-seeds `~/.claude.json` with `hasCompletedOnboarding: true` and pre-approved API key, bypassing the login flow entirely ([issue #27900](https://github.com/anthropics/claude-code/issues/27900)). Students just type `claude` and it works.
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
- **Serving**: vLLM v0.18.1 on NRP Nautilus (8 CPU / 32Gi RAM / 1x A100-80GB)
- **Image**: `vllm/vllm-openai:v0.18.1` (pinned — do NOT use `:latest`, v0.19.0 has a hang bug with this model)
- **Endpoint**: `http://vllm-qwen3-coder.llu-jupyter.svc.cluster.local:8000`
- **API**: Anthropic Messages API (native vLLM) + OpenAI API
- **Tool parser**: `qwen3_coder`
- **Node selector**: `nvidia.com/gpu.memory: "81920"` (80GB A100 only — model is ~60GB)
- **Toleration**: `nautilus.io/reservation: mizzou` (required since April 2026)
- **Manifest**: `k8s/6-vllm-qwen3-coder-deployment.yaml`

### Qwen proxy (fallback when A100-80GB unavailable)
- **What**: Custom Python proxy translating Anthropic Messages API → OpenAI Chat Completions
- **Backend**: NRP shared Envoy → `Qwen/Qwen3.5-397B-A17B-FP8`
- **Endpoint**: `http://qwen-proxy.llu-jupyter.svc.cluster.local:4000`
- **Key behaviors**:
  - Rewrites `max_tokens` to minimum 16384 (Qwen3.5 thinking mode needs headroom — with low max_tokens, all tokens go to reasoning and content is empty)
  - Strips reasoning/thinking tokens from streaming responses
  - No `thinking` content block sent to Claude Code (avoids display glitch)
- **Resources**: 500m CPU / 256Mi RAM (no GPU needed)
- **Manifest**: `k8s/8-qwen-proxy-deployment.yaml`
- **Auth**: Requires `NRP_LLM_TOKEN` env var for the Envoy endpoint

### Aider stack (fallback)
- **Model**: `zai-org/GLM-4.7-Flash` (MIT, 30B MoE, 3.6B active)
- **Endpoint**: `http://vllm-glm-flash.llu-jupyter.svc.cluster.local:8000/v1`
- **Fallback**: NRP managed endpoint (`https://ellm.nrp-nautilus.io/v1`) with Qwen3

### Lessons learned (April 2026)

1. **Pin vLLM image tags.** `:latest` auto-upgraded from v0.18.0 to v0.19.0 during a pod restart, causing the EngineCore to hang in D-state after loading the model. Pin to a specific version (e.g., `v0.18.1`).
2. **Node-select for 80GB GPUs.** The model needs ~60GB VRAM. If Kubernetes schedules on a 40GB A100, you get an immediate OOM. Use `nvidia.com/gpu.memory: "81920"` as a nodeSelector.
3. **Tolerate reservation taints.** NRP nodes can acquire reservation taints (e.g., `nautilus.io/reservation: mizzou`) while your pod is running. The running pod is grandfathered, but after a restart it can't reschedule without the toleration.
4. **npm global installs are ephemeral on JupyterHub.** If `node` was installed via conda, `npm install -g` lands in `/opt/conda/` which is wiped on server restart. Fix: `npm install -g --prefix="$HOME/.local" @anthropic-ai/claude-code`.
5. **Qwen3.5 thinking mode.** All models on the NRP Envoy have server-side thinking/reasoning enabled. This can't be disabled from the client. Workaround: set a high `max_tokens` (16384+) so reasoning completes and actual content is generated. Our `qwen-proxy` handles this automatically.
