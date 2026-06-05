#!/usr/bin/env bash
set -euo pipefail

IMAGE="${HERMES_AGENT_IMAGE:-nousresearch/hermes-agent:latest}"
ROOT="${HERMES_STORAGE_PROBE_DIR:-.hermes-storage-probe}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/verify_host_storage_primitives.sh

Runs a small file/SQLite probe from inside the Hermes-agent image as uid/gid
10000:10000 against host bind-mounted directories.

Cases:
  default-755: host-created directory with mode 755
  open-777:    host-created directory with mode 777
EOF
}

run_case() {
  local name="$1"
  local mode="$2"
  local path="${ROOT}/${name}"

  mkdir -p "${path}"
  chmod "${mode}" "${path}"

  echo "== ${name} =="
  stat -c 'host path=%n uid=%u gid=%g mode=%a fs=%T' "${path}" || true

  docker run --rm -i \
    --entrypoint /opt/hermes/.venv/bin/python \
    --user 10000:10000 \
    -v "$(pwd)/${path}:/data" \
    "${IMAGE}" \
    - <<'PY'
import fcntl
import os
import sqlite3
import tempfile

print(f"container uid={os.getuid()} gid={os.getgid()}")

with open("/data/write.txt", "w", encoding="utf-8") as handle:
    handle.write("write-ok\n")

lock_path = "/data/probe.lock"
with open(lock_path, "w", encoding="utf-8") as handle:
    fcntl.flock(handle, fcntl.LOCK_EX)
    handle.write("lock-ok\n")
    handle.flush()
    os.fsync(handle.fileno())
    fcntl.flock(handle, fcntl.LOCK_UN)

db = sqlite3.connect("/data/probe.sqlite", timeout=5)
try:
    journal_mode = db.execute("PRAGMA journal_mode=WAL").fetchone()[0]
    db.execute("CREATE TABLE IF NOT EXISTS probe (id INTEGER PRIMARY KEY, value TEXT NOT NULL)")
    db.execute("INSERT INTO probe(value) VALUES (?)", ("sqlite-ok",))
    db.commit()
finally:
    db.close()

fd, tmp_path = tempfile.mkstemp(prefix="rename-", dir="/data")
with os.fdopen(fd, "w", encoding="utf-8") as handle:
    handle.write("rename-ok\n")
os.replace(tmp_path, "/data/renamed.txt")

print(f"ok journal_mode={journal_mode}")
PY
}

case "${1:-run}" in
  run)
    failed=0
    if run_case default-755 755; then
      echo "RESULT default-755 OK"
    else
      echo "RESULT default-755 FAILED"
      failed=1
    fi
    if run_case open-777 777; then
      echo "RESULT open-777 OK"
    else
      echo "RESULT open-777 FAILED"
      failed=1
    fi
    exit "${failed}"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
