# 2026-06-04 Local Agent Multiturn Benchmark

## Setup

- Hardware: NVIDIA GeForce GTX 1660 6GB.
- Endpoint: `http://127.0.0.1:18080/v1`.
- Context: `LLAMA_CTX_SIZE=130000`, observed `n_ctx=130048`.
- Preset: `local-agent-multiturn`.
- Conversation shape: six messages, three user turns.
- Max tokens: 420.

## Results

| Profile | Label | Result | Elapsed ms | Prompt tok/s | Generate tok/s | Cache |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `gemma4-e2b-q4` | `gemma4-local-agent-multiturn-cold` | success | 87668.935 | 3.46 | 15.93 | 0 |
| `gemma4-e2b-q4` | `gemma4-local-agent-multiturn-warm` | success | 9861.043 | 19.55 | 44.02 | 207 |
| `qwen3.5-2b-q4-xl` | `qwen35-local-agent-multiturn-cold` | success | 109229.987 | 1.96 | 57.50 | 0 |
| `qwen3.5-2b-q4-xl` | `qwen35-local-agent-multiturn-warm` | success | 7117.498 | 22.22 | 61.33 | 196 |

One failed Gemma row was also recorded before escalation because the sandbox
blocked localhost HTTP access. Keep it in the local JSONL as an environment
failure reference, not a model failure.

## Interpretation

- Both models can serve the three-turn benchmark at `n_ctx=130048` on 6GB VRAM.
- Qwen Q4 XL is faster in warm generation and total warm elapsed time.
- Gemma cold prompt processing was faster than Qwen in this run, but Qwen
  generated much faster once decoding started.
- For Hermes-agent style repeated calls, Qwen Q4 XL is the stronger default
  candidate based on warm latency and generation throughput.
- Cold prompt processing remains the main risk for both profiles, especially
  Qwen; benchmark records should keep separating cold and warm runs.
