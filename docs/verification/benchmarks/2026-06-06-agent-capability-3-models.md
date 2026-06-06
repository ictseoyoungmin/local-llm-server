# 2026-06-06 Agent Capability Three-Model Benchmark

## Purpose

Compare three local model profiles for practical Hermes-agent and local-agent
work. This result sheet uses the protocol in
`docs/verification/benchmarks/agent-capability-protocol.md`.

## Candidates

| Profile | Model | Role |
| --- | --- | --- |
| `qwen3.5-2b-q4-xl` | `qwen3.5-2b-ud-q4-k-xl` | current practical Qwen baseline |
| `gemma4-e2b-q4` | `gemma-4-E2B-it-Q4_K_M` | current practical Gemma baseline |
| `gemma4-e4b-it-qat-q2-xl` | `gemma-4-E4B-it-qat-UD-Q2_K_XL` | slower quality candidate |

## Runtime Setup

Use requested context `130000` unless a test explicitly records a smaller
context. Run one model at a time.

For each candidate:

```bash
./scripts/run_model_profile.sh <profile> 130000
curl -fsS http://127.0.0.1:18080/v1/health
```

## Quantitative Results

| Profile | Test | Success | Elapsed ms | Prompt tok/s | Generation tok/s | VRAM | Notes |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `qwen3.5-2b-q4-xl` | short-ready cold | yes | `93044.380` | `0.270` | `8.297` | `~4.4 GiB` | cold 130k prefill dominates |
| `qwen3.5-2b-q4-xl` | short-ready warm | yes | `119.341` | `234.780` | `121.007` | `~4.4 GiB` | fastest warm smoke |
| `qwen3.5-2b-q4-xl` | hermes-routing | yes | `2271.417` | `148.370` | `58.392` | `~4.4 GiB` | fastest routing |
| `qwen3.5-2b-q4-xl` | local-agent-multiturn | yes | `8098.432` | `262.984` | `57.889` | `~4.4 GiB` | hit `max_tokens`, usable speed |
| `gemma4-e2b-q4` | short-ready cold | yes | `65230.692` | `0.406` | `0.182` | `~3.9 GiB` | cold generation unusually slow |
| `gemma4-e2b-q4` | short-ready warm | yes | `337.058` | `43.182` | `96.413` | `~3.9 GiB` | warm smoke practical |
| `gemma4-e2b-q4` | hermes-routing | yes | `4485.415` | `76.833` | `39.957` | `~3.9 GiB` | practical routing |
| `gemma4-e2b-q4` | local-agent-multiturn | yes | `12669.441` | `74.913` | `42.103` | `~3.9 GiB` | hit `max_tokens`, practical speed |
| `gemma4-e4b-it-qat-q2-xl` | short-ready cold | yes | `69654.537` | `0.317` | `17.161` | `~5.4 GiB` | cold prefill still high |
| `gemma4-e4b-it-qat-q2-xl` | short-ready warm | yes | `2107.149` | `6.892` | `12.591` | `~5.4 GiB` | passes warm rule but slower |
| `gemma4-e4b-it-qat-q2-xl` | hermes-routing | yes | `34047.131` | `22.995` | `7.205` | `~5.4 GiB` | completed, too slow for default |
| `gemma4-e4b-it-qat-q2-xl` | local-agent-multiturn | yes | `64422.232` | `37.033` | `7.187` | `~5.4 GiB` | hit `max_tokens`, slow |

## Quantitative Interpretation

`qwen3.5-2b-q4-xl` is the fastest operational profile after warmup. It completed
Hermes-routing in about `2.27s` and the multiturn preset in about `8.10s`.

`gemma4-e2b-q4` remains practical. It is slower than Qwen on routing and
multiturn work, but its warm smoke and agent-style prompts complete comfortably.
It also used less observed VRAM than Qwen in this run.

`gemma4-e4b-it-qat-q2-xl` is usable but not a default candidate at `130000`
context. It completed the tests, unlike the earlier Q4 timeout, but routing took
about `34s` and multiturn took about `64s`.

## Agent Capability Scores

Score each item from `0` to `5`.

| Profile | Speed | Stability | Instruction following | Tool use | Loop resistance | Goal completion | Answer quality | Wiki/memory quality | Operational fit | Weighted result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `qwen3.5-2b-q4-xl` | `5` | `5` | `4` | pending | pending | `4` | `3` | pending | `5` | pending |
| `gemma4-e2b-q4` | `4` | `4` | `4` | pending | pending | `4` | `3` | pending | `4` | pending |
| `gemma4-e4b-it-qat-q2-xl` | `2` | `3` | `3` | pending | pending | `3` | `3` | pending | `2` | pending |

These are preliminary scores from the quantitative chat benchmarks only. Tool
use, loop resistance, and wiki/memory quality require Hermes-agent tool runs and
must remain pending until those tests are executed.

## Tool Routing Notes

| Profile | Tools called | Repeated calls? | Useful citation? | Final answer usable? | Notes |
| --- | --- | --- | --- | --- | --- |
| `qwen3.5-2b-q4-xl` | pending | pending | pending | pending |  |
| `gemma4-e2b-q4` | pending | pending | pending | pending |  |
| `gemma4-e4b-it-qat-q2-xl` | pending | pending | pending | pending |  |

## Wiki / File Work Notes

| Profile | Files read | Files changed | Duplicate avoided? | Facts vs assumptions separated? | Notes |
| --- | --- | --- | --- | --- | --- |
| `qwen3.5-2b-q4-xl` | pending | pending | pending | pending |  |
| `gemma4-e2b-q4` | pending | pending | pending | pending |  |
| `gemma4-e4b-it-qat-q2-xl` | pending | pending | pending | pending |  |

## Decision

Pending. The default model should be chosen by operational fit, not just answer
quality. A slower model can remain a specialist candidate for wiki-building or
deep summarization if it scores well on quality and loop resistance.
