# Chat Benchmarks

Benchmark records are append-only JSONL so later work can compare changes
without losing failed attempts.

Record a benchmark:

```bash
./scripts/benchmark_chat.py \
  --profile qwen3.5-2b-mtp-q4-xl \
  --label qwen-mtp-short \
  --timeout 240
```

Use a Hermes-like planning prompt:

```bash
./scripts/benchmark_chat.py \
  --profile qwen3.5-2b-mtp-q4-xl \
  --preset hermes-routing \
  --timeout 300
```

Available presets:

- `short-ready`: smoke test, not useful as a throughput benchmark.
- `hermes-routing`: Korean task planning prompt for agent routing behavior.
- `hermes-summary`: English verification summary prompt.
- `custom`: use explicit `--system`, `--prompt`, and `--max-tokens`.

Summarize recent records:

```bash
./scripts/summarize_benchmarks.py
```

Current record file:

```text
docs/verification/benchmarks/chat-benchmarks.jsonl
```

Each record should include:

- selected profile and model
- benchmark preset and label
- health metadata, including `n_ctx`
- elapsed wall time
- llama.cpp `timings`
- success or error details

Do not delete failed benchmark rows. Failures are useful for distinguishing
model/runtime regressions from sandbox, Docker, or gateway availability issues.
