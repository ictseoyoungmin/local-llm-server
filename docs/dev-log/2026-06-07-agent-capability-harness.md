# 2026-06-07 Agent Capability Harness

## Context

The 2026-06-06 three-model evaluation showed that the local model server and
Hermes browser/terminal tools can run, but the model-directed tests were too
loose for reliable comparison. The wiki/file task also could not read this
repository because the Hermes terminal backend did not mount the checkout.

## Changes

- Added a read-only repository mount to `docker-compose.hermes-local-llm.yml`:
  `${HERMES_REPO_DIR:-.}` to
  `${HERMES_REPO_MOUNT:-/workspace/local-llm-server}`.
- Added default mount variables to
  `examples/hermes-agent/hermes-local-llm.hostuid.env.example`.
- Made `scripts/run_hermes_runtime_example.sh init-hostuid` append missing
  non-secret mount defaults to an existing `.env.hermes-local-llm-hostuid`.
- Added `scripts/run_agent_capability_eval.sh` for repeated Hermes
  agent-capability runs.
- Extended the harness to run `benchmark_chat.py` speed smoke, Hermes routing,
  and local-agent multiturn before the Hermes tool/file checks.
- Added a wiki artifact existence check for the file produced by the
  wiki/file-work task.

## Harness Behavior

For each selected profile, the harness:

1. starts the local model profile at the requested context size,
2. starts the hostuid Hermes runtime,
3. verifies `agent-capability-protocol.md` is readable inside the Hermes
   container,
4. runs the hostuid API smoke check,
5. runs `benchmark_chat.py` short-ready cold/warm, Hermes routing, and
   local-agent multiturn,
6. runs bounded Hermes one-shot tasks for tool routing, loop resistance, and
   wiki/file work,
7. verifies the expected wiki artifact exists under `/opt/data/workspace`.

Raw JSONL rows are written to
`docs/verification/benchmarks/results/agent-capability-runs.jsonl`. Per-test
terminal output is written under the ignored
`docs/verification/benchmarks/results/agentcap/` directory.

## Verification

Completed before commit:

```bash
bash -n scripts/run_agent_capability_eval.sh
AGENTCAP_DRY_RUN=1 ./scripts/run_agent_capability_eval.sh qwen3.5-2b-q4-xl
./scripts/run_hermes_runtime_example.sh init-hostuid
docker compose -f docker-compose.hermes-local-llm.yml --env-file .env.hermes-local-llm-hostuid config
docker exec local-llm-hermes-local-hostuid test -r /workspace/local-llm-server/docs/verification/benchmarks/agent-capability-protocol.md
docker exec local-llm-hermes-local-hostuid /opt/hermes/.venv/bin/hermes doctor
```

Results:

- Dry-run printed the expected profile start, hostuid start, mount check,
  smoke, and three bounded Hermes chat tasks.
- Compose config resolved the read-only repo mount from this checkout to
  `/workspace/local-llm-server`.
- Container mount check passed.
- `hermes doctor` reported `/opt/data/.env`, `config.yaml`, directory
  structure, built-in memory, browser, terminal, file, and core tools as
  available. Remaining warnings were expected missing optional external API
  credentials and optional integrations.

Full three-model rerun is left as the next benchmark slice because it can take
longer and may disturb the desktop when 4B-class profiles are active.

## Rerun Result

The three-model rerun completed on 2026-06-07 and is summarized in
`docs/verification/benchmarks/2026-06-07-agent-capability-rerun.md`.

Important follow-ups from the rerun:

- The top-level Hermes container can read the repo mount, but Hermes
  model-invoked terminal/file tools still reported the benchmark docs path as
  missing.
- Each profile switch hit one startup-time gateway health reset before later
  health/benchmark calls succeeded.
- `gemma4-e4b-it-qat-q2-xl` loaded at 130k context but was too slow for routine
  Hermes-agent use and timed out on loop/wiki tasks.

## Post-Rerun Fixes

- Restored the default local model to `qwen3.5-2b-q4-xl`.
- Added retry/backoff to `scripts/smoke_hermes_runtime.sh` before checking the
  local LLM gateway.
- Set hostuid Hermes terminal config to use `/workspace/local-llm-server` and
  nested `docker_volumes` so Hermes tool containers can read the repository.
- Added the hostuid Hermes data directory to nested `docker_volumes` at
  `/opt/data` so tool-created wiki artifacts persist in the same workspace that
  the top-level Hermes runtime checks.
- Added a deterministic local tool-routing fixture at
  `docs/verification/benchmarks/fixtures/llama-server-openai-api.md`.

Verification:

- `./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000` restored the gateway
  health to `qwen3.5-2b-ud-q4-k-xl`.
- `./scripts/run_hermes_runtime_example.sh smoke-hostuid` reached the Hermes
  API and returned a local-model response.
- A Qwen terminal-tool smoke returned `WORKSPACE_OK`; logs showed nested Docker
  volume
  `/mnt/f/NowWorking/Local-LLM-Server:/workspace/local-llm-server:ro`.

Post-fix rerun:

- `./scripts/run_agent_capability_eval.sh qwen3.5-2b-q4-xl gemma4-e2b-q4`
  completed on 2026-06-07 18:37 KST.
- Qwen and Gemma E2B both passed deterministic tool-routing and wiki artifact
  checks after `/opt/data` was mounted into nested tool containers.
- Qwen remains the default recommendation because it was faster on routing and
  multiturn work.
- Both 2B profiles still misread the benchmark directory in loop-resistance
  tasks, so unattended wiki-building quality remains a prompt/harness issue.
