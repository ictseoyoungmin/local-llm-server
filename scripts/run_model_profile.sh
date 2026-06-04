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
  ./scripts/run_model_profile.sh list
  ./scripts/run_model_profile.sh status

Profiles live in model-profiles/*.env. The script keeps the public endpoint
stable at http://127.0.0.1:18080/v1 and recreates the Docker services with the
selected model settings.

Examples:
  ./scripts/run_model_profile.sh list
  ./scripts/run_model_profile.sh status
  ./scripts/run_model_profile.sh qwen3.5-2b-mtp-q4-xl 130000
  ./scripts/run_model_profile.sh gemma4-e2b-q4
EOF
}

profile_value() {
  local profile_path="$1"
  local key="$2"

  awk -F= -v key="${key}" '
    $1 == key {
      value = substr($0, length($1) + 2)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "${profile_path}"
}

list_profiles() {
  local path name model ctx spec

  printf '%-28s %-34s %-10s %s\n' "PROFILE" "MODEL" "CTX" "MODE"
  for path in model-profiles/*.env; do
    [[ -f "${path}" ]] || continue
    name="$(basename "${path}" .env)"
    model="$(profile_value "${path}" "PUBLIC_MODEL_NAME")"
    ctx="$(profile_value "${path}" "LLAMA_CTX_SIZE")"
    spec="$(profile_value "${path}" "LLAMA_SPEC_TYPE")"
    if [[ -n "${spec}" ]]; then
      spec="mtp:${spec}"
    else
      spec="standard"
    fi
    printf '%-28s %-34s %-10s %s\n' "${name}" "${model:-unknown}" "${ctx:-default}" "${spec}"
  done
}

status() {
  local base_url="${OPENAI_BASE_URL:-http://127.0.0.1:18080/v1}"
  local attempt

  echo "Endpoint: ${base_url}"
  for attempt in 1 2 3; do
    if curl -fsS --max-time 10 "${base_url}/health"; then
      echo
      break
    fi
    if [[ "${attempt}" == "3" ]]; then
      echo "Health: unavailable"
    else
      sleep 1
    fi
  done

  if command -v nvidia-smi >/dev/null 2>&1; then
    echo
    if ! nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits; then
      echo "GPU: unavailable"
    fi
  fi
}

profile_name="${1:-}"
if [[ -z "${profile_name}" || "${profile_name}" == "-h" || "${profile_name}" == "--help" ]]; then
  usage
  exit 0
fi

case "${profile_name}" in
  list|profiles)
    list_profiles
    exit 0
    ;;
  status)
    status
    exit 0
    ;;
esac

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
