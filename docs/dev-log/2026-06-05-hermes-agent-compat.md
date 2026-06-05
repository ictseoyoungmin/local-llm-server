# 2026-06-05 Hermes-agent Compatibility

## Goal

Make Hermes-agent usable against this project's local llama.cpp backend through
a stable custom OpenAI-compatible endpoint.

## Source Read

Hermes-agent's provider documentation describes custom self-hosted endpoints
through `model.provider: custom`, `model.base_url`, `model.default`, and
`model.api_key`. The Docker documentation describes the official
`nousresearch/hermes-agent` image and `/opt/data` persistent config volume.

## Implementation Plan

- Keep Hermes-agent pointed at the FastAPI gateway, not raw llama.cpp.
- Strip known llama.cpp-incompatible top-level fields from request bodies:
  `extra_body`, `options`, and `num_ctx`.
- Preserve `tools` and `tool_choice` so actual tool behavior can be measured
  rather than hidden by the proxy.
- Add a separate Hermes smoke container using the official Docker image.
- Record every actual smoke run in
  `docs/verification/hermes-agent-compatibility.md`.

## Notes

Request-level context fields from Hermes or Ollama-compatible clients are not
used for server sizing. Context remains a profile/runtime concern:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
```

## Verification

2026-06-05 15:10-15:14 KST:

- Rebuilt the gateway image with sanitizer support.
- Re-applied `qwen3.5-2b-q4-xl` at requested context `130000`.
- Health reported `model_name=qwen3.5-2b-ud-q4-k-xl` and upstream
  `n_ctx=130048`.
- `scripts/smoke_hermes_agent.sh` confirmed the sanitizer header for
  `extra_body`, `options`, and `num_ctx`.
- The official `nousresearch/hermes-agent:latest` image digest
  `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33`
  returned:

```text
hermes local provider ready
```

The official image wrapper performed long recursive ownership changes on this
host before one-shot execution. The smoke compose now invokes
`/opt/hermes/.venv/bin/hermes` directly for one-shot verification only.

2026-06-05 19:20-19:23 KST:

- Added a host-bind, host-uid env example for
  `docker-compose.hermes-local-llm.yml`:
  `examples/hermes-agent/hermes-local-llm.hostuid.env.example`.
- The compose merged as `user: 1000:1000`, mounted
  `./.hermes-local-llm-hostuid` to `/opt/data`, and used ports
  `48642/49119`.
- This mode bypasses the official Docker wrapper and directly executes
  `/opt/hermes/.venv/bin/hermes gateway run`.
- `HERMES_CONTAINER=local-llm-hermes-local-hostuid
  ./scripts/smoke_hermes_runtime.sh` completed through the Hermes API server
  and returned:

```text
hermes gateway local llm ready
```

- Usage was `prompt_tokens=14402`, `completion_tokens=41`,
  `total_tokens=14443`.
- The test created `state.db`, `state.db-wal`, `response_store.db`,
  `response_store.db-wal`, `kanban.db`, and a session file in the host-bound
  data directory as the WSL host user.
- This separates two behaviors:
  - wrapper-based host-uid mode still stalls while changing ownership of
    `/opt/hermes/.venv`;
  - direct-entrypoint host-uid mode works on this WSL/DrvFS host.

2026-06-05 19:34-19:35 KST:

- Added hostuid subcommands to `scripts/run_hermes_runtime_example.sh`:
  `init-hostuid`, `up-hostuid`, `smoke-hostuid`, `status-hostuid`,
  `down-hostuid`, and `logs-hostuid`.
- Verified the new wrapper interface:
  - `up-hostuid` started `local-llm-hermes-local-hostuid`;
  - `smoke-hostuid` returned `hermes gateway local llm ready`;
  - `status-hostuid` showed ports `48642->8642` and `49119->9119`;
  - `down-hostuid` stopped and removed the container/network.
- Smoke usage was `prompt_tokens=14402`, `completion_tokens=29`,
  `total_tokens=14431`.

2026-06-05 19:46-19:48 KST:

- Added `HERMES_OVERWRITE_CONFIG` guard to `docker-compose.hermes-local-llm.yml`.
- Default `HERMES_OVERWRITE_CONFIG=0` keeps existing `/opt/data/config.yaml`
  and `/opt/data/SOUL.md` on hostuid startup.
- If set to `1`, the runtime writes timestamped `.bak` files before reseeding
  those files from `.hermes-runtime-example/`.
- Reverified `up-hostuid`, logs, `smoke-hostuid`, and `down-hostuid`.
- Startup logs confirmed both seed files were kept, and smoke returned
  `hermes gateway local llm ready` with `prompt_tokens=14402`,
  `completion_tokens=39`, `total_tokens=14441`.
