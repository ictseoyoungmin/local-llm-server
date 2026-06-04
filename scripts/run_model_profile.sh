#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source scripts/env.sh
load_env

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_model_profile.sh <profile> [ctx-size]

Profiles live in model-profiles/*.env. The script keeps the public endpoint
stable at http://127.0.0.1:18080/v1 and recreates the Docker services with the
selected model settings.

Examples:
  ./scripts/run_model_profile.sh qwen3.5-2b-mtp-q4-xl 130000
  ./scripts/run_model_profile.sh gemma4-e2b-q4
EOF
}

profile_name="${1:-}"
if [[ -z "${profile_name}" || "${profile_name}" == "-h" || "${profile_name}" == "--help" ]]; then
  usage
  exit 0
fi

profile_path="model-profiles/${profile_name}.env"
if [[ ! -f "${profile_path}" ]]; then
  echo "Unknown model profile: ${profile_name}" >&2
  echo "Expected file: ${profile_path}" >&2
  exit 2
fi

set -a
# shellcheck disable=SC1090
source "${profile_path}"
set +a

if [[ -n "${2:-}" ]]; then
  export LLAMA_CTX_SIZE="$2"
fi

if [[ -n "${LLAMA_SPEC_TYPE:-}" ]]; then
  compose_override="docker-compose.gpu-mtp.example.yml"
else
  compose_override="docker-compose.gpu.example.yml"
fi

echo "Starting local LLM profile: ${profile_name}"
echo "  model: ${PUBLIC_MODEL_NAME:-local-llama}"
echo "  path:  ${LLAMA_MODEL_PATH:-/models/model.gguf}"
echo "  ctx:   ${LLAMA_CTX_SIZE:-8192}"
echo "  mode:  ${compose_override}"

docker compose -f docker-compose.yml -f "${compose_override}" up -d --force-recreate --no-build
