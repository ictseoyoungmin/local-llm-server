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

2026-06-05 20:03-20:08 KST:

- Stopped the running `local-llm-hermes-local-hostuid` compose runtime.
- Moved the existing `.hermes-local-llm-hostuid/` aside to
  `.hermes-local-llm-hostuid.backup.20260605_200350/` instead of deleting it.
- Re-ran the hostuid flow from a fresh data directory:
  - `init-hostuid` kept the existing env and seed config;
  - `up-hostuid` created a new `.hermes-local-llm-hostuid/`;
  - startup logs showed `Seeded /opt/data/config.yaml` and
    `Seeded /opt/data/SOUL.md`;
  - `smoke-hostuid` returned `hermes gateway local llm ready`.
- Smoke usage was `prompt_tokens=14402`, `completion_tokens=50`,
  `total_tokens=14452`.
- Container-internal checks returned 200 for both
  `http://127.0.0.1:8642/v1/health` and `http://127.0.0.1:9119/chat`.
- A non-escalated Codex sandbox curl to Docker-published
  `127.0.0.1:48642/49119` failed with `curl: (7) Couldn't connect to server`.
  Later unrestricted curl showed this was a sandbox artifact, not a runtime
  failure.

2026-06-05 20:13-20:14 KST:

- Rechecked host-published ports without the sandbox network restriction:
  - `http://127.0.0.1:48642/v1/health` returned
    `{"status": "ok", "platform": "hermes-agent"}`;
  - `http://127.0.0.1:49119/chat` returned the dashboard HTML with status 200.
- Re-ran `smoke-hostuid`; it returned `hermes gateway local llm ready` with
  `prompt_tokens=14402`, `completion_tokens=48`, `total_tokens=14450`.
- Conclusion: the fresh hostuid runtime and host-published API/dashboard ports
  are healthy. The earlier connection-refused result was caused by the Codex
  command sandbox.

2026-06-05 20:39-20:41 KST:

- Addressed actionable `hermes doctor` issues for hostuid mode:
  - startup creates `/opt/data/.env` when missing;
  - startup creates `~/.local/bin/hermes` symlink for the container `HOME`;
  - startup appends missing local provider defaults to existing `/opt/data/.env`.
- Added local non-secret defaults:
  - `API_SERVER_KEY=change-me-local-hermes-key`;
  - `OPENAI_BASE_URL=http://host.docker.internal:18080/v1`;
  - `OPENAI_API_KEY=local-not-required`;
  - `GATEWAY_ALLOW_ALL_USERS=true`.
- Re-ran `hermes doctor`. Fixed items:
  - `/opt/data/.env file exists`;
  - `API key or custom endpoint configured`;
  - `~/.local/bin/hermes -> correct target`.
- Remaining doctor issue is expected for a local-only setup:
  `Run 'hermes setup' to configure missing API keys for full tool access`.
  This refers to optional external tool/provider keys such as OpenRouter,
  Discord, web search, and similar integrations.
- Re-ran `smoke-hostuid`; it returned `hermes gateway local llm ready` with
  `prompt_tokens=14608`, `completion_tokens=33`, `total_tokens=14641`.

## 20:55-20:59 KST - Fix Hostuid Browser Chat

- Symptom: `http://localhost:49119/chat?resume=20260605_111558_c4f41d`
  loaded the dashboard but the terminal showed `Chat unavailable: 1`.
- Root cause:
  - dashboard `/chat` uses `/api/pty`;
  - `/api/pty` spawns the embedded Node TUI;
  - Hermes rebuilds `ui-tui/dist/entry.js` before spawning;
  - hostuid mode runs the container as uid/gid 1000, which cannot write inside
    the image-owned `/opt/hermes/ui-tui/dist`.
- Evidence before fix:
  - container logs showed `TUI build failed`;
  - esbuild failed with `permission denied` on
    `/opt/hermes/ui-tui/dist/entry.js`;
  - API smoke still passed, so this was specific to browser chat.
- Fix:
  - added `HERMES_TUI_DIST_DIR=./.hermes-local-llm-hostuid-ui-tui-dist`;
  - mounted it to `/opt/hermes/ui-tui/dist` in
    `docker-compose.hermes-local-llm.yml`;
  - made `init-hostuid` create both the Hermes data directory and the TUI dist
    directory;
  - added the TUI dist directory to `.gitignore`.
- Verification after recreating the container:
  - direct websocket check against
    `/api/pty?resume=20260605_111558_c4f41d` returned
    `101 Switching Protocols`;
  - websocket payload contained terminal bytes instead of `Chat unavailable`;
  - `/opt/hermes/ui-tui/dist/entry.js` was created as uid/gid 1000;
  - `smoke-hostuid` returned `hermes gateway local llm ready` with
    `prompt_tokens=14608`, `completion_tokens=31`, `total_tokens=14639`.

## 23:19-23:35 KST - Fix Hostuid Browser Tool Launch

- Symptom: dashboard chat could call `browser_navigate`, but the tool could not
  open external pages. The UI looked like an internet problem.
- Network check:
  - `getent hosts search.google.com` resolved addresses inside the container;
  - `curl -I -L --max-time 10 https://search.google.com/search?...` reached
    Google and returned HTTP, so Docker DNS/egress was not the primary failure.
- Actual failure from Hermes logs:
  - `browser_navigate` returned
    `Failed to launch Chrome at "": No such file or directory`.
- Root causes:
  - `.env.hermes-local-llm-hostuid` had `AGENT_BROWSER_EXECUTABLE_PATH=` as an
    explicit empty value;
  - `docker-compose.hermes-local-llm.yml` used `/bin/bash -lc`, so the login
    shell reset `PATH` and hid `/opt/hermes/node_modules/.bin` from process
    env.
- Fix:
  - set `AGENT_BROWSER_EXECUTABLE_PATH` to the bundled executable:
    `/opt/hermes/.playwright/chromium_headless_shell-1217/chrome-headless-shell-linux64/chrome-headless-shell`;
  - set `PLAYWRIGHT_BROWSERS_PATH=/opt/hermes/.playwright`;
  - changed the compose entrypoint from `/bin/bash -lc` to `/bin/bash -c`;
  - added `scripts/smoke_hermes_browser_tool.sh`.
- Verification after recreating the container:
  - process env preserved
    `/opt/hermes/.venv/bin:/opt/hermes/node_modules/.bin:...`;
  - `./scripts/smoke_hermes_browser_tool.sh` returned
    `{"success": true, "error": null, "url": "https://example.com"}`;
  - `smoke-hostuid` still returned `hermes gateway local llm ready` with
    `prompt_tokens=14608`, `completion_tokens=31`, `total_tokens=14639`.
