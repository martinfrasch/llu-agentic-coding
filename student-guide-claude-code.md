# Agentic Coding with Claude Code on NRP

## What you're using

**Claude Code** is Anthropic's official CLI coding agent. It connects to a Qwen3-Coder-30B model running on NRP's GPU cluster and can read, edit, create files, run commands, and manage your project — all from the terminal.

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

This installs Claude Code CLI, configures the connection to the in-cluster Qwen3-Coder model, and runs a smoke test.

After setup, **restart your server once** for browser previews: File → Hub Control Panel → Stop My Server → Start My Server.

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
| Model | Qwen3-Coder-30B-A3B-Instruct |
| Architecture | 30B MoE (3B active params per token) |
| Context | 65K tokens |
| Endpoint | `http://vllm-qwen3-coder:8000` (in-cluster, no auth needed) |
| API | Anthropic Messages API (native vLLM support) |
| Tool calling | Yes — full agentic file creation, editing, commands |

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

1. Open a **second terminal** in JupyterLab
2. Start your app:

```bash
source ~/.bashrc
cd ~/my-project
flask run --host=0.0.0.0 --port=8080
```

3. Open this URL in your browser (replace `YOUR-USERNAME` with the part after `/user/` in your JupyterHub URL):

```
https://llu-jupyter.nrp-nautilus.io/user/YOUR-USERNAME/proxy/8080/
```

4. To stop the server, press **Ctrl-C** in the terminal.

## Tips

- **Be specific** — "Add input validation to the greet function in app.py" works better than "make it better"
- **Let it read your code** — Claude Code automatically reads files it needs; you don't have to manually add them
- **Commit regularly** — use `git add . && git commit -m "description"` to save your progress
- **Use one-shot mode for quick tasks** — `claude -p "explain what app.py does"` for quick questions
- **Always `source ~/.bashrc`** when you open a new terminal

## Server lifecycle

Your JupyterHub server will automatically shut down after **3 days of inactivity**. As long as you log in regularly, it stays running and your files persist. If it does shut down, just start it again from the Server Options page — your home directory (`/home/jovyan`) is saved on persistent storage.

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
| `command not found: claude` | Run `source ~/.bashrc` or check `npm list -g @anthropic-ai/claude-code` |
| Claude hangs after sending message | Check `curl http://vllm-qwen3-coder:8000/health` — if no response, the model may be loading (notify instructor) |
| "Connection refused" | The vLLM service may be down. Try the Aider fallback above. |
| Model gives poor results | Try being more specific, or start a new session with `claude` |
| Permission denied errors | Make sure you're not running as root; Claude Code blocks `--dangerously-skip-permissions` as root |
