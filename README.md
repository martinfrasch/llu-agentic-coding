# LLU Agentic Coding

Agentic coding environment for LLU class using [Aider](https://aider.chat) + GLM-4.7-Flash on NRP.

## Quick Start

1. Log in to **https://llu-jupyter.nrp-nautilus.io** with your institutional credentials
2. Start a server (defaults: 0 GPUs, 4 cores, 16 GB RAM, Python image)
3. Open a **Terminal** in JupyterLab
4. Run:

```bash
curl -sSL https://raw.githubusercontent.com/martinfrasch/llu-agentic-coding/main/student-setup.sh | bash
```

5. Follow the prompts (enter your name and email for git)
6. **Restart your server once** for browser previews: File → Hub Control Panel → Stop → Start
7. Open a new terminal and start coding:

```bash
source ~/.bashrc
mkdir ~/my-project && cd ~/my-project && git init
aider
```

## What This Sets Up

- **Aider** — CLI coding assistant that can read, edit, and create files
- **GLM-4.7-Flash** — 30B-parameter LLM running on a dedicated A100 GPU in the NRP cluster
- **Shell environment** — pre-configured to connect aider to the in-cluster model endpoint
- **jupyter-server-proxy** — enables viewing web apps in your browser via JupyterHub

## Documentation

- [Student Guide](student-guide.md) — full usage guide with examples and troubleshooting
