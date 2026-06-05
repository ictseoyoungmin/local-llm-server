# Hermes-agent Compatibility Verification

This file records observed Hermes-agent container compatibility with this
project's gateway and llama.cpp runtime.

## Test Contract

Run:

```bash
./scripts/smoke_hermes_agent.sh
```

The script must verify:

- host gateway health at `http://127.0.0.1:18080/v1/health`;
- gateway sanitizer for `extra_body`, `options`, and `num_ctx`;
- official `nousresearch/hermes-agent` Docker image one-shot request through
  `http://host.docker.internal:18080/v1`.

## Results

| Measured at | Hermes image | llama-server version | Profile | Result | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-06-05 15:10-15:14 KST | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | `9501 (65ef50a0a)` | `qwen3.5-2b-q4-xl` / `qwen3.5-2b-ud-q4-k-xl` | OK | Gateway health OK with `n_ctx=130048`; sanitizer request returned `X-Local-LLM-Sanitized-Fields`; official Hermes image one-shot returned `hermes local provider ready`. Smoke compose uses direct `/opt/hermes/.venv/bin/hermes` entrypoint to avoid wrapper chown delay on this host. |
| 2026-06-05 15:46-15:53 KST | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | `9501 (65ef50a0a)` | `qwen3.5-2b-q4-xl` / `qwen3.5-2b-ud-q4-k-xl` | OK with caveat | Full `/mnt/f/NowWorking/hermes-agent` gateway runtime was configured as `provider: custom` with `base_url: http://host.docker.internal:18080/v1`. Backup created at `/mnt/f/NowWorking/hermes-agent/.hermes/config.yaml.bak.20260605_154619_local_llm`. Hermes internal API request returned `hermes gateway local llm ready`. llama.cpp logged `prompt eval time = 22052.61 ms / 11946 tokens` and `eval time = 568.15 ms / 36 tokens`. Host access to `127.0.0.1:8642` was intermittent after startup, while container-internal `127.0.0.1:8642` stayed usable. |
| 2026-06-05 15:55 KST | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | `9501 (65ef50a0a)` | `qwen3.5-2b-q4-xl` / `qwen3.5-2b-ud-q4-k-xl` | OK | `./scripts/smoke_hermes_runtime.sh` completed through the full Hermes gateway runtime and returned `hermes gateway local llm ready`; usage was `prompt_tokens=11946`, `completion_tokens=44`, `total_tokens=11990`. |
| 2026-06-05 16:43 KST | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | `9501 (65ef50a0a)` | `qwen3.5-2b-q4-xl` / `qwen3.5-2b-ud-q4-k-xl` | OK | Repository-local `docker-compose.hermes-runtime.example.yml` was changed to use Docker named volume `local-llm-hermes-data` for `/opt/data` and read-only seed files from `.hermes-runtime-example/`. `./scripts/run_hermes_runtime_example.sh smoke` returned `hermes gateway local llm ready`; usage was `prompt_tokens=11822`, `completion_tokens=36`, `total_tokens=11858`. |
| 2026-06-05 19:20-19:23 KST | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | `9501 (65ef50a0a)` | `qwen3.5-2b-q4-xl` / `qwen3.5-2b-ud-q4-k-xl` | OK | `docker-compose.hermes-local-llm.yml` with `.env.hermes-local-llm-hostuid` ran as `user: 1000:1000` with host bind `/opt/data` and direct Hermes entrypoint. `HERMES_CONTAINER=local-llm-hermes-local-hostuid ./scripts/smoke_hermes_runtime.sh` returned `hermes gateway local llm ready`; usage was `prompt_tokens=14402`, `completion_tokens=41`, `total_tokens=14443`. |
| 2026-06-05 19:34-19:35 KST | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | `9501 (65ef50a0a)` | `qwen3.5-2b-q4-xl` / `qwen3.5-2b-ud-q4-k-xl` | OK | `./scripts/run_hermes_runtime_example.sh up-hostuid`, `smoke-hostuid`, `status-hostuid`, and `down-hostuid` were verified against the host bind uid/gid 1000 runtime. `smoke-hostuid` returned `hermes gateway local llm ready`; usage was `prompt_tokens=14402`, `completion_tokens=29`, `total_tokens=14431`. |
| 2026-06-05 19:46-19:48 KST | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | `9501 (65ef50a0a)` | `qwen3.5-2b-q4-xl` / `qwen3.5-2b-ud-q4-k-xl` | OK | Hostuid runtime was reverified with `HERMES_OVERWRITE_CONFIG=0`. Startup kept existing `/opt/data/config.yaml` and `/opt/data/SOUL.md` instead of reseeding. `smoke-hostuid` returned `hermes gateway local llm ready`; usage was `prompt_tokens=14402`, `completion_tokens=39`, `total_tokens=14441`. |

## Failed/Interrupted Runs

| Measured at | Hermes image | Profile | Result | Notes |
| --- | --- | --- | --- | --- |
| 2026-06-05 14:50 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Interrupted | Smoke container set `HERMES_UID/HERMES_GID=10000`, causing startup to sit in recursive `/opt/hermes/.venv` ownership changes for more than 6 minutes. Removed UID/GID overrides from the smoke compose file. Gateway sanitizer request completed before interruption. |
| 2026-06-05 15:01 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Interrupted | Even without UID/GID overrides, the official wrapper stayed in recursive `/opt/hermes/.venv` ownership changes. Switched smoke compose to invoke `hermes` directly as the entrypoint for one-shot verification only. Gateway sanitizer request completed before interruption. |
| 2026-06-05 15:05 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Failed before Hermes start | Direct `entrypoint: ["hermes"]` failed because the image wrapper had not added `/opt/hermes/.venv/bin` to `PATH`. Updated smoke compose to use `/opt/hermes/.venv/bin/hermes`. Gateway sanitizer request completed before failure. |
| 2026-06-05 15:46 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Config edit recovered | A `perl -pi` edit against the Windows/WSL bind mount failed during rename and removed `.hermes/config.yaml`. Restored it from `/mnt/f/NowWorking/hermes-agent/.hermes/config.yaml.bak.20260605_154619_local_llm` with only the `model` block changed. Avoid in-place rename edits on that mount. |
| 2026-06-05 16:24 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Example runtime permission failure | Binding `.hermes-runtime-example/` directly to `/opt/data` failed after startup with `mkdir: cannot create directory '/opt/data/skins': Permission denied` and similar errors. Cause: WSL/DrvFS host files were owned by uid 1000 while the container wrote as uid 10000. Fixed by using a Docker named volume for `/opt/data` and mounting `.hermes-runtime-example/` as a read-only seed. |
| 2026-06-05 17:39-17:47 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Bind data verification failed | `./scripts/verify_hermes_bind_data.sh run` mounted `./.hermes-runtime-bind-test` from `/mnt/f` as `/opt/data`. The API server did not become ready within 120s, then reproduced with a 60s timeout after compose override cleanup. Logs stopped at `Fixing ownership of /opt/data to hermes (10000)`; process table showed `chown -R hermes:hermes /opt/hermes/.venv` stuck. Storage-specific results are tracked in `docs/verification/hermes-storage-compatibility.md`. |
| 2026-06-05 18:10-18:13 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Host-uid bind data verification failed | `./scripts/verify_hermes_bind_data.sh run-host-uid` reproduced the `F:\NowWorking\hermes-agent` storage pattern with host bind `/opt/data` and `HERMES_UID/HERMES_GID=1000`. Primitive file/SQLite checks passed separately, but the full gateway API did not become ready within 180s. Logs stopped at `Fixing ownership of /opt/data to hermes (1000)` and process table showed `chown -R hermes:hermes /opt/hermes/.venv` stuck. |

## Open Caveats

- This smoke test proves basic custom endpoint reachability and request
  compatibility, not full Hermes tool execution.
- Tool payloads are preserved by the gateway. If a llama.cpp version ignores
  tool schemas, record that as a model/runtime limitation rather than masking
  it in the gateway.
- For the full Hermes runtime, prefer `scripts/smoke_hermes_runtime.sh` because
  it talks to the Hermes API server from inside the container and avoids the
  observed host port mapping instability on this WSL/Docker setup.
