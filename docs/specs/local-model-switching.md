# Local Model Switching Interface

## Purpose

Hermes-agent should use a stable OpenAI-compatible endpoint while this project
handles local model selection, runtime options, and llama.cpp server lifecycle.

Stable endpoint:

```text
http://127.0.0.1:18080/v1
```

Dockerized consumers should use:

```text
http://host.docker.internal:18080/v1
```

## Interface

Model profiles live in:

```text
model-profiles/*.env
```

Each profile defines the model path, public model name, context size, GPU
offload settings, and optional runtime features.

Policy:

- `model-profiles/*.env` are the source of truth for switching local models.
- `.env` remains a manual fallback and compatibility file for direct Docker
  Compose use.
- Generate `.env` only with an explicit command when a profile should become
  the manual default.

Export a profile to stdout:

```bash
./scripts/export_model_profile_env.sh qwen3.5-2b-q4-xl
```

Write a profile into `.env` explicitly:

```bash
./scripts/export_model_profile_env.sh qwen3.5-2b-q4-xl --output .env
```

Start a profile:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-mtp-q4-xl
```

List profiles:

```bash
./scripts/run_model_profile.sh list
```

Check the active server:

```bash
./scripts/run_model_profile.sh status
```

Run a Hermes-agent style provider smoke test:

```bash
OPENAI_BASE_URL=http://host.docker.internal:18080/v1 \
OPENAI_MODEL=<current PUBLIC_MODEL_NAME> \
./scripts/smoke_hermes_agent.sh
```

Override context for one run:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-mtp-q4-xl 130000
```

Download a preset model:

```bash
./scripts/download_model.sh qwen3.5-2b-mtp-q4-xl
```

Record a benchmark after switching:

```bash
./scripts/benchmark_chat.py --profile qwen3.5-2b-mtp-q4-xl --label qwen-mtp-short
```

## Current Profiles

### qwen3.5-2b-mtp-q4-xl

```text
model: Qwen3.5-2B-UD-Q4_K_XL.gguf
repo: unsloth/Qwen3.5-2B-MTP-GGUF
ctx: 130000
gpu layers: -1
KV cache: f16/f16
MTP compose override: enabled
```

### qwen3.5-2b-q4-xl

```text
model: Qwen3.5-2B-UD-Q4_K_XL.gguf
repo: unsloth/Qwen3.5-2B-MTP-GGUF
ctx: 130000
gpu layers: -1
KV cache: llama.cpp default
MTP compose override: disabled
```

### qwen3.5-2b-q8

```text
model: Qwen3.5-2B-Q8_0.gguf
repo: unsloth/Qwen3.5-2B-MTP-GGUF
ctx: 130000
gpu layers: -1
MTP compose override: disabled
purpose: quality fallback if Q4 XL output is insufficient
```

### qwen3.5-2b-mtp-q4-xl-kv-q8

```text
model: Qwen3.5-2B-UD-Q4_K_XL.gguf
repo: unsloth/Qwen3.5-2B-MTP-GGUF
ctx: 130000
gpu layers: -1
KV cache: q8_0/q8_0
MTP compose override: enabled
```

### gemma4-e2b-q4

```text
model: gemma-4-E2B-it-Q4_K_M.gguf
ctx: 130000
gpu layers: -1
MTP compose override: disabled
```

## Runtime Contract For Hermes-agent

Hermes-agent should not depend on the concrete GGUF filename. It should only
configure:

```env
OPENAI_BASE_URL=http://host.docker.internal:18080/v1
OPENAI_API_KEY=local-not-required
OPENAI_MODEL=<current PUBLIC_MODEL_NAME>
```

The model profile owns `PUBLIC_MODEL_NAME`. If Hermes-agent validates model IDs,
update `OPENAI_MODEL` after switching profiles.

Before wiring a selected profile into Hermes-agent workflows, run:

```bash
./scripts/smoke_hermes_agent.sh
```

Use the default `host.docker.internal` URL from inside Docker, or override
`OPENAI_BASE_URL=http://127.0.0.1:18080/v1` for host-only development.

## MTP Constraints

For Qwen3.5 MTP, use `docker-compose.gpu-mtp.example.yml`.

Do not combine MTP with:

```text
LLAMA_PARALLEL > 1
--mmproj
```

The MTP override currently passes:

```text
-fa on
--cache-type-k f16
--cache-type-v f16
--spec-type draft-mtp
--spec-draft-n-max 6
```

KV cache quantization can be tested by changing profile values:

```env
LLAMA_CACHE_TYPE_K=q8_0
LLAMA_CACHE_TYPE_V=q8_0
```
