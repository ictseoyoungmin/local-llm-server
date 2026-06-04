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
env LLAMA_MODEL_PATH=/models/qwen35/Qwen3.5-2B-UD-Q4_K_XL.gguf \
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

## q8_0 KV Cache Pass

Profile:

```text
qwen3.5-2b-mtp-q4-xl-kv-q8
```

Command:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-mtp-q4-xl-kv-q8 130000
```

Health:

```text
model_name: qwen3.5-2b-mtp-ud-q4-k-xl-kv-q8
n_ctx: 130048
status: ok
```

Observed VRAM:

```text
~4.43 GiB / 6 GiB
```

Benchmark records:

```text
hermes-routing cold: prompt 0.84 tok/s, generation 2.82 tok/s, draft 34/276
hermes-routing warm: prompt 14.61 tok/s, generation 20.38 tok/s, draft 34/276
```

Compared with the f16 MTP warm record:

```text
hermes-routing warm: prompt 233.04 tok/s, generation 29.32 tok/s, draft 35/288
```

Recommendation: keep f16 KV as the default profile for speed. Keep q8_0 KV as a
VRAM fallback profile.

## Hermes-agent Provider Smoke

Script:

```bash
OPENAI_BASE_URL=http://127.0.0.1:18080/v1 \
OPENAI_MODEL=qwen3.5-2b-mtp-ud-q4-k-xl-kv-q8 \
./scripts/smoke_hermes_agent.sh
```

Result:

```text
response: hermes local provider ready
status: OK
```

The script defaults to `http://host.docker.internal:18080/v1` for Dockerized
Hermes-agent use. Use the host URL override above when running the smoke test
directly from the host.

## MTP On/Off Long Benchmark

Profiles:

```text
MTP off: qwen3.5-2b-q4-xl
MTP on:  qwen3.5-2b-mtp-q4-xl
```

Benchmark preset:

```text
hermes-summary
```

Results:

| Profile | State | Prompt tok/s | Generation tok/s | Elapsed ms | Draft |
| --- | --- | ---: | ---: | ---: | ---: |
| qwen3.5-2b-q4-xl | cold | 1.36 | 47.38 | 97969.384 | - |
| qwen3.5-2b-q4-xl | warm | 21.44 | 59.04 | 4020.707 | - |
| qwen3.5-2b-mtp-q4-xl | cold | 1.27 | 10.69 | 120941.171 | 116/608 |
| qwen3.5-2b-mtp-q4-xl | warm | 18.21 | 33.26 | 6960.388 | 114/620 |

Recommendation: use the non-MTP Qwen Q4 XL profile for Hermes-agent by default
on this GTX 1660 6GB machine. Keep the MTP profile available for regression
testing after llama.cpp image updates.
