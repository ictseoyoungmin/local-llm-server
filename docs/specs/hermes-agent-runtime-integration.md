# Hermes-agent Runtime Integration

## Scope

These notes are imported from the local Hermes runtime repository at:

```text
/mnt/f/NowWorking/hermes-agent
```

Only non-sensitive operational patterns are copied here. Do not copy `.env`,
`auth.json`, API keys, session payloads, local databases, or user-specific
Hermes state into this project.

Hermes-agent remains a consumer of this service. This project does not become a
Hermes-only runtime.

## Full Hermes Runtime Shape

The full Hermes runtime uses:

```text
image: nousresearch/hermes-agent:latest
command: ["gateway", "run"]
data volume: ./.hermes -> /opt/data
API server: 127.0.0.1:8642
dashboard: 127.0.0.1:9119
```

This repository includes a non-secret example compose file:

```text
docker-compose.hermes-runtime.example.yml
```

Initialize the example runtime state with:

```bash
./scripts/run_hermes_runtime_example.sh init
```

That creates gitignored local files:

```text
.env.hermes-runtime
.hermes-runtime-example/config.yaml
.hermes-runtime-example/SOUL.md
```

The example runtime stores mutable Hermes state in the Docker named volume
`local-llm-hermes-data`. The `.hermes-runtime-example/` directory is only a
read-only seed mounted into the container and copied into `/opt/data` at
startup. This avoids WSL/DrvFS bind-mount write permission failures for the
container's `hermes` user.

The runtime also mounts Docker access for Hermes terminal tooling:

```text
/var/run/docker.sock -> /var/run/docker.sock
/usr/bin/docker -> /usr/bin/docker:ro
```

It adds:

```text
host.docker.internal:host-gateway
```

That host alias is required for Hermes inside Docker to reach this project's
gateway:

```text
http://host.docker.internal:18080/v1
```

## Environment Notes

The full Hermes runtime uses the official wrapper entrypoint. Keep that for
gateway mode.

Important non-secret environment patterns:

```text
HERMES_HOME=/opt/data
HERMES_UID=10000
HERMES_GID=10000
HOME=/tmp/hermes-browser
PATH=/opt/hermes/.venv/bin:/opt/hermes/node_modules/.bin:/opt/data/.local/bin:...
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
HERMES_DASHBOARD=1
HERMES_DASHBOARD_HOST=0.0.0.0
HERMES_DASHBOARD_PORT=9119
HERMES_DASHBOARD_TUI=1
```

`HOME=/tmp/hermes-browser` keeps browser daemon sockets and transient state off
the Windows/WSL bind-mounted Hermes data directory. Preserve it in gateway mode.

`HERMES_UID/HERMES_GID=10000` matches the official image's built-in `hermes`
user. Overriding those values can trigger a slow recursive ownership change of
the image's internal virtual environment before the API server starts.

For the repository-local example runtime, do not bind-mount the whole Hermes
home directory from WSL/DrvFS as `/opt/data`. Host-created directories are often
owned by uid 1000 while the container writes as uid 10000, which can produce
`Permission denied` for directories such as `skins/`, `plans/`, `workspace/`,
and `home/`.

The external `F:\NowWorking\hermes-agent` runtime uses a different host-bind
strategy: it mounts `.hermes` as `/opt/data` and sets `HERMES_UID=1000` and
`HERMES_GID=1000`, matching the WSL host owner. On this host, that uid/gid
alignment passes basic file and SQLite probes, but the current official Hermes
image still failed the full gateway smoke in this repository because the
wrapper stalled while changing ownership of `/opt/hermes/.venv`.

Environment-specific storage results are tracked in
`docs/verification/hermes-storage-compatibility.md`. Add new filesystem results
there instead of relying on assumptions from one host.

The one-shot smoke container in this repository bypasses the wrapper entrypoint
only to avoid repeated ownership changes during short CLI tests. Do not use that
shortcut for the long-running Hermes gateway.

## Local Model Config Snippet

In the Hermes runtime, configure the model provider like this:

```yaml
model:
  provider: custom
  default: qwen3.5-2b-ud-q4-k-xl
  base_url: http://host.docker.internal:18080/v1
  api_key: local-not-required
```

The `default` value should match the active `PUBLIC_MODEL_NAME` from this
project's model profile. Check it with:

```bash
curl -fsS http://127.0.0.1:18080/v1/health
```

Do not set context through Hermes request fields such as `num_ctx`. Context is
owned by this project's selected model profile:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
```

## Readiness Checks

Start this local LLM server first:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
curl -fsS http://127.0.0.1:18080/v1/health
```

Then start the full Hermes runtime from its own repository:

```bash
cd /mnt/f/NowWorking/hermes-agent
docker compose up -d
```

Or start the example runtime from this repository:

```bash
./scripts/run_hermes_runtime_example.sh up
```

If an existing Hermes runtime already binds `8642` or `9119`, edit the
generated `.env.hermes-runtime` before `up`:

```env
HERMES_API_PORT=18642
HERMES_DASHBOARD_PORT=19119
```

The wrapper checks these ports before `docker compose up` and exits with a
clear message if they are already allocated. If Docker already created a failed
example container, clean it with:

```bash
./scripts/run_hermes_runtime_example.sh down
```

Check Hermes gateway readiness:

```bash
curl -fsS http://127.0.0.1:8642/v1/health
```

Expected shape:

```json
{"status": "ok", "platform": "hermes-agent"}
```

Useful diagnostics:

```bash
docker compose ps
docker compose logs -f hermes
tail -200 .hermes/logs/gateway.log
tail -200 .hermes/logs/errors.log
```

On this WSL/Docker host, `127.0.0.1:8642` from the host has been observed to be
intermittent after startup even while the API server is reachable from inside
the `hermes` container. Use the runtime smoke script for the end-to-end check:

```bash
./scripts/smoke_hermes_runtime.sh
```

For the example runtime managed by this repo, the wrapper command is:

```bash
./scripts/run_hermes_runtime_example.sh smoke
```

## Next Verification Slice

The next end-to-end slice should:

- back up `/mnt/f/NowWorking/hermes-agent/.hermes/config.yaml`;
- apply only the local model provider snippet above;
- start or recreate the Hermes gateway container;
- check `http://127.0.0.1:8642/v1/health`;
- send one Hermes API server request that routes through this project using
  `./scripts/smoke_hermes_runtime.sh`;
- record the result in `docs/verification/hermes-agent-compatibility.md`;
- restore the previous Hermes config if the local provider blocks normal use.
