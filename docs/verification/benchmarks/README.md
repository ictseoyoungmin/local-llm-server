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

For full local-agent capability testing, use:

```text
docs/verification/benchmarks/agent-capability-protocol.md
```

The protocol covers speed, Hermes tool routing, loop resistance, goal
completion, answer quality, and wiki/memory quality.

Available presets:

- `short-ready`: smoke test, not useful as a throughput benchmark.
- `hermes-routing`: Korean task planning prompt for agent routing behavior.
- `hermes-summary`: English verification summary prompt.
- `local-agent-multiturn`: six-message, three-user-turn planning conversation
  for Hermes-agent local model comparison.
- `custom`: use explicit `--system`, `--prompt`, and `--max-tokens`.

Summarize recent records:

```bash
./scripts/summarize_benchmarks.py
```

Local record file:

```text
docs/verification/benchmarks/results/chat-benchmarks.jsonl
```

Committed sample file:

```text
docs/verification/benchmarks/examples/qwen3.5-2b-mtp-q4-xl.sample.jsonl
```

Each record should include:

- selected profile and model
- measurement timestamps: `started_at`, `finished_at`, and runtime `collected_at`
- llama.cpp runtime metadata: `runtime.llama_server_version`,
  `runtime.container_image`, and image digest/creation details when Docker is accessible
- benchmark preset and label
- health metadata, including `n_ctx`
- elapsed wall time
- llama.cpp `timings`
- success or error details

Do not delete failed benchmark rows. Failures are useful for distinguishing
model/runtime regressions from sandbox, Docker, or gateway availability issues.

Local result JSONL files under `results/` are ignored by git. Commit only
curated sample files under `examples/` when a benchmark should become a stable
reference point.
