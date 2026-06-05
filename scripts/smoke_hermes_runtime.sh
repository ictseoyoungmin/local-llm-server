#!/usr/bin/env bash
set -euo pipefail

HERMES_CONTAINER="${HERMES_CONTAINER:-hermes}"
MODEL="${HERMES_AGENT_MODEL:-qwen3.5-2b-ud-q4-k-xl}"
PROMPT="${HERMES_AGENT_PROMPT:-Reply exactly: hermes gateway local llm ready}"
LOCAL_GATEWAY_BASE_URL="${LOCAL_LLM_GATEWAY_BASE_URL:-http://127.0.0.1:18080/v1}"
HERMES_API_READY_TIMEOUT_SECONDS="${HERMES_API_READY_TIMEOUT_SECONDS:-600}"
HERMES_API_READY_INTERVAL_SECONDS="${HERMES_API_READY_INTERVAL_SECONDS:-5}"

wait_for_hermes_api() {
  local deadline now
  deadline=$((SECONDS + HERMES_API_READY_TIMEOUT_SECONDS))

  while true; do
    if docker exec -i "${HERMES_CONTAINER}" /opt/hermes/.venv/bin/python3 - <<'PY' >/dev/null 2>&1
import urllib.request

with urllib.request.urlopen("http://127.0.0.1:8642/v1/health", timeout=5) as response:
    raise SystemExit(0 if response.status == 200 else 1)
PY
    then
      return 0
    fi

    now="${SECONDS}"
    if (( now >= deadline )); then
      echo "Hermes API server did not become ready within ${HERMES_API_READY_TIMEOUT_SECONDS}s." >&2
      echo "Recent container logs:" >&2
      docker logs --tail 80 "${HERMES_CONTAINER}" >&2 || true
      return 9
    fi

    sleep "${HERMES_API_READY_INTERVAL_SECONDS}"
  done
}

echo "Checking Local LLM gateway: ${LOCAL_GATEWAY_BASE_URL}/health"
curl -fsS --max-time 10 "${LOCAL_GATEWAY_BASE_URL}/health" >/dev/null

echo "Checking Hermes container: ${HERMES_CONTAINER}"
docker exec "${HERMES_CONTAINER}" /opt/hermes/.venv/bin/hermes status >/dev/null

echo "Waiting for Hermes API server inside the container"
wait_for_hermes_api

echo "Sending request through Hermes API server inside the container"
docker exec -i \
  -e HERMES_RUNTIME_SMOKE_MODEL="${MODEL}" \
  -e HERMES_RUNTIME_SMOKE_PROMPT="${PROMPT}" \
  -e API_SERVER_KEY="${API_SERVER_KEY:-}" \
  "${HERMES_CONTAINER}" \
  /opt/hermes/.venv/bin/python3 - <<'PY'
import json
import os
import time
import urllib.error
import urllib.request


def _container_env() -> dict[str, str]:
    try:
        raw = open("/proc/1/environ", "rb").read().decode("utf-8", errors="ignore")
    except PermissionError:
        return {}
    pairs = (item.split("=", 1) for item in raw.split("\0") if "=" in item)
    return {key: value for key, value in pairs}


key = os.environ.get("API_SERVER_KEY") or _container_env().get("API_SERVER_KEY", "")
if not key:
    raise SystemExit("API_SERVER_KEY is not available in the Hermes container environment")

body = json.dumps(
    {
        "model": os.environ["HERMES_RUNTIME_SMOKE_MODEL"],
        "messages": [{"role": "user", "content": os.environ["HERMES_RUNTIME_SMOKE_PROMPT"]}],
        "temperature": 0,
        "max_tokens": 32,
    }
).encode("utf-8")

req = urllib.request.Request(
    "http://127.0.0.1:8642/v1/chat/completions",
    data=body,
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
    method="POST",
)

deadline = time.monotonic() + 120
while True:
    try:
        with urllib.request.urlopen(req, timeout=300) as response:
            payload = json.loads(response.read().decode("utf-8"))
        break
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Hermes API request failed with HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        if time.monotonic() >= deadline:
            raise SystemExit(f"Hermes API request did not connect within 120s: {exc}") from exc
        time.sleep(5)

print(json.dumps(payload, ensure_ascii=False))
PY
