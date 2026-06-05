# Hermes-agent Examples

These files are non-secret snippets for connecting a full Hermes-agent runtime
to this project's gateway.

Two integration modes exist:

- `docker-compose.hermes-agent.yml`: short one-shot CLI smoke container.
- `docker-compose.hermes-runtime.example.yml`: full Hermes gateway runtime
  example with API server and dashboard.

They are not a replacement for an existing Hermes runtime repository such as:

```text
/mnt/f/NowWorking/hermes-agent
```

Use them as references only. Back up the live Hermes config before applying any
snippet.

## Full Runtime Example

Initialize local runtime files:

```bash
./scripts/run_hermes_runtime_example.sh init
```

This creates gitignored files:

```text
.env.hermes-runtime
.hermes-runtime-example/config.yaml
.hermes-runtime-example/SOUL.md
```

The compose project name defaults to `local-llm-hermes-runtime`, so it stays
separate from this repository's main `llama` and `gateway` compose stack.

Start the full Hermes gateway runtime:

```bash
./scripts/run_hermes_runtime_example.sh up
```

If another Hermes runtime already uses ports `8642` or `9119`, edit
`.env.hermes-runtime` before starting:

```env
HERMES_CONTAINER_NAME=local-llm-hermes
HERMES_API_PORT=18642
HERMES_DASHBOARD_PORT=19119
```

The example defaults `HERMES_UID/HERMES_GID` to `10000`, matching the official
image's built-in `hermes` user. Setting these to a different user can make the
entrypoint spend a long time recursively changing ownership of
`/opt/hermes/.venv` before the API server starts.

If `up` already failed with `port is already allocated`, clean the failed
container before retrying:

```bash
./scripts/run_hermes_runtime_example.sh down
```

Smoke test through the Hermes API server:

```bash
./scripts/run_hermes_runtime_example.sh smoke
```

Stop it:

```bash
./scripts/run_hermes_runtime_example.sh down
```
