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
- health metadata, including `n_ctx`
- elapsed wall time
- llama.cpp `timings`
- success or error details

Do not delete failed benchmark rows. Failures are useful for distinguishing
model/runtime regressions from sandbox, Docker, or gateway availability issues.
