#!/usr/bin/env bash
set -euo pipefail

load_env() {
  if [[ -f ".env" ]]; then
    while IFS='=' read -r key value; do
      [[ -z "${key}" || "${key}" =~ ^[[:space:]]*# ]] && continue
      key="${key%%[[:space:]]*}"
      [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
      if [[ -z "${!key+x}" ]]; then
        value="${value%%#*}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value#\"}"
        value="${value%\"}"
        export "${key}=${value}"
      fi
    done < ".env"
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
