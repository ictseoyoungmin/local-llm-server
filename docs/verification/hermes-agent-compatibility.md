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

## Failed/Interrupted Runs

| Measured at | Hermes image | Profile | Result | Notes |
| --- | --- | --- | --- | --- |
| 2026-06-05 14:50 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Interrupted | Smoke container set `HERMES_UID/HERMES_GID=10000`, causing startup to sit in recursive `/opt/hermes/.venv` ownership changes for more than 6 minutes. Removed UID/GID overrides from the smoke compose file. Gateway sanitizer request completed before interruption. |
| 2026-06-05 15:01 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Interrupted | Even without UID/GID overrides, the official wrapper stayed in recursive `/opt/hermes/.venv` ownership changes. Switched smoke compose to invoke `hermes` directly as the entrypoint for one-shot verification only. Gateway sanitizer request completed before interruption. |
| 2026-06-05 15:05 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Failed before Hermes start | Direct `entrypoint: ["hermes"]` failed because the image wrapper had not added `/opt/hermes/.venv/bin` to `PATH`. Updated smoke compose to use `/opt/hermes/.venv/bin/hermes`. Gateway sanitizer request completed before failure. |
| 2026-06-05 15:46 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Config edit recovered | A `perl -pi` edit against the Windows/WSL bind mount failed during rename and removed `.hermes/config.yaml`. Restored it from `/mnt/f/NowWorking/hermes-agent/.hermes/config.yaml.bak.20260605_154619_local_llm` with only the `model` block changed. Avoid in-place rename edits on that mount. |

## Open Caveats

- This smoke test proves basic custom endpoint reachability and request
  compatibility, not full Hermes tool execution.
- Tool payloads are preserved by the gateway. If a llama.cpp version ignores
  tool schemas, record that as a model/runtime limitation rather than masking
  it in the gateway.
- For the full Hermes runtime, prefer `scripts/smoke_hermes_runtime.sh` because
  it talks to the Hermes API server from inside the container and avoids the
  observed host port mapping instability on this WSL/Docker setup.
