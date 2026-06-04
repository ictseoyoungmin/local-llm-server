#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${OPENAI_BASE_URL:-http://host.docker.internal:18080/v1}"
MODEL="${OPENAI_MODEL:-local-llama}"
API_KEY="${OPENAI_API_KEY:-local-not-required}"

echo "Checking Hermes-agent local provider endpoint: ${BASE_URL}/health"
if ! curl -fsS --max-time 10 "${BASE_URL}/health" >/dev/null; then
  cat >&2 <<EOF
Hermes-agent cannot reach the local LLM gateway at:
  ${BASE_URL}

If Hermes-agent runs in Docker, use:
  OPENAI_BASE_URL=http://host.docker.internal:18080/v1

If running on the host, use:
  OPENAI_BASE_URL=http://127.0.0.1:18080/v1
EOF
  exit 7
fi

echo "Sending Hermes-agent provider smoke request with model=${MODEL}"
curl -fsS --max-time 180 "${BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [
      {\"role\": \"system\", \"content\": \"You are a local provider smoke test for Hermes-agent. Reply concisely.\"},
      {\"role\": \"user\", \"content\": \"Return exactly: hermes local provider ready\"}
    ],
    \"thinking\": false,
    \"chat_template_kwargs\": {\"enable_thinking\": false},
    \"temperature\": 0,
    \"max_tokens\": 32
  }"
