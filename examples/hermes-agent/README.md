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

Hermes runtime state is stored in the Docker named volume
`local-llm-hermes-data`. The `.hermes-runtime-example/` directory is only a
seed/config source copied into `/opt/data` at container startup. This avoids
WSL/DrvFS bind-mount write permission issues for the container's `hermes`
user.

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

Edit `.hermes-runtime-example/config.yaml` to change the local provider seed.
The file is copied into the named volume whenever the container starts.

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

## Host UID Runtime Example

For a host-bound `/opt/data` directory on WSL/DrvFS, use the hostuid commands.
This mode copies `hermes-local-llm.hostuid.env.example` to the gitignored
`.env.hermes-local-llm-hostuid`, runs the container as `1000:1000`, and uses
`docker-compose.hermes-local-llm.yml` to bypass the official wrapper ownership
step.

```bash
./scripts/run_hermes_runtime_example.sh init-hostuid
./scripts/run_hermes_runtime_example.sh up-hostuid
./scripts/run_hermes_runtime_example.sh smoke-hostuid
./scripts/run_hermes_runtime_example.sh down-hostuid
```

Runtime state is stored in:

```text
.hermes-local-llm-hostuid/
```

Existing `.hermes-local-llm-hostuid/config.yaml` and `SOUL.md` are kept by
default. To intentionally reseed them from `.hermes-runtime-example/`, set this
in `.env.hermes-local-llm-hostuid` before `up-hostuid`:

```env
HERMES_OVERWRITE_CONFIG=1
```

The runtime creates timestamped `.bak` files before overwriting.
