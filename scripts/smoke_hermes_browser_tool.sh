#!/usr/bin/env bash
set -euo pipefail

HERMES_CONTAINER="${HERMES_CONTAINER:-local-llm-hermes-local-hostuid}"
SMOKE_URL="${HERMES_BROWSER_SMOKE_URL:-https://example.com}"
TASK_ID="${HERMES_BROWSER_SMOKE_TASK_ID:-local-llm-browser-smoke}"

if [[ "$(docker inspect -f '{{.State.Running}}' "${HERMES_CONTAINER}" 2>/dev/null || true)" != "true" ]]; then
  cat >&2 <<EOF
Hermes container '${HERMES_CONTAINER}' is not running.

Start it with:
  ./scripts/run_hermes_runtime_example.sh up-hostuid
EOF
  exit 8
fi

docker exec -i \
  -e HERMES_BROWSER_SMOKE_URL="${SMOKE_URL}" \
  -e HERMES_BROWSER_SMOKE_TASK_ID="${TASK_ID}" \
  "${HERMES_CONTAINER}" \
  /opt/hermes/.venv/bin/python - <<'PY'
import json
import os
import sys

sys.path.insert(0, "/opt/hermes")
from tools.browser_tool import browser_navigate  # noqa: E402

url = os.environ["HERMES_BROWSER_SMOKE_URL"]
task_id = os.environ["HERMES_BROWSER_SMOKE_TASK_ID"]
result = json.loads(browser_navigate(url, task_id=task_id))

summary = {
    "success": result.get("success"),
    "error": result.get("error"),
    "url": url,
    "task_id": task_id,
}
print(json.dumps(summary, ensure_ascii=False))

if not result.get("success"):
    raise SystemExit(1)
PY
