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

Override context for one run:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-mtp-q4-xl 130000
```

Download a preset model:

```bash
./scripts/download_model.sh qwen3.5-2b-mtp-q4-xl
```

## Current Profiles

### qwen3.5-2b-mtp-q4-xl

```text
model: Qwen3.5-2B-UD-Q4_K_XL.gguf
repo: unsloth/Qwen3.5-2B-MTP-GGUF
ctx: 130000
gpu layers: -1
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
