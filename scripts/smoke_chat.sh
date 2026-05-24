#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${OPENAI_BASE_URL:-http://127.0.0.1:18080/v1}"
MODEL="${OPENAI_MODEL:-local-llama}"
API_KEY="${OPENAI_API_KEY:-local-not-required}"

echo "Checking ${BASE_URL}/health"
if ! curl -fsS --max-time 10 "${BASE_URL}/health" >/dev/null; then
  cat >&2 <<EOF
Local LLM gateway is not reachable at:
  ${BASE_URL}

Start it first:
  docker compose up --build

Then check:
  curl http://127.0.0.1:18080/v1/health
EOF
  exit 7
fi

echo "Sending chat request to ${BASE_URL}/chat/completions with model=${MODEL}"
curl -fsS --max-time 180 "${BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [
      {\"role\": \"system\", \"content\": \"You are a concise local test assistant.\"},
      {\"role\": \"user\", \"content\": \"Say local LLM is ready in one short sentence.\"}
    ],
    \"thinking\": false,
    \"chat_template_kwargs\": {\"enable_thinking\": false},
    \"temperature\": 0.2,
    \"max_tokens\": 128
  }"
