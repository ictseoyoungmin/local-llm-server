#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${LOCAL_LLM_GATEWAY_BASE_URL:-http://127.0.0.1:18080/v1}"
MODEL="${HERMES_AGENT_MODEL:-gemma-4-E2B-it-Q4_K_M}"
API_KEY="${LOCAL_LLM_API_KEY:-local-not-required}"

echo "Checking host gateway endpoint: ${BASE_URL}/health"
if ! curl -fsS --max-time 10 "${BASE_URL}/health" >/dev/null; then
  cat >&2 <<EOF
Hermes-agent smoke test cannot reach the local LLM gateway at:
  ${BASE_URL}

Start or switch a model profile first, for example:
  ./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
  ./scripts/run_model_profile.sh gemma4-e2b-q4 130000
EOF
  exit 7
fi

echo "Checking gateway sanitizer for llama.cpp-incompatible Hermes/Ollama fields"
headers_file="$(mktemp)"
body_file="$(mktemp)"
trap 'rm -f "${headers_file}" "${body_file}"' EXIT

curl -fsS --max-time 180 "${BASE_URL}/chat/completions" \
  -D "${headers_file}" \
  -o "${body_file}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [
      {\"role\": \"system\", \"content\": \"You are a gateway compatibility smoke test. Reply concisely.\"},
      {\"role\": \"user\", \"content\": \"Return exactly: gateway sanitizer ready\"}
    ],
    \"extra_body\": {\"options\": {\"num_ctx\": 200192}},
    \"options\": {\"num_ctx\": 200192},
    \"num_ctx\": 200192,
    \"temperature\": 0,
    \"max_tokens\": 32
  }" >/dev/null

if ! grep -iq "x-local-llm-sanitized-fields: .*extra_body" "${headers_file}"; then
  echo "Expected X-Local-LLM-Sanitized-Fields response header was not found." >&2
  cat "${headers_file}" >&2
  cat "${body_file}" >&2
  exit 8
fi

echo "Running Hermes-agent official Docker image against custom endpoint"
HERMES_AGENT_MODEL="${MODEL}" docker compose -f docker-compose.hermes-agent.yml run --rm hermes-agent-smoke
