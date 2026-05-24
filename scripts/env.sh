#!/usr/bin/env bash
set -euo pipefail

load_env() {
  if [[ -f ".env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
  fi
}

host_model_dir() {
  printf '%s\n' "${HOST_MODEL_DIR:-./models}"
}

container_model_basename() {
  basename "${LLAMA_MODEL_PATH:-/models/model.gguf}"
}

container_mmproj_basename() {
  basename "${LLAMA_MMPROJ_PATH:-/models/mmproj.gguf}"
}
