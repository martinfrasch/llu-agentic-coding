# LiteLLM + vLLM as Backend for Claude Code CLI: Research Report

**Date**: 2026-03-26
**Confidence**: High (0.8) -- based on official docs, multiple independent sources, and known GitHub issues

---

## Executive Summary

There are **two viable architectures** for making Claude Code CLI work with open-source models via vLLM:

1. **vLLM Direct** (simpler, recommended): vLLM now natively implements the Anthropic Messages API. Claude Code can point `ANTHROPIC_BASE_URL` directly at vLLM with no translation layer needed.
2. **LiteLLM Proxy** (more flexible): LiteLLM sits between Claude Code and vLLM, translating Anthropic API format to OpenAI format. More configuration complexity but adds load balancing, fallbacks, and cost tracking.

Both approaches work, but tool calling reliability depends heavily on the **model's intrinsic ability** to produce structured tool calls -- no proxy can fix a model that doesn't reliably generate them.

---

## 1. Can LiteLLM Act as an Anthropic API-Compatible Proxy?

**Yes, confirmed and well-documented.**

### Architecture A: LiteLLM as Translator (Anthropic -> OpenAI -> vLLM)

Claude Code speaks Anthropic Messages API. LiteLLM accepts these requests on its `/anthropic` passthrough endpoint and translates them to OpenAI chat completion format, which vLLM natively serves.

**LiteLLM `config.yaml`:**
```yaml
model_list:
  - model_name: "claude-sonnet-4-20250514"   # What Claude Code asks for
    litellm_params:
      model: "openai/your-model-name"         # "openai/" prefix = OpenAI-compatible endpoint
      api_base: "http://localhost:8000/v1"    # Your vLLM server
      api_key: "dummy"                        # vLLM doesn't need a real key
      drop_params: true                       # DROP unrecognized params like output_config

general_settings:
  drop_params: true        # Critical: Claude Code sends params vLLM doesn't understand
  modify_params: true      # Allow LiteLLM to adjust params for compatibility
```

**Claude Code environment:**
```bash
export ANTHROPIC_BASE_URL="http://localhost:4000/anthropic"
export ANTHROPIC_AUTH_TOKEN="sk-your-litellm-master-key"
export ANTHROPIC_MODEL="claude-sonnet-4-20250514"  # Must match model_name in config
```

**Start LiteLLM:**
```bash
litellm --config config.yaml --port 4000
```

### Architecture B: vLLM Direct (No LiteLLM Needed)

As of vLLM ~0.8+, vLLM implements the Anthropic Messages API directly. This is the simpler path.

**Start vLLM with Anthropic API support:**
```bash
vllm serve your-model-name \
  --host 0.0.0.0 \
  --port 8000 \
  --enable-auto-tool-choice \
  --tool-call-parser <parser-name> \
  --served-model-name claude-sonnet-4-20250514
```

**Claude Code environment:**
```bash
export ANTHROPIC_BASE_URL="http://localhost:8000"
export ANTHROPIC_API_KEY="dummy"
export ANTHROPIC_AUTH_TOKEN="dummy"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-20250514"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-sonnet-4-20250514"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-sonnet-4-20250514"
```

**Important vLLM note**: Claude Code injects a per-request hash in system prompts that defeats prefix caching. For vLLM <= 0.17.1, add to `~/.claude/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0"
  }
}
```

### Known Issues

- **`output_config` parameter**: Claude Code sends this parameter which OpenAI/vLLM doesn't understand. In LiteLLM, `drop_params: true` is essential. See [GitHub issue #22963](https://github.com/BerriAI/litellm/issues/22963).
- **Beta headers**: Claude Code sends Anthropic-specific beta headers that can cause issues. LiteLLM has had [incidents](https://docs.litellm.ai/blog/claude-code-beta-headers-incident) with these.

---

## 2. Tool Calling Translation

### How It Works

LiteLLM translates between:
- **Anthropic format**: `tool_use` blocks (in assistant messages) and `tool_result` blocks (in user messages)
- **OpenAI format**: `function_call` / `tool_calls` in assistant messages, `tool` role messages for results

The translation layer is in `litellm/llms/anthropic/experimental_pass_through/adapters/transformation.py`.

### What Works
- Basic tool definitions (name, description, parameters JSON schema) translate correctly
- Single tool calls work
- Tool results are properly mapped back

### Known Limitations
- **Responses API format**: Newer Claude Code versions may use the Responses API (`/responses`), which has different tool call structures. Translation of this format is still being developed ([GitHub issue #16215](https://github.com/BerriAI/litellm/issues/16215)).
- **Parallel tool calls**: Translation quality varies; some edge cases around multiple simultaneous tool calls.
- **Content block ordering**: Anthropic interleaves text and tool_use blocks in a single message; the translation to OpenAI format (where tool_calls are a separate field) can lose ordering information.
- **Streaming**: Tool call streaming translation can be fragile.

### With vLLM Direct (Architecture B)
vLLM handles this translation natively at the API layer, so Anthropic-format tool definitions in the request are translated to the model's chat template format, and the model's tool call output is translated back to Anthropic format. This avoids double-translation.

---

## 3. Claude Code + Open-Source Models: Real-World Experience

### Has Anyone Done This Successfully?

**Yes, multiple confirmed implementations exist:**

1. **vLLM official docs** have a dedicated [Claude Code integration page](https://docs.vllm.ai/en/stable/serving/integrations/claude_code/).

2. **WolframRavenwolf's HOWTO gist** is the most detailed community guide: [Use Qwen3-Coder with Claude Code via LiteLLM](https://gist.github.com/WolframRavenwolf/0ee85a65b10e1a442e4bf65f848d6b01). Key finding: the model needs at least 200K context window because Claude Code uses auto-compacting near the limit.

3. **DEV Community guide**: [Running Claude Code with Local LLMs via vLLM and LiteLLM](https://dev.to/dcruver/running-claude-code-with-local-llms-via-vllm-and-litellm-599b).

4. **Ollama blog**: [Claude Code with Anthropic API compatibility](https://ollama.com/blog/claude) -- confirms Ollama also implements the Anthropic Messages API for Claude Code.

5. **ruflo wiki**: [Using Claude Code with Open Models](https://github.com/ruvnet/ruflo/wiki/Using-Claude-Code-with-Open-Models) documents using Qwen3-Coder and other models.

### Honest Assessment of Quality

The experience is **functional but degraded** compared to actual Claude models:

- **Tool calling reliability**: Open-source models sometimes narrate what they would do ("I would now edit the file...") instead of actually emitting tool calls. This is a model-level problem, not a proxy problem.
- **Complex multi-step tasks**: Models can lose track of tool call sequences in long conversations.
- **Error recovery**: When a tool call fails, open-source models are less reliable at retrying or adjusting their approach.
- **Context window pressure**: Claude Code consumes 3-5K tokens for system prompt + 2-4K per tool definition. With many tools loaded, smaller context models struggle.

---

## 4. GLM-4.7-Flash Tool Calling Capability

### Architecture
- **Parameters**: ~130B total (MoE), efficient inference
- **Context**: 128K tokens
- **vLLM parser**: `--tool-call-parser glm47`

### vLLM Launch Command
```bash
vllm serve zai-org/GLM-4.7-Flash \
  --tensor-parallel-size 1 \
  --tool-call-parser glm47 \
  --enable-auto-tool-choice \
  --max-model-len 32768
```

### Known Issues (as of March 2026)

There are **multiple open bugs** in vLLM for GLM-4.7 tool calling:

1. **[Issue #36833](https://github.com/vllm-project/vllm/issues/36833)**: GLM-4.7-Flash does not return `tool_calls` field in vLLM 0.16.0 even with `--tool-call-parser glm47`. Filed ~2 weeks ago, suggesting the problem is recent/ongoing.

2. **[Issue #32436](https://github.com/vllm-project/vllm/issues/32436)**: "Failed to extract tool call spec" -- TypeError when tool calls have empty parameters. The regex parser doesn't handle edge cases.

3. **[Issue #32829](https://github.com/vllm-project/vllm/issues/32829)**: During GLM-4.7 function calling, output is not streamed properly.

4. **[Issue #27703](https://github.com/vllm-project/vllm/issues/27703)**: GLM-4.5 reasoning parser fails in multi-turn conversations with tool calls (Turn 3+).

### Honest Assessment

GLM-4.7-Flash has strong inherent tool-calling capability (the model itself generates good tool call formats). However, **vLLM's parser support for GLM-4.7 is currently buggy**. The model works better with SGLang or with the ZhipuAI cloud API than with vLLM's tool call parser at this moment. If you're running through NRP's Envoy endpoint, the reliability will depend on which inference engine is behind Envoy and whether it properly implements GLM tool call parsing.

---

## 5. Alternative Models for A100-80GB

### Tier 1: Recommended for Agentic Coding on Single A100-80GB

#### Qwen3-Coder-30B-A3B-Instruct
- **Architecture**: 30B total params, 3B active (MoE) -- fits easily on A100-80GB
- **Context**: 256K tokens (critical for Claude Code which needs large context)
- **vLLM parser**: `--tool-call-parser qwen3_coder` (requires vLLM >= 0.10.0)
- **Tool calling**: Purpose-built for agentic coding with function calling
- **Status**: Active development, well-supported
- **Caveat**: [Tool call parser issues reported](https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct/discussions/19) in some vLLM versions

```bash
vllm serve Qwen/Qwen3-Coder-30B-A3B-Instruct \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  --max-model-len 65536 \
  --gpu-memory-utilization 0.90
```

#### Qwen3-Coder-Next (80B MoE, 3B active)
- **Released**: 2026
- **Context**: 256K tokens
- **Performance**: Comparable to models with 10-20x more active parameters
- **Fits**: ~46GB VRAM in FP16, comfortably on A100-80GB
- **Claude Code integration**: Explicitly documented as compatible

### Tier 2: Strong Alternatives

#### Qwen2.5-Coder-32B-Instruct
- **Architecture**: 32B dense model -- fits on A100-80GB in FP16 (~64GB)
- **Context**: 32K tokens (possibly too small for Claude Code)
- **Tool calling**: **Problematic with vLLM**. Multiple bugs filed:
  - [Issue #10952](https://github.com/vllm-project/vllm/issues/10952): Function calling not working properly
  - [Issue #17821](https://github.com/vllm-project/vllm/issues/17821): Tool calls not triggered with vLLM 0.8.5
  - Works better via Ollama than vLLM for tool calling
- **Honest assessment**: Good coding model but **tool calling with vLLM is unreliable**. The hermes parser doesn't work well with it. Not recommended for agentic use with Claude Code.

#### DeepSeek-Coder-V2-Lite-Instruct (16B active, MoE)
- **Architecture**: MoE, ~16B active params
- **Context**: 128K tokens
- **Tool calling**: No dedicated vLLM parser. Would need hermes-style tool calling.
- **Honest assessment**: Decent coding but **not designed for robust tool calling**. Superseded by newer models. Not recommended.

### Tier 3: Worth Watching

#### Kimi-K2-Thinking
- Large MoE model with excellent tool-use (200-300 sequential tool calls reported stable)
- May be too large for single A100-80GB without quantization

#### GPT-OSS-120B (MoE, 5.1B active)
- Runs on single 80GB GPU with MXFP4 quantization
- Native agentic tools including function calling
- Very new, limited community testing

### Recommendation for Your Setup

**Primary choice: Qwen3-Coder-30B-A3B-Instruct** -- best balance of:
- Fits comfortably on A100-80GB
- 256K context (Claude Code needs this)
- Purpose-built tool calling with dedicated vLLM parser
- Active community using it with Claude Code
- MoE efficiency means fast inference

**Fallback: GLM-4.7-Flash** -- if you're already committed to the NRP Envoy endpoint using GLM, be prepared for tool calling parser bugs and consider pinning to a specific vLLM version where tool calling is confirmed working.

---

## 6. vLLM Structured Output / Constrained Decoding for Tool Calls

### How `--enable-auto-tool-choice` Works

When you start vLLM with `--enable-auto-tool-choice` and a `--tool-call-parser`, it:

1. **Detects** when the model is generating a tool call (parser-specific regex/pattern matching)
2. **Activates guided decoding** to ensure the tool call parameters conform to the JSON schema defined in the `tools` parameter
3. **Parses** the raw model output into structured `tool_calls` objects in the API response

### Does It Force Valid JSON?

**Partially yes, with caveats.**

- When `tool_choice='required'` is set, vLLM guarantees the model will produce at least one tool call, and guided decoding ensures the parameters match the JSON schema.
- When `tool_choice='auto'` (default for Claude Code), the model decides whether to call tools. If it decides to call a tool, guided decoding kicks in for the parameters. But the model can still choose to output text instead of a tool call.
- **vLLM V1 (0.8.5+)** has dramatically faster structured output than V0. Previously, constrained decoding could degrade system-wide throughput; V1 introduces minimal overhead.

### Reliability Assessment

**The constrained decoding for JSON schema conformance is reliable** -- once the model starts generating a tool call, the output will be valid JSON matching the schema.

**The unreliable part is the model deciding to generate a tool call in the first place.** If the model outputs tool calls as plain text (common with weaker models), the parser won't catch it. Using the **wrong parser** for a model silently produces no tool calls -- a common misconfiguration.

### Parser Compatibility Matrix

| Model | Parser Flag | Status |
|-------|------------|--------|
| GLM-4.7 | `--tool-call-parser glm47` | Buggy (see issues above) |
| Qwen3-Coder | `--tool-call-parser qwen3_coder` | Working (vLLM >= 0.10.0) |
| Hermes-format models | `--tool-call-parser hermes` | Stable, well-tested |
| Mistral | `--tool-call-parser mistral` | Stable |
| Llama 3.1+ | `--tool-call-parser llama3_json` | Stable |
| Jamba | `--tool-call-parser jamba` | Supported |

**Critical warning**: Using the wrong parser (e.g., hermes parser with a GLM model) **silently produces no tool calls**. Always match the parser to the model's training format.

---

## Practical Recommendations for Your LLU Class Setup

### Option A: Simplest Path (vLLM Direct, No LiteLLM)

```bash
# On the VM running vLLM
vllm serve Qwen/Qwen3-Coder-30B-A3B-Instruct \
  --host 0.0.0.0 \
  --port 8000 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  --max-model-len 65536 \
  --gpu-memory-utilization 0.90 \
  --served-model-name claude-sonnet-4-20250514

# On each student VM
export ANTHROPIC_BASE_URL="http://<vllm-server>:8000"
export ANTHROPIC_API_KEY="dummy"
export ANTHROPIC_AUTH_TOKEN="dummy"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-20250514"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-sonnet-4-20250514"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-sonnet-4-20250514"

claude
```

### Option B: With LiteLLM (If Using NRP Envoy + GLM-4.7)

```bash
# On student VM or shared proxy
pip install 'litellm[proxy]'

# config.yaml
cat > litellm_config.yaml << 'EOF'
model_list:
  - model_name: "claude-sonnet-4-20250514"
    litellm_params:
      model: "openai/glm-4.7-flash"
      api_base: "https://ellm.nrp-nautilus.io/v1"
      api_key: "your-envoy-key"
      drop_params: true

general_settings:
  drop_params: true
  modify_params: true
EOF

litellm --config litellm_config.yaml --port 4000

# Student environment
export ANTHROPIC_BASE_URL="http://localhost:4000/anthropic"
export ANTHROPIC_AUTH_TOKEN="sk-litellm-master-key"
```

### Key Risk: GLM-4.7 via NRP Envoy

Your original architecture (Claude Code -> Envoy -> GLM-4.7) has a specific risk: if Envoy passes through to a vLLM backend with the buggy GLM-4.7 tool call parser, students will experience tool calls silently failing. The model will try to call tools but the response won't contain `tool_calls` in the structured format Claude Code expects.

**Mitigation options**:
1. Test tool calling end-to-end before the class with a simple script
2. Have Qwen3-Coder-30B as a backup model on a local A100
3. If tool calling fails, students can still use Claude Code for code generation (it falls back to text-based suggestions), but the agentic loop will be broken

---

## Sources

- [Claude Code - vLLM Integration](https://docs.vllm.ai/en/stable/serving/integrations/claude_code/)
- [Use Claude Code with Non-Anthropic Models | LiteLLM](https://docs.litellm.ai/docs/tutorials/claude_non_anthropic_models)
- [Claude Code Quickstart | LiteLLM](https://docs.litellm.ai/docs/tutorials/claude_responses_api)
- [LLM Gateway Configuration - Claude Code Docs](https://code.claude.com/docs/en/llm-gateway)
- [GLM-4.7-Flash on HuggingFace](https://huggingface.co/zai-org/GLM-4.7-Flash)
- [GLM-4.X LLM Usage Guide - vLLM Recipes](https://docs.vllm.ai/projects/recipes/en/latest/GLM/GLM.html)
- [vLLM Bug #36833: GLM-4.7-Flash tool_calls missing](https://github.com/vllm-project/vllm/issues/36833)
- [vLLM Bug #32436: GLM-4.7 tool call extraction failure](https://github.com/vllm-project/vllm/issues/32436)
- [vLLM Bug #10952: Qwen2.5-Coder function calling broken](https://github.com/vllm-project/vllm/issues/10952)
- [LiteLLM Bug #22963: output_config parameter issue](https://github.com/BerriAI/litellm/issues/22963)
- [HOWTO: Qwen3-Coder with Claude Code via LiteLLM](https://gist.github.com/WolframRavenwolf/0ee85a65b10e1a442e4bf65f848d6b01)
- [Using Claude Code with Open Models (ruflo wiki)](https://github.com/ruvnet/ruflo/wiki/Using-Claude-Code-with-Open-Models)
- [Qwen3-Coder-30B-A3B-Instruct on HuggingFace](https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct)
- [vLLM Tool Calling Documentation](https://docs.vllm.ai/en/latest/features/tool_calling/)
- [Qwen3-Coder GitHub](https://github.com/QwenLM/Qwen3-Coder)
- [LiteLLM Anthropic Passthrough](https://docs.litellm.ai/docs/pass_through/anthropic_completion)
- [Running Claude Code with Local LLMs via vLLM and LiteLLM](https://dev.to/dcruver/running-claude-code-with-local-llms-via-vllm-and-litellm-599b)
- [Ollama Claude Code Integration](https://ollama.com/blog/claude)
- [Best Local LLMs for Coding Agents 2026](https://www.clawctl.com/blog/best-local-llm-coding-2026)
- [Best Open-Source LLM for Agent Workflow 2026](https://www.siliconflow.com/articles/en/best-open-source-LLM-for-Agent-Workflow)
