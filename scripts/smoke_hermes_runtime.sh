#!/usr/bin/env bash
set -euo pipefail

HERMES_CONTAINER="${HERMES_CONTAINER:-hermes}"
MODEL="${HERMES_AGENT_MODEL:-qwen3.5-2b-ud-q4-k-xl}"
PROMPT="${HERMES_AGENT_PROMPT:-Reply exactly: hermes gateway local llm ready}"
LOCAL_GATEWAY_BASE_URL="${LOCAL_LLM_GATEWAY_BASE_URL:-http://127.0.0.1:18080/v1}"

echo "Checking Local LLM gateway: ${LOCAL_GATEWAY_BASE_URL}/health"
curl -fsS --max-time 10 "${LOCAL_GATEWAY_BASE_URL}/health" >/dev/null

echo "Checking Hermes container: ${HERMES_CONTAINER}"
docker exec "${HERMES_CONTAINER}" /opt/hermes/.venv/bin/hermes status >/dev/null

echo "Sending request through Hermes API server inside the container"
docker exec -i \
  -e HERMES_RUNTIME_SMOKE_MODEL="${MODEL}" \
  -e HERMES_RUNTIME_SMOKE_PROMPT="${PROMPT}" \
  "${HERMES_CONTAINER}" \
  /opt/hermes/.venv/bin/python3 - <<'PY'
import json
import os
import urllib.error
import urllib.request


def _container_env() -> dict[str, str]:
    raw = open("/proc/1/environ", "rb").read().decode("utf-8", errors="ignore")
    pairs = (item.split("=", 1) for item in raw.split("\0") if "=" in item)
    return {key: value for key, value in pairs}


key = _container_env().get("API_SERVER_KEY", "")
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

try:
    with urllib.request.urlopen(req, timeout=300) as response:
        payload = json.loads(response.read().decode("utf-8"))
except urllib.error.HTTPError as exc:
    detail = exc.read().decode("utf-8", errors="replace")
    raise SystemExit(f"Hermes API request failed with HTTP {exc.code}: {detail}") from exc

print(json.dumps(payload, ensure_ascii=False))
PY
