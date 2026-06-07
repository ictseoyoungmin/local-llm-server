# 2026-06-07 Agent Capability Rerun

## Purpose

Rerun the three-model Hermes/local-agent benchmark after adding the maintained
agent-capability harness and read-only repository mount.

Protocol:
`docs/verification/benchmarks/agent-capability-protocol.md`

Harness:

```bash
./scripts/run_agent_capability_eval.sh qwen3.5-2b-q4-xl gemma4-e2b-q4 gemma4-e4b-it-qat-q2-xl
```

## Runtime

| Item | Value |
| --- | --- |
| Date | 2026-06-07 KST |
| Context | `130000` requested, llama.cpp health reported `130048` |
| llama.cpp image | `ghcr.io/ggml-org/llama.cpp:server-cuda` |
| llama.cpp digest | `sha256:bdc62a30471f456cbeee251c565f555d486d0ef4451f27f92ec9b4a9ed966eab` |
| llama.cpp version | `9501 (65ef50a0a)` |
| Host GPU | GTX 1660 6GB |
| Hermes runtime | `docker-compose.hermes-local-llm.yml` hostuid mode |

During each profile switch the first Hermes smoke check against
`http://127.0.0.1:18080/v1/health` returned `curl: (56) Recv failure:
Connection reset by peer`. Subsequent direct health and benchmark calls
succeeded. Treat this as a gateway start race, not a model load failure.

## Quantitative Results

`Harness elapsed` is the wrapper command time. `Chat elapsed` and token rates
come from `benchmark_chat.py`.

| Profile | Test | Status | Harness elapsed | Chat elapsed | Prompt tok/s | Generation tok/s | Notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| `qwen3.5-2b-q4-xl` | short-ready cold | success | `119s` | `106.716s` | `0.235` | `14.236` | cold 130k prefill dominates |
| `qwen3.5-2b-q4-xl` | short-ready warm | success | `3s` | `0.301s` | `63.839` | `124.603` | fastest warm smoke |
| `qwen3.5-2b-q4-xl` | Hermes routing | success | `4s` | `2.630s` | `125.512` | `51.193` | fastest routing |
| `qwen3.5-2b-q4-xl` | multiturn | success | `11s` | `10.702s` | `117.653` | `47.443` | practical speed |
| `gemma4-e2b-q4` | short-ready cold | success | `74s` | `62.358s` | `0.441` | `0.161` | cold generation very slow |
| `gemma4-e2b-q4` | short-ready warm | success | `1s` | `0.139s` | `131.572` | `88.751` | fastest wall-clock warm smoke |
| `gemma4-e2b-q4` | Hermes routing | success | `5s` | `4.595s` | `88.961` | `36.112` | practical routing |
| `gemma4-e2b-q4` | multiturn | success | `13s` | `12.035s` | `115.501` | `40.855` | practical speed |
| `gemma4-e4b-it-qat-q2-xl` | short-ready cold | success | `90s` | `78.869s` | `0.281` | `8.456` | high cold cost |
| `gemma4-e4b-it-qat-q2-xl` | short-ready warm | success | `14s` | `2.043s` | `7.514` | `18.941` | slower than 2B profiles |
| `gemma4-e4b-it-qat-q2-xl` | Hermes routing | success | `48s` | `39.055s` | `20.384` | `6.295` | too slow for default agent use |
| `gemma4-e4b-it-qat-q2-xl` | multiturn | success | `76s` | `63.299s` | `43.290` | `7.226` | too slow for routine use |

## Hermes Tool/File Results

| Profile | Tool routing | Loop resistance | Wiki/file work | Artifact check | Notes |
| --- | --- | --- | --- | --- | --- |
| `qwen3.5-2b-q4-xl` | success, `74s` | success, `50s` | success, `75s` | failed | hit `max-turns=6`; handled 404s but did not reach useful citation; Hermes tool environment could not read `/workspace/local-llm-server/docs/verification/benchmarks` |
| `gemma4-e2b-q4` | success, `123s` | success, `50s` | success, `82s` | failed | final tool answer was short but no useful source; loop task returned exactly three items, but generic because repo path was not visible |
| `gemma4-e4b-it-qat-q2-xl` | success, `282s` | timeout, `301s` | timeout, `422s` | success after delayed check | too slow; loop and wiki tasks exceeded bounds |

Session IDs:

- Qwen tool: `20260607_060823_802d54`
- Qwen loop: `20260607_060926_f24907`
- Qwen wiki: `20260607_061017_805e47`
- Gemma E2B tool: `20260607_061715_91908a`
- Gemma E2B loop: `20260607_061909_9f9e09`
- Gemma E2B wiki: `20260607_061954_a9ac13`
- QAT Q2 tool: `20260607_063253_2d188e`

## Key Findings

The read-only repo mount is visible to `docker exec`, but Hermes tool execution
still reported `/workspace/local-llm-server/docs/verification/benchmarks` as
missing for Qwen and Gemma E2B. This means the current mount is not enough for
the Hermes terminal/file tool sandbox. The next fix should expose the repo to
the actual tool execution workspace, not only to the top-level gateway
container.

Both 2B profiles completed all bounded Hermes chat tasks without shell-level
timeouts, but neither produced reliable tool/wiki output. Tool routing still
needs deterministic URLs or a terminal/curl-first task that points to a known
existing file. The URL used in this run returned 404 and degraded all three
tool-routing scores.

`gemma4-e4b-it-qat-q2-xl` can load at 130k context on the GTX 1660 6GB, but it
is not a practical default. It used about 5.5 GiB observed VRAM during the run,
generated around `6-7 tok/s` on routing/multiturn, and timed out on loop/wiki
tasks.

## Scores

Scores are `0-5` and use the protocol categories. Weighted result uses speed
20%, stability 20%, tool use 20%, goal completion 20%, loop resistance 10%,
wiki/memory quality 10%.

| Profile | Speed | Stability | Instruction following | Tool use | Loop resistance | Goal completion | Answer quality | Wiki/memory quality | Operational fit | Weighted result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `qwen3.5-2b-q4-xl` | `5` | `4` | `3` | `2` | `2` | `3` | `2` | `1` | `5` | `3.1 / 5` |
| `gemma4-e2b-q4` | `4` | `4` | `3` | `2` | `3` | `3` | `2` | `1` | `4` | `3.0 / 5` |
| `gemma4-e4b-it-qat-q2-xl` | `1` | `2` | `2` | `1` | `0` | `1` | `2` | `1` | `1` | `1.2 / 5` |

## Decision

Default remains `qwen3.5-2b-q4-xl`.

`gemma4-e2b-q4` remains the practical fallback. In this run it was close to
Qwen for warm smoke and only slightly slower on routing/multiturn, but it did
not solve the Hermes tool/wiki reliability problems.

`gemma4-e4b-it-qat-q2-xl` should stay experimental at `130000` context. It is
too slow for everyday Hermes-agent use on this 6GB VRAM machine.

## Follow-up

- Fixed after this rerun: Hermes terminal/file tool workspace visibility for
  the repo mount by configuring nested `terminal.docker_volumes`.
- Fixed after this rerun: replaced the drifting tool-routing URL with the local
  deterministic fixture
  `docs/verification/benchmarks/fixtures/llama-server-openai-api.md`.
- Fixed after this rerun: added startup wait/retry before Hermes smoke to avoid
  the repeated gateway `connection reset by peer` race.
- Keep QAT Q2 tests for isolated/idle runs or smaller contexts such as `32768`
  and `65536`.
