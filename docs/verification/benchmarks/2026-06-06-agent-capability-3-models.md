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
| `qwen3.5-2b-q4-xl` | short-ready cold | pending |  |  |  |  |  |
| `qwen3.5-2b-q4-xl` | short-ready warm | pending |  |  |  |  |  |
| `qwen3.5-2b-q4-xl` | hermes-routing | pending |  |  |  |  |  |
| `qwen3.5-2b-q4-xl` | local-agent-multiturn | pending |  |  |  |  |  |
| `gemma4-e2b-q4` | short-ready cold | pending |  |  |  |  |  |
| `gemma4-e2b-q4` | short-ready warm | pending |  |  |  |  |  |
| `gemma4-e2b-q4` | hermes-routing | pending |  |  |  |  |  |
| `gemma4-e2b-q4` | local-agent-multiturn | pending |  |  |  |  |  |
| `gemma4-e4b-it-qat-q2-xl` | short-ready cold | pending |  |  |  |  |  |
| `gemma4-e4b-it-qat-q2-xl` | short-ready warm | pending |  |  |  |  |  |
| `gemma4-e4b-it-qat-q2-xl` | hermes-routing | pending |  |  |  |  |  |
| `gemma4-e4b-it-qat-q2-xl` | local-agent-multiturn | pending |  |  |  |  |  |

## Agent Capability Scores

Score each item from `0` to `5`.

| Profile | Speed | Stability | Instruction following | Tool use | Loop resistance | Goal completion | Answer quality | Wiki/memory quality | Operational fit | Weighted result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `qwen3.5-2b-q4-xl` | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| `gemma4-e2b-q4` | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| `gemma4-e4b-it-qat-q2-xl` | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |

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
