# Hermes-agent llama.cpp Compatibility

## Purpose

Hermes-agent should be able to use this project as a local, switchable model
backend without coupling itself to llama.cpp flags, GGUF paths, or model
download details.

This is a consumer-specific compatibility contract. The Local LLM Server itself
remains a shared OpenAI-compatible gateway for multiple consumers.

## Supported Integration

Use Hermes-agent's custom self-hosted provider:

```yaml
model:
  provider: custom
  default: <current PUBLIC_MODEL_NAME>
  base_url: http://host.docker.internal:18080/v1
  api_key: local-not-required
```

The endpoint must be the gateway:

```text
http://host.docker.internal:18080/v1
```

Do not point Hermes-agent directly at llama.cpp:

```text
http://host.docker.internal:18081/v1
```

The gateway owns compatibility normalization and keeps the public endpoint
stable while model profiles are switched underneath it.

Source references:

- Hermes custom provider docs:
  `https://github.com/NousResearch/hermes-agent/blob/main/website/docs/integrations/providers.md`
- Hermes Docker docs:
  `https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/docker.md`

## Gateway Sanitizer

Hermes Docker and some OpenAI-compatible client layers can send provider
extension fields that llama.cpp rejects with HTTP 400. The gateway removes the
known problematic top-level fields before forwarding to llama.cpp:

```text
extra_body
options
num_ctx
```

The sanitizer applies to:

```text
/v1/chat/completions
/v1/completions
/v1/embeddings
```

It is enabled by default:

```env
SANITIZE_LLAMA_CPP_REQUESTS=true
```

For debugging only:

```env
SANITIZE_LLAMA_CPP_REQUESTS=false
```

When the gateway removes fields, it adds:

```text
X-Local-LLM-Sanitized-Fields: extra_body,num_ctx,options
```

## Tool Payload Policy

The gateway does not remove `tools`, `tool_choice`, or function schema fields.
Hermes-agent depends on tool payloads for agent workflows, so stripping them at
the gateway would hide integration problems.

Known caveat: llama.cpp's OpenAI-compatible server may not execute or honor all
tool-calling semantics expected by Hermes-agent. The current policy is:

- preserve tool payloads;
- record whether the selected llama.cpp version and model handle them;
- avoid claiming full Hermes tool support until an end-to-end tool workflow is
  measured.

## Smoke Container

This repository provides a separate Hermes-agent smoke container:

```text
docker-compose.hermes-agent.yml
hermes-agent-smoke/config.yaml
scripts/smoke_hermes_agent.sh
```

Run it after starting a model profile:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
HERMES_AGENT_MODEL=qwen3.5-2b-ud-q4-k-xl ./scripts/smoke_hermes_agent.sh
```

or:

```bash
./scripts/run_model_profile.sh gemma4-e2b-q4 130000
HERMES_AGENT_MODEL=gemma-4-E2B-it-Q4_K_M ./scripts/smoke_hermes_agent.sh
```

The script performs two checks:

- direct gateway request containing `extra_body`, `options`, and `num_ctx`;
- one-shot Hermes-agent run using the official Docker image and custom
  endpoint config.

The smoke compose file intentionally runs
`entrypoint: ["/opt/hermes/.venv/bin/hermes"]` for one-shot CLI verification.
On this host, the official image wrapper spent several minutes recursively
changing ownership of its internal virtual environment before the one-shot
command could start. Do not apply this shortcut to a long-running Hermes
gateway container; the official wrapper is still the correct path for that
mode.

For full Hermes gateway mode, use the operational notes in
`docs/specs/hermes-agent-runtime-integration.md`. The smoke container is not a
replacement for that runtime.

Record results in:

```text
docs/verification/hermes-agent-compatibility.md
```

## Context Requirement

Hermes-agent requires a large server-side context window for practical agent
use. Do not rely on request-level `num_ctx` from Hermes or OpenAI-compatible
clients. Set context in the selected local model profile:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
```

The measured llama.cpp runtime rounds this to:

```text
n_ctx=130048
```
