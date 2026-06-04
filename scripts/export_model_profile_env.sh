#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
  cat <<'EOF'
Usage:
  ./scripts/export_model_profile_env.sh <profile> [--output PATH]

Print a complete environment file for a model profile. By default this writes
to stdout. Use --output explicitly when you want to update a file such as .env.

Examples:
  ./scripts/export_model_profile_env.sh qwen3.5-2b-q4-xl
  ./scripts/export_model_profile_env.sh qwen3.5-2b-q4-xl --output .env
EOF
}

profile_name="${1:-}"
if [[ -z "${profile_name}" || "${profile_name}" == "-h" || "${profile_name}" == "--help" ]]; then
  usage
  exit 0
fi
shift

output_path=""
if [[ "${1:-}" == "--output" ]]; then
  output_path="${2:-}"
  if [[ -z "${output_path}" ]]; then
    echo "--output requires a path" >&2
    exit 2
  fi
  shift 2
fi

if [[ "$#" -ne 0 ]]; then
  echo "Unexpected arguments: $*" >&2
  usage >&2
  exit 2
fi

profile_path="model-profiles/${profile_name}.env"
if [[ ! -f "${profile_path}" ]]; then
  echo "Unknown model profile: ${profile_name}" >&2
  echo "Expected file: ${profile_path}" >&2
  exit 2
fi

render() {
  cat <<EOF
# Generated from ${profile_path}.
# Manual edits are allowed, but model-profiles/*.env are the switching source of truth.
HOST_MODEL_DIR=${HOST_MODEL_DIR:-./models}

EOF
  cat "${profile_path}"
  cat <<'EOF'

LLAMA_HOST=0.0.0.0
LLAMA_PORT=8080
LLAMA_THREADS=8
LLAMA_GPU_IMAGE=ghcr.io/ggml-org/llama.cpp:server-cuda

GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=8000
LLAMA_UPSTREAM_BASE_URL=http://llama:8080/v1
LOCAL_LLM_API_KEY=local-not-required
REQUEST_TIMEOUT_SECONDS=600
EOF
}

if [[ -n "${output_path}" ]]; then
  render > "${output_path}"
  echo "Wrote ${output_path} from ${profile_path}"
else
  render
fi
