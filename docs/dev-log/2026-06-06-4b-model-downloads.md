# 2026-06-06 4B Model Downloads

## Goal

Identify downloadable 4B-class GGUF models for Gemma and Qwen, then place them
under nested model folders so model-specific `mmproj-F16.gguf` files are not
mixed across repositories.

## Hugging Face Repositories Checked

- `unsloth/Qwen3.5-4B-GGUF`
- `unsloth/Qwen3.5-4B-MTP-GGUF`
- `unsloth/gemma-3-4b-it-GGUF`
- `unsloth/gemma-4-E2B-it-GGUF`

`Qwen3.6 4B` was not found in the checked public Unsloth/Hugging Face search
results. Public Qwen3.6 GGUF results found during this pass were larger model
classes, not a 4B download target.

## Downloaded / Placed Files

| Source repo | File | Local path | Size |
| --- | --- | --- | --- |
| `unsloth/Qwen3.5-4B-GGUF` | `Qwen3.5-4B-Q4_K_M.gguf` | `models/qwen3.5/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf` | `2740937888` bytes |
| `unsloth/Qwen3.5-4B-GGUF` | `mmproj-F16.gguf` | `models/qwen3.5/qwen3.5-4b/mmproj-F16.gguf` | `672423616` bytes |
| `unsloth/Qwen3.5-4B-MTP-GGUF` | `Qwen3.5-4B-Q4_K_M.gguf` | `models/qwen3.5/qwen3.5-4b-mtp/Qwen3.5-4B-Q4_K_M.gguf` | `2834975040` bytes |
| `unsloth/Qwen3.5-4B-MTP-GGUF` | `mmproj-F16.gguf` | `models/qwen3.5/qwen3.5-4b-mtp/mmproj-F16.gguf` | `672423488` bytes |
| `unsloth/gemma-3-4b-it-GGUF` | `gemma-3-4b-it-Q4_K_M.gguf` | `models/gemma3/gemma-3-4b-it/gemma-3-4b-it-Q4_K_M.gguf` | `2489894016` bytes |
| `unsloth/gemma-3-4b-it-GGUF` | `mmproj-F16.gguf` | `models/gemma3/gemma-3-4b-it/mmproj-F16.gguf` | `851251328` bytes |
| `unsloth/gemma-4-E2B-it-GGUF` | `gemma-4-E2B-it-Q4_K_M.gguf` | `models/gemma4/gemma-4-e2b-it/gemma-4-E2B-it-Q4_K_M.gguf` | `3106735776` bytes |
| `unsloth/gemma-4-E2B-it-GGUF` | `mmproj-F16.gguf` | `models/gemma4/gemma-4-e2b-it/mmproj-F16.gguf` | `985654208` bytes |

The Gemma4 E2B files already existed in `models/gemma4/`; they were copied into
the nested folder instead of downloaded again.

## Profiles Added

- `gemma3-4b-it-q4`
- `gemma4-e2b-q4-nested`
- `qwen3.5-4b-q4`
- `qwen3.5-4b-mtp-q4`

## Notes

- The first Qwen3.5 4B download stalled near completion and was resumed.
- One concurrent duplicate download failed while writing Hugging Face metadata,
  but the final files were verified by size.
- The Qwen3.5 4B MTP download initially failed through HF Xet with
  `Cannot allocate memory`; retrying with `HF_HUB_DISABLE_XET=1` succeeded.
