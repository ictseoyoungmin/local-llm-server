# 2026-06-04 Local Agent Multiturn Benchmark

## Setup

- Hardware: NVIDIA GeForce GTX 1660 6GB.
- Endpoint: `http://127.0.0.1:18080/v1`.
- Context: `LLAMA_CTX_SIZE=130000`, observed `n_ctx=130048`.
- Preset: `local-agent-multiturn`.
- Conversation shape: six messages, three user turns.
- Max tokens: 420.

## llama.cpp Runtimes

| Runtime | Measured at | llama-server version | Image digest | Image created |
| --- | --- | --- | --- | --- |
| Previous local image | 2026-06-04 18:34-18:41 KST | `9294 (0f3cb3fc8)` | `sha256:e8d36f4dc2a72a1df323748f6219c9dd11f662f7cb3b06a6b2916c9bf3866d89` | 2026-05-23 16:00:36 KST |
| Latest pulled image | 2026-06-05 14:04-14:13 KST | `9501 (65ef50a0a)` | `sha256:bdc62a30471f456cbeee251c565f555d486d0ef4451f27f92ec9b4a9ed966eab` | 2026-06-04 16:15:50 KST |

The 2026-06-05 rows were recorded after `./scripts/llama_image.sh update`.
The JSONL benchmark records include `started_at`, `finished_at`, and `runtime`
metadata.

## Results: Previous Local Image

| Profile | Label | Result | Elapsed ms | Prompt tok/s | Generate tok/s | Cache |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `gemma4-e2b-q4` | `gemma4-local-agent-multiturn-cold` | success | 87668.935 | 3.46 | 15.93 | 0 |
| `gemma4-e2b-q4` | `gemma4-local-agent-multiturn-warm` | success | 9861.043 | 19.55 | 44.02 | 207 |
| `qwen3.5-2b-q4-xl` | `qwen35-local-agent-multiturn-cold` | success | 109229.987 | 1.96 | 57.50 | 0 |
| `qwen3.5-2b-q4-xl` | `qwen35-local-agent-multiturn-warm` | success | 7117.498 | 22.22 | 61.33 | 196 |

One failed Gemma row was also recorded before escalation because the sandbox
blocked localhost HTTP access. Keep it in the local JSONL as an environment
failure reference, not a model failure.

## Results: Latest Pulled Image

| Profile | Label | Result | Elapsed ms | Prompt tok/s | Generate tok/s | Cache |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `qwen3.5-2b-q4-xl` | `qwen35-local-agent-multiturn-llama9501-cold` | success | 109096.746 | 2.00 | 46.69 | 0 |
| `qwen3.5-2b-q4-xl` | `qwen35-local-agent-multiturn-llama9501-warm` | success | 7741.983 | 109.65 | 58.24 | 161 |
| `gemma4-e2b-q4` | `gemma4-local-agent-multiturn-llama9501-cold` | success | 76876.104 | 3.88 | 18.91 | 0 |
| `gemma4-e2b-q4` | `gemma4-local-agent-multiturn-llama9501-warm` | success | 9623.800 | 110.44 | 44.40 | 173 |

## Interpretation

- Both models can serve the three-turn benchmark at `n_ctx=130048` on 6GB VRAM.
- On the latest pulled image, Qwen Q4 XL remains faster in warm total elapsed
  time than Gemma, but its generation throughput dropped from 61.33 tok/s to
  58.24 tok/s.
- Gemma improved on latest cold elapsed time and cold generation throughput.
- Gemma warm throughput stayed effectively flat: 44.02 tok/s to 44.40 tok/s.
- For Hermes-agent style repeated calls, Qwen Q4 XL remains the stronger
  default candidate based on warm latency, but the latest image is not a clear
  universal speed upgrade.
- Cold prompt processing remains the main risk for both profiles, especially
  Qwen; benchmark records should keep separating cold and warm runs.
