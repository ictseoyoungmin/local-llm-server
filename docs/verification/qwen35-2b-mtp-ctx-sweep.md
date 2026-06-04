# Qwen3.5 2B MTP Context Verification

## Model

```text
unsloth/Qwen3.5-2B-MTP-GGUF
Qwen3.5-2B-UD-Q4_K_XL.gguf
```

## Commands Used

Download:

```bash
HF_CLI=/tmp/local-llm-hf-venv/bin/hf ./scripts/download_model.sh qwen3.5-2b-mtp-q4-xl
```

Run examples:

```bash
env LLAMA_MODEL_PATH=/models/Qwen3.5-2B-UD-Q4_K_XL.gguf \
  PUBLIC_MODEL_NAME=qwen3.5-2b-mtp-ud-q4-k-xl \
  LLAMA_CTX_SIZE=130000 \
  LLAMA_N_GPU_LAYERS=-1 \
  LLAMA_PARALLEL=1 \
  docker compose -f docker-compose.yml -f docker-compose.gpu.example.yml up -d --force-recreate --no-build
```

Health:

```bash
curl -fsS http://127.0.0.1:18080/v1/health
```

Chat:

```bash
curl -fsS --max-time 240 http://127.0.0.1:18080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer local-not-required' \
  -d '{"model":"qwen3.5-2b-mtp-ud-q4-k-xl","messages":[{"role":"system","content":"You are concise."},{"role":"user","content":"Reply with: ready"}],"thinking":false,"chat_template_kwargs":{"enable_thinking":false},"temperature":0,"max_tokens":8}'
```

## Results

| Check | Result |
| --- | --- |
| Download | OK |
| Model validation | OK |
| 32768 ctx health | OK |
| 32768 ctx chat | OK |
| 65536 ctx health | OK |
| 98304 ctx health | OK |
| 130000 ctx health | OK, reported as 130048 |
| 130000 ctx chat | OK, response `ready` |

## Observed Performance

At 130000 requested context:

```text
prompt tokens: 25
prompt time: ~92 seconds
generation: ~41 tokens/sec
VRAM: ~4.48 GiB / 6 GiB
```

## Gaps

- MTP speculative decoding was not enabled during the first context sweep.
- A second pass with `docker-compose.gpu-mtp.example.yml` confirmed MTP loads at
  `LLAMA_CTX_SIZE=130000`.
- Need Hermes-agent end-to-end validation using the stable gateway endpoint.

## MTP Pass

Command:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-mtp-q4-xl 130000
```

Server log evidence:

```text
adding speculative implementation 'draft-mtp'
speculative decoding context initialized
```

Health:

```text
n_ctx: 130048
status: ok
```

Observed VRAM:

```text
~5.26 GiB / 6 GiB
```

Short chat:

```text
response: ready
draft_n: 6
draft_n_accepted: 4
```

This confirms MTP is active, but not that it is faster for Hermes-agent. The
2-token test is too short and showed high overhead.
