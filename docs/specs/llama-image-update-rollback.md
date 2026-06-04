# llama.cpp Image Update And Rollback

## Purpose

The local LLM server depends on the upstream llama.cpp Docker image. MTP flags
and CUDA behavior can change across image updates, so updates must be reversible.

## Known-good Lock

Current known-good image:

```text
ghcr.io/ggml-org/llama.cpp:server-cuda
ghcr.io/ggml-org/llama.cpp@sha256:e8d36f4dc2a72a1df323748f6219c9dd11f662f7cb3b06a6b2916c9bf3866d89
```

The lock file is:

```text
llama-image.lock
```

## Commands

Check local image and lock state:

```bash
./scripts/llama_image.sh status
```

Record the current local image as known-good:

```bash
./scripts/llama_image.sh record-known-good
```

Pull the latest configured image tag:

```bash
./scripts/llama_image.sh update
```

Rollback the configured tag to the locked digest:

```bash
./scripts/llama_image.sh rollback
```

## Update Flow

1. Verify current server:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
./scripts/benchmark_chat.py --profile qwen3.5-2b-q4-xl --preset hermes-summary
```

2. Record the known-good digest:

```bash
./scripts/llama_image.sh record-known-good
```

3. Pull the update:

```bash
./scripts/llama_image.sh update
```

4. Recreate and verify profiles:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
./scripts/run_model_profile.sh qwen3.5-2b-mtp-q4-xl 130000
```

5. Record benchmark results and compare:

```bash
./scripts/benchmark_chat.py --profile qwen3.5-2b-q4-xl --preset hermes-summary
./scripts/benchmark_chat.py --profile qwen3.5-2b-mtp-q4-xl --preset hermes-summary
```

## Rollback Flow

Rollback when health fails, MTP flags disappear, VRAM usage regresses, or
benchmarks materially degrade:

```bash
./scripts/llama_image.sh rollback
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
```

Then rerun smoke and benchmark checks.

## Source Build Policy

Do not build llama.cpp from source by default. The current image supports the
required MTP flags:

```text
--spec-type draft-mtp
--spec-draft-n-max
```

Evaluate a source build only if a future image lacks required flags or a needed
upstream fix is unavailable in the Docker image.
