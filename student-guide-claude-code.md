# Agentic Coding with Claude Code on NRP

## What you're using

**Claude Code** is Anthropic's official CLI coding agent. It connects to a Qwen3-Coder-30B model running on NRP's GPU cluster and can read, edit, create files, run commands, and manage your project — all from the terminal.

No Anthropic account or API key needed — everything runs on our self-hosted infrastructure.

## Getting started

1. Go to **https://llu-jupyter.nrp-nautilus.io**
2. Log in with your institutional credentials (CILogon)
3. On the Server Options page, use the defaults (0 GPUs, 4 cores, 16 GB RAM) and select the **Python** image. Click **Start**.
4. In JupyterLab, click **Terminal**

## Setup (one-time)

Run this single command in your JupyterHub terminal:

```bash
git clone https://github.com/martinfrasch/llu-agentic-coding.git /tmp/llu-setup && bash /tmp/llu-setup/student-setup-claude-code.sh
```

This installs Claude Code CLI, configures authentication (no Anthropic account needed), connects to the in-cluster Qwen3-Coder model, and installs browser preview support.

After setup, **restart your server once**: File → Hub Control Panel → Stop My Server → Start My Server. This activates `jupyter-server-proxy` for browser previews. The setup script creates a startup hook that automatically reinstalls it on each restart (the conda environment is ephemeral).

## Daily usage

Every time you open a new terminal:

```bash
source ~/.bashrc
cd your-project
claude
```

No Anthropic account needed — the setup script pre-configures authentication to use the in-cluster model.

If you don't have a project yet:

```bash
source ~/.bashrc
mkdir ~/my-project && cd ~/my-project && git init
claude
```

> **Note:** If `claude` shows "Not logged in" or tries to open a browser, run `source ~/.bashrc` first. If the problem persists, re-run the setup script.

## Model info

| Property | Value |
|----------|-------|
| Model (primary) | Qwen3-Coder-30B-A3B-Instruct |
| Model (fallback) | Qwen3.5-397B via NRP shared Envoy |
| Architecture | 30B MoE (3B active) / 397B MoE (17B active) |
| Context | 65K tokens |
| Endpoint (primary) | `http://vllm-qwen3-coder:8000` (in-cluster, no auth needed) |
| Endpoint (fallback) | `http://qwen-proxy:4000` (in-cluster, no auth needed) |
| API | Anthropic Messages API |
| Tool calling | Yes — full agentic file creation, editing, commands |

### Switching to the fallback endpoint

If the primary model is unavailable (timeout errors, connection refused), switch to the fallback:

```bash
sed -i 's|http://vllm-qwen3-coder:8000|http://qwen-proxy:4000|' ~/.llu_env
source ~/.bashrc
claude
```

To switch back when the primary is restored:

```bash
sed -i 's|http://qwen-proxy:4000|http://vllm-qwen3-coder:8000|' ~/.llu_env
source ~/.bashrc
```

The fallback uses a larger model (Qwen3.5-397B) on shared NRP infrastructure. You'll notice a **5–15 second pause** before responses start streaming — this is the model's internal reasoning step and is normal.

## What Claude Code can do

Unlike simpler coding assistants, Claude Code is a full **agentic** tool:

- **Read files** — understands your project structure automatically
- **Create files** — generates new files with correct content
- **Edit files** — makes targeted changes to existing code
- **Run commands** — executes shell commands and reads output
- **Multi-step tasks** — chains multiple operations to complete complex requests

### Example session

```
$ source ~/.bashrc
$ cd ~/my-project
$ claude

> Create a Flask app with /health and /api/greet/<name> endpoints

# Claude Code creates app.py with the complete implementation

> Add input validation to the greet endpoint — return 400 if name contains numbers

# Claude Code reads app.py, makes targeted edits, shows you the diff

> Run the app and test the endpoints with curl

# Claude Code runs flask, opens another terminal, tests with curl, shows results
```

### Useful flags

| Flag | What it does |
|------|-------------|
| `claude` | Start interactive session |
| `claude -p "prompt"` | One-shot: run a single prompt and exit |
| `claude --model qwen3-coder` | Explicitly set model (usually auto-configured) |

## Viewing your web app in the browser

### Step 1: Start your app on port 8080

Open a **second terminal** in JupyterLab and run:

```bash
source ~/.bashrc
cd ~/my-project
python3 -m flask run --host=0.0.0.0 --port=8080
```

**Important:** You must use `--host=0.0.0.0` (not localhost/127.0.0.1), otherwise the proxy can't reach your app.

### Step 2: Find your proxy URL

Your URL follows this pattern:

```
https://llu-jupyter.nrp-nautilus.io/user/YOUR-EMAIL/proxy/8080/
```

Use your **email as shown in the JupyterLab URL bar** — for example:

```
https://llu-jupyter.nrp-nautilus.io/user/mfrasch@uw.edu/proxy/8080/
```

**Tip:** Look at your browser's URL bar while in JupyterLab — the part after `/user/` is exactly what you need.

### Step 3: Open it

Open the proxy URL in a new browser tab. Keep it open — whenever you update your app, just refresh the tab.

### Port tips

- **Use port 8080** (not 5000) — port 5000 can conflict with other processes on JupyterHub
- If port 8080 is in use, try 8081, 8082, etc.
- Kill a stuck process: `pkill -f "flask run"` then restart

### Common issues

| Problem | Fix |
|---------|-----|
| **404 Not Found** | `jupyter-server-proxy` not active — restart your server (File → Hub Control Panel → Stop → Start) |
| **504 Gateway Timeout** | Your app isn't running or isn't bound to `0.0.0.0` — restart with `--host=0.0.0.0` |
| **Address already in use** | Kill the old process: `pkill -f "flask run"` or `pkill -f "python3 app.py"`, wait 2 seconds, try again |
| **Port conflict** | Use a different port: `--port=8081` and update proxy URL accordingly |

## Tips

- **Be specific** — "Add input validation to the greet function in app.py" works better than "make it better"
- **Let it read your code** — Claude Code automatically reads files it needs; you don't have to manually add them
- **Commit regularly** — use `git add . && git commit -m "description"` to save your progress
- **Use one-shot mode for quick tasks** — `claude -p "explain what app.py does"` for quick questions
- **Always `source ~/.bashrc`** when you open a new terminal
- **Don't kill all Python processes** — `kill -9` on all python will kill your Jupyter server too. Use `pkill -f "flask run"` to target just your app.

## Server lifecycle

Your JupyterHub server will automatically shut down after **3 days of inactivity**. As long as you log in regularly, it stays running and your files persist. If it does shut down, just start it again from the Server Options page — your home directory (`/home/jovyan`) is saved on persistent storage.

**What persists across restarts:** Your home directory (`/home/jovyan`), including code, git repos, `~/.bashrc`, `~/.claude.json`, `~/.llu_env`, Claude Code CLI (npm global), and the jupyter startup hook.

**What doesn't persist:** The conda environment (`/opt/conda`). This is why the setup script creates a startup hook in `~/.jupyter/jupyter_server_config.py` that automatically reinstalls `jupyter-server-proxy` each time your server boots.

## What to expect

- **Qwen3-Coder-30B** is a strong coding model with native tool calling. It handles file creation, editing, and multi-step tasks well.
- **Response time** is typically 2-5 seconds for short responses, longer for complex multi-file operations.
- **Context window** is 65K tokens — enough for most projects, but very large codebases may need you to be selective about which files you reference.
- The model runs on a dedicated A100 GPU shared by all students. During peak usage, responses may be slower.

## Switching to Aider (fallback)

If Claude Code or Qwen3-Coder is unavailable, switch to Aider with GLM-4.7-Flash:

```bash
# Install aider if not already installed
pip install --user aider-chat

# Configure for GLM-4.7-Flash
export OPENAI_API_BASE="http://vllm-glm-flash:8000/v1"
export OPENAI_API_KEY="not-needed"
aider --model openai/glm-4.7-flash --no-show-model-warnings --no-auto-commits
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `command not found: claude` | Run `source ~/.bashrc`. If still missing: `npm install -g --prefix="$HOME/.local" @anthropic-ai/claude-code && source ~/.bashrc` |
| "Not logged in" / browser opens | Run `source ~/.bashrc` first. If persists, re-run the setup script to recreate `~/.claude.json` |
| Claude hangs / timeout errors | Primary model may be down. Switch to fallback: `sed -i 's\|http://vllm-qwen3-coder:8000\|http://qwen-proxy:4000\|' ~/.llu_env && source ~/.bashrc` |
| "Connection refused" | vLLM service down. Switch to fallback (see above) or try the Aider fallback |
| Long pause before response (fallback) | Normal — Qwen3.5-397B thinks for 5–15 seconds before responding. Wait for it. |
| Model gives poor results | Try being more specific, or start a new session with `claude` |
| `claude` lost after server restart | `npm install -g --prefix="$HOME/.local" @anthropic-ai/claude-code && source ~/.bashrc` |
| Browser preview 404 | Restart server to activate jupyter-server-proxy |
| Browser preview 504 | App not running or not bound to `0.0.0.0` |
