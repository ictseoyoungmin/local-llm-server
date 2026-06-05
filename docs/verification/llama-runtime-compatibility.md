# llama.cpp Runtime Compatibility

This file is the quick lookup table for humans and external agents choosing a
llama.cpp runtime and local model profile.

## Runtime Selection

- Default runtime tag: `ghcr.io/ggml-org/llama.cpp:server-cuda`.
- Known-good rollback lock: `llama-image.lock`.
- Update command: `./scripts/llama_image.sh update`.
- Rollback command: `./scripts/llama_image.sh rollback`.
- Model switch command: `./scripts/run_model_profile.sh <profile> 130000`.

## Model Paths

| Family | Runtime profile | Host path | Container path | Notes |
| --- | --- | --- | --- | --- |
| Gemma 4 | `gemma4-e2b-q4` | `models/gemma4/gemma-4-E2B-it-Q4_K_M.gguf` | `/models/gemma4/gemma-4-E2B-it-Q4_K_M.gguf` | Uses Gemma-specific mmproj. |
| Gemma 4 projector | `gemma4-e2b-q4` | `models/gemma4/mmproj-F16.gguf` | `/models/gemma4/mmproj-F16.gguf` | Do not share with Qwen text profiles. |
| Qwen3.5 | `qwen3.5-2b-q4-xl` | `models/qwen35/Qwen3.5-2B-UD-Q4_K_XL.gguf` | `/models/qwen35/Qwen3.5-2B-UD-Q4_K_XL.gguf` | Stable runtime path on this `/mnt/f` mount. |
| Qwen3.5 MTP | `qwen3.5-2b-mtp-q4-xl` | `models/qwen35/Qwen3.5-2B-UD-Q4_K_XL.gguf` | `/models/qwen35/Qwen3.5-2B-UD-Q4_K_XL.gguf` | MTP supported, but slower in current benchmarks. |

## Compatibility Matrix

| Measured at | llama-server version | Image digest | Profile | Model | Status | Benchmark |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-06-04 18:34-18:41 KST | `9294 (0f3cb3fc8)` | `sha256:e8d36f4dc2a72a1df323748f6219c9dd11f662f7cb3b06a6b2916c9bf3866d89` | `gemma4-e2b-q4` | Gemma 4 E2B Q4 | Working at `n_ctx=130048` | `docs/verification/benchmarks/2026-06-04-local-agent-multiturn.md` |
| 2026-06-04 18:39-18:41 KST | `9294 (0f3cb3fc8)` | `sha256:e8d36f4dc2a72a1df323748f6219c9dd11f662f7cb3b06a6b2916c9bf3866d89` | `qwen3.5-2b-q4-xl` | Qwen3.5 2B UD-Q4_K_XL | Working at `n_ctx=130048` | `docs/verification/benchmarks/2026-06-04-local-agent-multiturn.md` |

## Recording Rules

- Every benchmark row must include `started_at`, `finished_at`, model profile,
  prompt preset, llama.cpp version, image digest, and health metadata.
- Record cold and warm rows separately.
- Record failed rows instead of deleting them; classify environment failures
  separately from model/runtime failures in the benchmark note.
- After `./scripts/llama_image.sh update`, add rows here before changing
  Hermes-agent defaults.
