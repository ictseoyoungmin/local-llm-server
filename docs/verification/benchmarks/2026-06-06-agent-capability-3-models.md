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
| `qwen3.5-2b-q4-xl` | `5` | `5` | `3` | `2` | `2` | `3` | `2` | `1` | `5` | `3.3 / 5` |
| `gemma4-e2b-q4` | `4` | `4` | `3` | `1` | `3` | `3` | `2` | `2` | `4` | `2.9 / 5` |
| `gemma4-e4b-it-qat-q2-xl` | `2` | `1` | `3` | `0` | `0` | `1` | `3` | `0` | `1` | `0.8 / 5` |

Weighted result uses the protocol weights for default Hermes-agent selection:
speed `20%`, stability `20%`, tool use `20%`, goal completion `20%`, loop
resistance `10%`, and wiki/memory quality `10%`.

After the Hermes API compatibility smoke below, stability and operational fit
should be interpreted more strictly:

- `qwen3.5-2b-q4-xl`: remains the safest default candidate.
- `gemma4-e2b-q4`: compatible but slower through the full Hermes API prompt.
- `gemma4-e4b-it-qat-q2-xl`: not suitable as a default at `130000` because the
  Hermes API smoke timed out.

## Hermes API Compatibility Smoke

This smoke uses `./scripts/run_hermes_runtime_example.sh smoke-hostuid`. It sends
a minimal OpenAI-compatible request through the Hermes API server, not directly
to the local gateway. The observed prompt size is about `14.7k-15.1k` tokens
because Hermes adds its runtime/system context.

| Profile | Model | Result | Prompt tokens | Completion tokens | Notes |
| --- | --- | --- | ---: | ---: | --- |
| `qwen3.5-2b-q4-xl` | `qwen3.5-2b-ud-q4-k-xl` | success | `15084` | `41` | returned `hermes gateway local llm ready` |
| `gemma4-e2b-q4` | `gemma-4-E2B-it-Q4_K_M` | success | `14723` | `105` | returned `hermes gateway local llm ready`; much slower than Qwen |
| `gemma4-e4b-it-qat-q2-xl` | `gemma-4-E4B-it-qat-UD-Q2_K_XL` | timeout | n/a | n/a | llama.cpp logs showed `14719` prompt tokens processed after about `219s`, but the Hermes smoke request timed out before a response |

Direct browser runtime smoke was also checked once with:

```bash
./scripts/smoke_hermes_browser_tool.sh
```

Result:

```json
{"success": true, "error": null, "url": "https://example.com", "task_id": "local-llm-browser-smoke"}
```

This confirms the Hermes browser tool runtime is available. It does not yet
prove model-directed tool routing quality, because the browser tool was invoked
directly by the smoke script rather than selected by the model in a chat.

## Tool Routing Notes

| Profile | Tools called | Repeated calls? | Useful citation? | Final answer usable? | Notes |
| --- | --- | --- | --- | --- | --- |
| `qwen3.5-2b-q4-xl` | `browser_navigate` x2 | yes, reached `max-turns=6` | weak | partially | wrong first URL, then official repo; final cited `https://github.com/ggerganov/llama.cpp/README.md`, but max-turn summary was required |
| `gemma4-e2b-q4` | `browser_navigate`, `browser_type`, `browser_press`, `browser_snapshot`, `browser_scroll` | yes, reached `max-turns=6` | no | no | got blocked/limited on Google and returned no usable source URL |
| `gemma4-e4b-it-qat-q2-xl` | not run | n/a | n/a | no | skipped because Hermes API smoke timed out before tool-routing evaluation |

Tool-routing session IDs:

- Qwen: `20260606_125246_40235f`
- Gemma E2B: `20260606_130323_1b40f7`

Both practical models struggled with web tool routing. The issue is partly prompt
and tool choice: the task asked for a public source, but the models overused the
browser instead of choosing a direct terminal/curl or known documentation URL.
This means tool use is available, but model-directed routing quality is not yet
strong enough to trust unattended research tasks.

## Loop Resistance Notes

| Profile | Result | Modified files? | Stopped cleanly? | Notes |
| --- | --- | --- | --- | --- |
| `qwen3.5-2b-q4-xl` | partial | no | yes | asked for more context instead of inspecting docs despite permission; safe but did not complete the requested three tasks |
| `gemma4-e2b-q4` | partial | no | yes | returned exactly three tasks and stopped, but did not inspect docs and tasks were generic |
| `gemma4-e4b-it-qat-q2-xl` | not run | n/a | n/a | skipped because Hermes API smoke timed out |

Loop-resistance session IDs:

- Qwen: `20260606_125722_98f772`
- Gemma E2B: `20260606_130627_b8d3dd`

## Wiki / File Work Notes

| Profile | Files read | Files changed | Duplicate avoided? | Facts vs assumptions separated? | Notes |
| --- | --- | --- | --- | --- | --- |
| `qwen3.5-2b-q4-xl` | `/opt` searched/read | 1 file in Hermes backend workspace | yes | superficially | wrote a wiki page, but hallucinated `Llama3.1-8B-Instruct` as the recommendation and invented sources/dates |
| `gemma4-e2b-q4` | `search_files` for benchmark notes | 1 file in Hermes backend workspace | yes | superficially | wrote a wiki page recommending Gemma E2B, but did not find actual benchmark notes and treated assumptions as facts |
| `gemma4-e4b-it-qat-q2-xl` | not run | not run | n/a | n/a | skipped because Hermes API smoke timed out |

Wiki/file-work session IDs:

- Qwen: `20260606_125812_23ee9d`
- Gemma E2B: `20260606_130736_adb84b`

The file tools worked, but neither model produced a reliable wiki entry from the
available benchmark evidence. The Hermes terminal backend did not expose this
repository's benchmark docs by default, so both models had poor context and
filled gaps with assumptions. For future wiki tests, mount the repository into
the Hermes terminal backend or provide exact source snippets in the prompt.

## Decision

Final decision after quantitative benchmarks, Hermes API smoke, model-directed
tool routing, loop resistance, and wiki/file work:

- Default candidate: `qwen3.5-2b-q4-xl`
- Secondary practical candidate: `gemma4-e2b-q4`
- Specialist/experimental only: `gemma4-e4b-it-qat-q2-xl`

`qwen3.5-2b-q4-xl` wins on operational fit and should remain the default. Its
tool and wiki behavior are not strong, but it is fast enough to iterate and
supervise.

`gemma4-e2b-q4` is a viable fallback when Gemma behavior is desired. It is
slower than Qwen, and its tool/wiki behavior was not better enough to justify
making it the default.

`gemma4-e4b-it-qat-q2-xl` should not be used as a Hermes-agent default at
`130000` context. It completed direct chat benchmarks but failed the full Hermes
API smoke timeout and therefore did not qualify for the remaining tool/wiki
tests.

Next improvement target is not another model benchmark. It is test harness and
prompt/tooling quality:

- mount the repository into the Hermes terminal backend for file/wiki tests
- add a deterministic source URL or web_extract/curl path for research tests
- reduce Hermes prompt/context size or test smaller model contexts
- rerun tool/wiki tests after the harness can expose the actual docs
