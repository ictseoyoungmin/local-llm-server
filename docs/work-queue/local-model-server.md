# Local Model Server Work Queue

## Active

- [x] Verify `docker-compose.gpu-mtp.example.yml` with
  `qwen3.5-2b-mtp-q4-xl` and confirm llama.cpp no longer logs
  `no implementations specified for speculative decoding`.
- [x] Run a longer MTP on/off benchmark at `LLAMA_CTX_SIZE=130000`; MTP was
  slower than the non-MTP Qwen Q4 XL profile for the recorded Hermes-summary
  workload.
- [x] Add persistent benchmark records for every benchmark attempt.
- [x] Test `LLAMA_CACHE_TYPE_K=q8_0` and `LLAMA_CACHE_TYPE_V=q8_0` for VRAM and
  speed tradeoffs. q8_0 lowered VRAM but was slower than f16 in recorded
  Hermes-routing benchmarks.
- [x] Add a Hermes-agent smoke test that calls
  `http://host.docker.internal:18080/v1`.
- [x] Add gateway sanitizer for Hermes/Ollama-style request fields that
  llama.cpp rejects.
- [x] Run the official Hermes-agent Docker smoke container against the rebuilt
  gateway and record the result.
- [x] Fix and record hostuid dashboard `/chat` failure where API smoke passed
  but `/api/pty` returned `Chat unavailable: 1`. Resolution: mount a writable
  `HERMES_TUI_DIST_DIR` to `/opt/hermes/ui-tui/dist`.
- [x] Fix and record hostuid browser tool launch failure where
  `browser_navigate` reported `Failed to launch Chrome at ""`. Resolution:
  preserve the compose `PATH` with `/bin/bash -c` and set
  `AGENT_BROWSER_EXECUTABLE_PATH` to the Hermes image's bundled Chromium
  headless shell.

## Next

- [x] Add profile listing to `scripts/run_model_profile.sh`.
- [x] Add a small status command that prints current model, ctx, health, and
  VRAM.
- [x] Decide whether `.env` should remain the default manual configuration or
  be generated from selected model profiles. Decision: profiles are the source
  of truth for switching; `.env` remains a manual fallback and can be generated
  explicitly with `scripts/export_model_profile_env.sh`.
- [x] Add Qwen Q8 profile if Q4 XL quality is insufficient. Profile added as a
  quality fallback; default remains non-MTP Q4 XL based on current benchmarks.
- [ ] Run an end-to-end Hermes tool workflow and record whether llama.cpp
  honors tool schemas for the selected profile/runtime.
- [ ] Add a combined Hermes tool smoke that exercises browser navigation,
  terminal execution, and one local LLM follow-up in the same chat session.
- [x] Apply the local model config to the full
  `/mnt/f/NowWorking/hermes-agent` gateway runtime, excluding secrets, and
  record gateway `/v1/health` plus API request behavior.
- [ ] Diagnose why host access to Hermes `127.0.0.1:8642` is intermittent
  while container-internal API access works.
- [ ] Retest 4B-class non-QAT profiles only when the machine is otherwise idle.
  The first attempt caused severe desktop slowdown while other containers and
  processes were active, so the next pass should isolate one model at a time.
- [ ] Retest `gemma4-e4b-it-qat-q4-xl` with smaller context sizes such as
  `32768` and `65536`. It loads at `130000`, but Hermes-routing timed out after
  420 seconds in the first recorded run.
- [ ] Retest `gemma4-e4b-it-qat-q2-xl` at `32768` and `65536`. It completes
  Hermes-routing at `130000`, unlike Q4, but still took about 87 seconds and
  used roughly 5.4 GiB VRAM in the recorded run.
- [ ] Recheck Qwen3.6 2B availability later. On 2026-06-06, no native
  Qwen3.6 2B Q4 GGUF was found; Unsloth had 27B/35B GGUFs, and the only 2B-class
  related candidate was a Qwen3.5 2B distilled repo with f16/q8 files only.
- [x] Improve the Hermes agent-capability test harness before rerunning
  tool/wiki benchmarks. The 2026-06-06 run showed browser/tool execution works,
  but model-directed web research looped, and the Hermes terminal backend did
  not expose this repository's benchmark docs to the file/wiki task. Resolution:
  add `scripts/run_agent_capability_eval.sh` with bounded one-shot Hermes tasks
  and JSONL result capture.
- [x] Mount this repository into the Hermes terminal backend, or provide exact
  benchmark snippets in the prompt, before scoring wiki/memory quality again.
  Resolution: hostuid compose mounts `${HERMES_REPO_DIR:-.}` read-only at
  `${HERMES_REPO_MOUNT:-/workspace/local-llm-server}`.
- [ ] Rerun the three-model agent capability benchmark with
  `scripts/run_agent_capability_eval.sh` and summarize the JSONL records into
  the dated benchmark report.
- [x] Add `benchmark_chat.py` speed/routing/multiturn runs to
  `scripts/run_agent_capability_eval.sh` so protocol items 1, 2, and 3 are
  executed with the Hermes tool/file checks.

## Later

- [x] Add llama.cpp image/version update support.
- [x] Record the current known-good llama.cpp image digest before updating.
- [x] Add rollback support to return to the previous llama.cpp image/tag/digest.
- [x] Document the update/rollback command flow and failure recovery steps.
- [x] Evaluate building llama.cpp from source only if the container image lacks
  required MTP flags.
