# Local LLM Server

Shared local LLM hosting service for projects that need a llama.cpp-backed,
OpenAI-compatible endpoint.

Target consumers:

- `F:\Fin_Project\2026\gemma4-tutor`
- `F:\NowWorking\hermes-agent`
- `F:\NowWorking\Dacon-Fin-Agent`

The public endpoint is intentionally stable:

```text
http://127.0.0.1:18080/v1
```

Behind that endpoint, this project runs:

- `llama.cpp` server for local GGUF inference
- a small FastAPI gateway for health checks, auth normalization, and proxying

## Quickstart

Copy the environment template:

```bash
cp .env.example .env
```

Edit `.env` so `HOST_MODEL_DIR` points to the directory that contains your GGUF
model. Then start the stack:

```bash
docker compose up --build
```

CPU mode is the default. For NVIDIA GPU mode:

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.example.yml up --build
```

Check health:

```bash
curl http://127.0.0.1:18080/v1/health
curl http://127.0.0.1:18080/v1/models
```

Run a chat smoke test:

```bash
./scripts/smoke_chat.sh
```

## Download Weights

This project does not commit model weights. Put GGUF files under `./models` or
set `HOST_MODEL_DIR` to another directory.

If the model is on Hugging Face, configure `.env`:

```env
HOST_MODEL_DIR=./models
HF_MODEL_REPO=owner/repo-name
HF_MODEL_FILE=model.gguf
HF_MMPROJ_FILE=
LLAMA_MODEL_PATH=/models/model.gguf
PUBLIC_MODEL_NAME=local-llama
```

Then download and validate:

```bash
./scripts/download_model.sh
./scripts/validate_models.sh
```

For gated repos, authenticate first:

```bash
huggingface-cli login
```

or set `HF_TOKEN` in your shell. Keep tokens out of `.env` if the repo may be
shared.

## Endpoint Contract

Use this as an OpenAI-compatible base URL:

```text
OPENAI_BASE_URL=http://127.0.0.1:18080/v1
OPENAI_API_KEY=local-not-required
```

The gateway proxies these paths to llama.cpp:

- `GET /v1/models`
- `POST /v1/chat/completions`
- `POST /v1/completions`
- `POST /v1/embeddings`

It also provides service-specific checks:

- `GET /health`
- `GET /v1/health`

## Provider Integration Guide

New agent projects should treat this service as a normal OpenAI-compatible LLM
provider. Keep provider-specific code in the consuming project small and
config-driven, so switching between hosted APIs and this local server only
changes environment variables.

Recommended provider environment variables:

```env
LLM_PROVIDER=openai_compatible
OPENAI_BASE_URL=http://127.0.0.1:18080/v1
OPENAI_API_KEY=local-not-required
OPENAI_MODEL=gemma-4-local
```

When the consuming app runs inside Docker, use the host gateway address:

```env
OPENAI_BASE_URL=http://host.docker.internal:18080/v1
```

Use the gateway port, not the raw llama.cpp port:

```text
good: http://127.0.0.1:18080/v1
avoid: http://127.0.0.1:18081/v1
```

### Minimal Chat Request

```bash
curl -fsS http://127.0.0.1:18080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer local-not-required" \
  -d '{
    "model": "gemma-4-local",
    "messages": [
      {"role": "system", "content": "You are a concise assistant."},
      {"role": "user", "content": "Say hello in one sentence."}
    ],
    "thinking": false,
    "chat_template_kwargs": {"enable_thinking": false},
    "temperature": 0.2,
    "max_tokens": 256
  }'
```

### Python Client Example

Any OpenAI-compatible client can use this endpoint:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:18080/v1",
    api_key="local-not-required",
)

response = client.chat.completions.create(
    model="gemma-4-local",
    messages=[
        {"role": "system", "content": "You are a concise assistant."},
        {"role": "user", "content": "Give me one local LLM health check sentence."},
    ],
    extra_body={
        "thinking": False,
        "chat_template_kwargs": {"enable_thinking": False},
    },
    max_tokens=256,
    temperature=0.2,
)

print(response.choices[0].message.content)
```

### Provider Adapter Pattern

For new repositories, prefer a thin adapter boundary:

```text
app/integrations/llm_client.py
```

The adapter should accept:

- `base_url`
- `api_key`
- `model`
- `timeout`
- `thinking_enabled`

Then expose a small project-native interface such as:

```python
class LlmClient:
    def generate_text(self, messages: list[dict[str, str]]) -> str: ...
    def generate_json(self, messages: list[dict[str, str]]) -> dict: ...
```

This keeps agents, tools, and services independent from whether the backend is
Gemini, OpenAI, OpenRouter, or this local llama.cpp server.

### Thinking On/Off

Gemma 4 can emit internal reasoning. For most app workflows, keep thinking off
unless the UI explicitly captures reasoning.

Thinking off:

```json
{
  "thinking": false,
  "chat_template_kwargs": {"enable_thinking": false},
  "max_tokens": 256
}
```

Thinking on:

```json
{
  "thinking": true,
  "reasoning_format": "auto",
  "chat_template_kwargs": {"enable_thinking": true},
  "max_tokens": 1024
}
```

When thinking is on, llama.cpp may return reasoning in
`message.reasoning_content`. If `max_tokens` is too small, reasoning can consume
the whole budget and leave `message.content` empty.

### Streaming

Streaming uses the standard OpenAI-compatible shape:

```json
{
  "model": "gemma-4-local",
  "messages": [{"role": "user", "content": "Stream a short answer."}],
  "stream": true,
  "thinking": false,
  "chat_template_kwargs": {"enable_thinking": false},
  "max_tokens": 256
}
```

### Health Checks for Consumers

Before an agent sends work, check:

```bash
curl -fsS http://127.0.0.1:18080/v1/health
curl -fsS http://127.0.0.1:18080/v1/models
```

`/v1/health` is the stable service health endpoint. `/v1/models` confirms the
upstream llama.cpp server is serving the loaded model.

### Recommended Defaults for Agent Projects

```env
OPENAI_BASE_URL=http://127.0.0.1:18080/v1
OPENAI_API_KEY=local-not-required
OPENAI_MODEL=gemma-4-local
LLM_TIMEOUT_SECONDS=600
LLM_THINKING_ENABLED=false
LLM_MAX_TOKENS=1024
LLM_TEMPERATURE=0.2
```

For Dockerized consumers:

```env
OPENAI_BASE_URL=http://host.docker.internal:18080/v1
```

For JSON-producing agents, use a strict system prompt and parse defensively.
This local server intentionally stays close to the OpenAI-compatible API surface
instead of adding project-specific parsing or schema repair.

## Model Configuration

The default `.env.example` assumes a model mounted into the container at:

```text
/models/model.gguf
```

For a Gemma 4 GGUF layout like `gemma4-tutor`, set:

```env
HOST_MODEL_DIR=/absolute/path/to/models
LLAMA_MODEL_PATH=/models/gemma-4-E2B-it-Q4_K_M.gguf
LLAMA_MMPROJ_PATH=/models/mmproj-F16.gguf
PUBLIC_MODEL_NAME=gemma-4-local
```

If you need multimodal support, use the example override:

```bash
docker compose -f docker-compose.yml -f docker-compose.multimodal.example.yml up --build
```

For GPU plus multimodal:

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu-multimodal.example.yml up --build
```

Set the projector path in `.env`:

```text
LLAMA_MMPROJ_PATH=/models/mmproj-F16.gguf
```

## CPU/GPU Selection

Default CPU mode:

```bash
docker compose up --build
```

NVIDIA GPU mode:

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.example.yml up --build
```

This switches the llama.cpp image to:

```env
LLAMA_GPU_IMAGE=ghcr.io/ggml-org/llama.cpp:server-cuda
```

NVIDIA GPU + MTP speculative decoding mode:

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu-mtp.example.yml up --build
```

Use the MTP override only with models that support MTP/speculative draft
decoding. The override enables flash attention, configurable KV cache types,
and:

```env
LLAMA_SPEC_TYPE=draft-mtp
LLAMA_SPEC_DRAFT_N_MAX=6
```

MTP currently assumes one parallel slot and no multimodal projector:

```env
LLAMA_PARALLEL=1
```

NVIDIA GPU + multimodal mode:

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu-multimodal.example.yml up --build
```

GPU offload is controlled by:

```env
LLAMA_N_GPU_LAYERS=-1
```

`-1` asks llama.cpp to offload all possible layers. If VRAM is tight, lower it,
for example `LLAMA_N_GPU_LAYERS=20`. CPU mode ignores this value.

To verify GPU use, logs should mention CUDA/CUBLAS and GPU buffers, not only
`CPU_Mapped`, `CPU KV`, or `CPU compute buffer`:

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.example.yml logs llama
```

If you previously started CPU mode, recreate the container after switching:

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.example.yml up -d --force-recreate
```

## Consumer Setup

### gemma4-tutor

Use the shared service instead of the project-local `llama` compose service:

```env
LLM_BACKEND=llama_cpp
LLAMA_BASE_URL=http://host.docker.internal:18080/v1
LLAMA_MODEL=gemma-4-local
LLAMA_API_KEY=local-not-required
VALIDATE_LLAMA_ASSETS=false
```

If running `gemma4-tutor` directly on the host instead of in Docker:

```env
LLAMA_BASE_URL=http://127.0.0.1:18080/v1
```

### hermes-agent

Inside the Hermes container, point an OpenAI-compatible provider at:

```text
http://host.docker.internal:18080/v1
```

Use:

```text
api_key=local-not-required
model=gemma-4-local
```

### Dacon-Fin-Agent

The current Dacon backend has a Gemini-specific client. Add an
OpenAI-compatible client there, or adapt the Gemini client boundary to support:

```env
LLM_PROVIDER=openai_compatible
OPENAI_BASE_URL=http://host.docker.internal:18080/v1
OPENAI_API_KEY=local-not-required
OPENAI_MODEL=gemma-4-local
```

For host-only development:

```env
OPENAI_BASE_URL=http://127.0.0.1:18080/v1
```

## Ports

- gateway: `18080`
- raw llama.cpp server: `18081`

Most clients should use the gateway port only.
