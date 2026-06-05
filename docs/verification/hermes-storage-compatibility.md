# Hermes Runtime Storage Compatibility

This file records whether Hermes-agent's mutable `/opt/data` directory works
with different host storage backends. It is meant for GitHub users to append
their own results without reading every dev log.

## How To Verify

Named volume baseline:

```bash
./scripts/run_hermes_runtime_example.sh up
./scripts/run_hermes_runtime_example.sh smoke
```

Host bind mount test:

```bash
./scripts/verify_hermes_bind_data.sh run
```

Host bind mount with host uid/gid, matching the observed
`F:\NowWorking\hermes-agent` pattern:

```bash
./scripts/verify_hermes_bind_data.sh run-host-uid
```

Host bind mount with host uid/gid and direct Hermes entrypoint, using
`docker-compose.hermes-local-llm.yml`:

```bash
./scripts/run_hermes_runtime_example.sh init-hostuid
./scripts/run_hermes_runtime_example.sh up-hostuid
./scripts/run_hermes_runtime_example.sh smoke-hostuid
./scripts/run_hermes_runtime_example.sh down-hostuid
```

Host storage primitive probe:

```bash
./scripts/verify_host_storage_primitives.sh

HERMES_STORAGE_PROBE_UID=1000 \
HERMES_STORAGE_PROBE_GID=1000 \
HERMES_STORAGE_PROBE_DIR=.hermes-storage-probe-uid1000 \
  ./scripts/verify_host_storage_primitives.sh
```

Clean up the bind-mount test container:

```bash
./scripts/verify_hermes_bind_data.sh down
./scripts/verify_hermes_bind_data.sh down-host-uid
```

The bind test stores mutable Hermes state in:

```text
./.hermes-runtime-bind-test
```

That directory is intentionally gitignored.

## Result Matrix

| Measured at | Host OS / runtime | Storage path | Filesystem / mount | Docker storage mode | Hermes image | Result | Evidence / notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-06-05 16:43 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | Docker volume `local-llm-hermes-data` | Docker managed Linux volume | named volume -> `/opt/data` | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | OK | `./scripts/run_hermes_runtime_example.sh smoke` returned `hermes gateway local llm ready`; usage `prompt_tokens=11822`, `completion_tokens=36`, `total_tokens=11858`. |
| 2026-06-05 16:24 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-runtime-example` on `/mnt/f` | DrvFS / Windows drive bind mount | host bind -> `/opt/data` | `nousresearch/hermes-agent:latest` | Failed | Startup failed with `mkdir: cannot create directory '/opt/data/skins': Permission denied`, also `plans`, `workspace`, and `home`. Host files were uid 1000 while the container wrote as uid 10000. |
| 2026-06-05 17:39-17:47 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-runtime-bind-test` on `/mnt/f` | DrvFS / Windows drive bind mount | host bind -> `/opt/data` | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | Failed | `./scripts/verify_hermes_bind_data.sh run` started `local-llm-hermes-bind-test`, but `./scripts/smoke_hermes_runtime.sh` timed out after 120s and again after 60s on rerun. Container stayed running with log `Fixing ownership of /opt/data to hermes (10000)`. Process table showed root process stuck in `chown -R hermes:hermes /opt/hermes/.venv`. |
| 2026-06-05 18:10-18:13 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-runtime-bind-host-uid` on `/mnt/f` | DrvFS / Windows drive bind mount | host bind -> `/opt/data`; `HERMES_UID=1000`, `HERMES_GID=1000` | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | Failed at gateway wrapper | This matches the storage pattern used by `F:\NowWorking\hermes-agent`: host `.hermes` bind mount plus uid/gid 1000. The container created `/opt/data` directories and files as host user `ymin`, but the API server did not become ready within 180s. Logs stopped at `Changing hermes UID to 1000`, `Changing hermes GID to 1000`, `Fixing ownership of /opt/data to hermes (1000)`. Process table showed root process stuck in `chown -R hermes:hermes /opt/hermes/.venv`. |
| 2026-06-05 19:20-19:23 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-local-llm-hostuid` on `/mnt/f` | DrvFS / Windows drive bind mount | host bind -> `/opt/data`; compose `user: 1000:1000`; direct `/opt/hermes/.venv/bin/hermes gateway run` entrypoint | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | OK | `docker-compose.hermes-local-llm.yml` with `.env.hermes-local-llm-hostuid` avoided the official wrapper ownership path. `HERMES_CONTAINER=local-llm-hermes-local-hostuid ./scripts/smoke_hermes_runtime.sh` returned `hermes gateway local llm ready`; usage `prompt_tokens=14402`, `completion_tokens=41`, `total_tokens=14443`. Data files including `state.db`, `state.db-wal`, `response_store.db`, `response_store.db-wal`, `kanban.db`, and `sessions/session_api-...json` were created as host user `ymin`. |
| 2026-06-05 19:34-19:35 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-local-llm-hostuid` on `/mnt/f` | DrvFS / Windows drive bind mount | same hostuid direct-entrypoint mode managed by `scripts/run_hermes_runtime_example.sh` | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | OK | New wrapper commands `up-hostuid`, `smoke-hostuid`, `status-hostuid`, and `down-hostuid` were verified. `smoke-hostuid` returned `hermes gateway local llm ready`; usage `prompt_tokens=14402`, `completion_tokens=29`, `total_tokens=14431`. |
| 2026-06-05 19:46-19:48 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-local-llm-hostuid` on `/mnt/f` | DrvFS / Windows drive bind mount | hostuid direct-entrypoint mode with `HERMES_OVERWRITE_CONFIG=0` | `nousresearch/hermes-agent:latest` `sha256:b6e41c155d6bfce5ad83c5d0fec670086db8a43250e4511c9474134be5482d33` | OK | Startup logs showed `Keeping existing /opt/data/config.yaml; set HERMES_OVERWRITE_CONFIG=1 to reseed` and the same for `SOUL.md`. `./scripts/run_hermes_runtime_example.sh smoke-hostuid` returned `hermes gateway local llm ready`; usage `prompt_tokens=14402`, `completion_tokens=39`, `total_tokens=14441`. |

## Primitive Probe Results

These tests run inside the Hermes image as uid/gid `10000:10000` against a
host bind-mounted directory. They isolate file, lock, SQLite, fsync, and rename
behavior from the full Hermes gateway wrapper.

| Measured at | Host OS / runtime | Storage path | Filesystem / mount | Directory mode | Result | Evidence / notes |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-06-05 17:44 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-storage-probe/default-755` on `/mnt/f` | DrvFS / Windows drive bind mount | host stat `uid=1000 gid=1000 mode=755 fs=0` | Failed | `./scripts/verify_host_storage_primitives.sh` failed at first file create with `PermissionError: [Errno 13] Permission denied: '/data/write.txt'`. SQLite was not reached. |
| 2026-06-05 17:44 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-storage-probe/open-777` on `/mnt/f` | DrvFS / Windows drive bind mount | requested `chmod 777`, host stat still `uid=1000 gid=1000 mode=755 fs=0` | Failed | Same `PermissionError` at `/data/write.txt`. On this mount, `chmod 777` did not persist as a usable mitigation for uid `10000`. |
| 2026-06-05 18:06 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-storage-probe-uid1000/default-755` on `/mnt/f` | DrvFS / Windows drive bind mount | host stat `uid=1000 gid=1000 mode=755 fs=0` | OK | `HERMES_STORAGE_PROBE_UID=1000 HERMES_STORAGE_PROBE_GID=1000` succeeded as `container uid=1000 gid=1000`; file create, `flock`, `fsync`, SQLite WAL, and atomic rename all passed with `ok journal_mode=wal`. |
| 2026-06-05 18:06 KST | Windows 11 + WSL2 Ubuntu 22.04 + Docker Desktop | `./.hermes-storage-probe-uid1000/open-777` on `/mnt/f` | DrvFS / Windows drive bind mount | requested `chmod 777`, host stat still `uid=1000 gid=1000 mode=755 fs=0` | OK | Same uid/gid 1000 primitive probe passed. On this mount, matching container uid/gid to the host owner matters more than `chmod 777`. |

## Result Fields

Use these values consistently:

- `OK`: container starts, Hermes API becomes ready, and smoke request completes.
- `Failed`: deterministic failure with a recorded command and error.
- `Partial`: container starts but a required smoke, DB, lock, or persistence check
  is missing.
- `Interrupted`: the run was stopped before a conclusion.

Always record:

- exact timestamp and timezone;
- host OS and Docker runtime;
- storage path;
- filesystem or mount type;
- Hermes image tag and digest when available;
- command used for verification;
- first failing error line when the result is not OK.

For primitive probe submissions, include both case outputs:

```text
RESULT default-755 ...
RESULT open-777 ...
```

## Current Recommendation

For WSL2 + Docker Desktop on Windows drives, keep Hermes mutable state in a
Docker named volume and use a repo directory only as a read-only seed/config
source. Directly bind-mounting a DrvFS directory as `/opt/data` is not currently
portable enough for the official Hermes container's uid/gid behavior.

The host-uid bind strategy used by `F:\NowWorking\hermes-agent` is viable for
basic file and SQLite operations on this host when the container process runs
as uid/gid `1000:1000`. The full gateway also passed when using
`docker-compose.hermes-local-llm.yml`, which bypasses the official wrapper and
executes Hermes directly as uid/gid `1000:1000`. The wrapper-based host-uid test
still fails on this host because it stalls while changing ownership of the
image's internal virtual environment.
