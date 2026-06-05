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

## Failed/Interrupted Runs

| Measured at | Hermes image | Profile | Result | Notes |
| --- | --- | --- | --- | --- |
| 2026-06-05 14:50 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Interrupted | Smoke container set `HERMES_UID/HERMES_GID=10000`, causing startup to sit in recursive `/opt/hermes/.venv` ownership changes for more than 6 minutes. Removed UID/GID overrides from the smoke compose file. Gateway sanitizer request completed before interruption. |
| 2026-06-05 15:01 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Interrupted | Even without UID/GID overrides, the official wrapper stayed in recursive `/opt/hermes/.venv` ownership changes. Switched smoke compose to invoke `hermes` directly as the entrypoint for one-shot verification only. Gateway sanitizer request completed before interruption. |
| 2026-06-05 15:05 KST | `nousresearch/hermes-agent:latest` | `qwen3.5-2b-q4-xl` | Failed before Hermes start | Direct `entrypoint: ["hermes"]` failed because the image wrapper had not added `/opt/hermes/.venv/bin` to `PATH`. Updated smoke compose to use `/opt/hermes/.venv/bin/hermes`. Gateway sanitizer request completed before failure. |

## Open Caveats

- This smoke test proves basic custom endpoint reachability and request
  compatibility, not full Hermes tool execution.
- Tool payloads are preserved by the gateway. If a llama.cpp version ignores
  tool schemas, record that as a model/runtime limitation rather than masking
  it in the gateway.
