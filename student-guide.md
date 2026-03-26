# Agentic Coding with Aider on NRP

## What you're using

**Aider** is an open-source CLI coding assistant. It connects to a large language model running on NRP's GPU cluster and can read, edit, and create files in your project — all from the terminal.

## Getting started

1. Go to **https://llu-jupyter.nrp-nautilus.io**
2. Log in with your institutional credentials (CILogon)
3. On the Server Options page, use the defaults (0 GPUs, 4 cores, 16 GB RAM) and select the **Python** image. Click **Start**.
4. In JupyterLab, click **Terminal**

## Models available

| Model | Endpoint | Speed | Best for |
|-------|----------|-------|----------|
| **GLM-4.7-Flash** (default) | Self-hosted in-cluster | Fast, no cold starts | General coding, agentic editing |
| qwen3 (fallback) | NRP managed endpoint | Fast | Backup if GLM is down |

**Default flow**: `aider` → `http://vllm-glm-flash:8000/v1` → GLM-4.7-Flash (dedicated A100)

## Setup (one-time)

Run all of these in your JupyterHub terminal.

### Step 1: Install packages

```bash
pip install --user aider-chat flask
```

### Step 2: Enable browser preview for web apps

```bash
/opt/conda/bin/pip install jupyter-server-proxy
jupyter server extension enable jupyter_server_proxy
```

After this step, **restart your server** once: **File → Hub Control Panel → Stop My Server → Start My Server**. Then open a new terminal and continue with Step 3.

### Step 3: Configure git

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.edu"
```

### Step 4: Configure the model

This tells aider how to handle GLM's output format:

```bash
cat > ~/.aider.model.settings.yml << 'EOF'
- name: openai/glm-4.7-flash
  reasoning_tag: think
  edit_format: whole
EOF
```

### Step 5: Set up your shell environment

```bash
cat > ~/.bashrc << 'EOF'
export PATH="$HOME/.local/bin:$PATH"
export OPENAI_API_BASE="http://vllm-glm-flash:8000/v1"
export OPENAI_API_KEY="not-needed"
export AIDER_MODEL="openai/glm-4.7-flash"
export AIDER_FLAGS="--no-show-model-warnings --no-auto-commits"
EOF
source ~/.bashrc
```

## Daily usage

Every time you open a new terminal:

```bash
source ~/.bashrc
cd your-project    # navigate to any git repo
aider              # start aider
```

If you don't have a project yet:

```bash
source ~/.bashrc
mkdir ~/my-project && cd ~/my-project && git init
aider
```

### Key commands inside Aider

| Command | What it does |
|---------|-------------|
| just type | Ask the model to edit code in your project |
| `/ask <question>` | Ask a question without editing files |
| `/add <file>` | Add a file to the chat context |
| `/drop <file>` | Remove a file from context |
| `/diff` | Show pending changes |
| `/undo` | Undo the last change |
| `/commit` | **Save your work** — commit all changes to git (do this during breaks!) |
| `/help` | Full command list |
| `/exit` or Ctrl-D | Quit |

### Example session

```
$ source ~/.bashrc
$ cd ~/my-project
$ aider

> Create a file called app.py with a simple Flask hello world server

# Aider creates app.py and shows you the code

> /add app.py
> Add a /health endpoint that returns {"status": "ok"}

# Aider edits app.py and shows you the changes

> /ask What does the app.route decorator do?

# Aider answers without editing anything

> /undo
# Reverts the last edit

> /commit
# Saves all changes to git
```

### Viewing your web app in the browser

1. Open a **second terminal** in JupyterLab (click the **+** tab, then **Terminal**)
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

For example: `https://llu-jupyter.nrp-nautilus.io/user/jdoe-uw-edu---abc123/proxy/8080/`

4. To stop the server, go back to the terminal and press **Ctrl-C**.

### Testing with curl

If you prefer the command line, open a second terminal and run:

```bash
curl http://localhost:8080
curl http://localhost:8080/health
```

## Tips

- **Add only relevant files** — don't `/add` your whole project. Give it the files you want changed plus any it needs for context.
- **Be specific** — "Add input validation to the create_user function in models.py" works better than "make the code better."
- **Use `/ask` for questions** — it won't modify files, so it's safe for exploration.
- **Commit regularly** — Auto-commits are off. Use `/commit` during breaks to save your work. You can always review with `git log` and revert with `git revert`.
- **Always `source ~/.bashrc`** when you open a new terminal — your environment variables don't carry over automatically.

## Server lifecycle

Your JupyterHub server will automatically shut down after **3 days of inactivity**. As long as you log in regularly, it stays running and your files persist. If it does shut down, just start it again from the Server Options page — your home directory (`/home/jovyan`) is saved on persistent storage.

## What to expect

- **GLM-4.7-Flash** is a 30B-parameter model. It handles standard coding tasks well (writing functions, editing files, answering questions) but may struggle with very large or ambiguous requests.
- **Be specific** in your prompts. "Add a `/health` endpoint to `app.py`" works much better than "improve the server."
- **Auto-commits are off** — use `/commit` during breaks to save your work. You can undo edits with `/undo`.
- **Response time** is typically a few seconds. If it hangs for more than 30 seconds, the vLLM pod may be restarting — see Troubleshooting below.

## Switching to fallback model

If GLM-4.7-Flash is unavailable, switch to the NRP managed endpoint. You need to override both the endpoint **and** the model:

```bash
export OPENAI_API_BASE="https://ellm.nrp-nautilus.io/v1"
export OPENAI_API_KEY="<ask instructor for token>"
aider --model openai/qwen3 --no-show-model-warnings --no-auto-commits
```

To switch back to the default after GLM is restored:

```bash
source ~/.bashrc
aider
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `command not found: aider` or `flask` | Run `source ~/.bashrc` to load your PATH, or `export PATH="$HOME/.local/bin:$PATH"` |
| Aider hangs after sending message | Check `curl http://vllm-glm-flash:8000/v1/models` — if no response, the vLLM pod may be restarting (notify instructor) |
| "Connection refused" | The vLLM service may be down. Switch to fallback: `--model openai/qwen3` with NRP endpoint |
| Model gives poor code results | Try `/clear` to reset context, or be more specific in your prompt |
| `/add` says "file not found" | Use relative paths from your project root, e.g., `/add src/app.py` |
| Browser shows 404 for proxy URL | Make sure Flask is running with `--host=0.0.0.0` (not just localhost). Check the port matches your URL. |
| `~/.bashrc: No such file or directory` | Re-run Step 5 from the Setup section to recreate it |
