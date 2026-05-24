#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source scripts/env.sh
load_env

MODEL_DIR="$(host_model_dir)"
MODEL_FILE="${MODEL_DIR}/$(container_model_basename)"
MMPROJ_FILE="${MODEL_DIR}/$(container_mmproj_basename)"

if [[ ! -f "${MODEL_FILE}" ]]; then
  cat >&2 <<EOF
Missing model file:
  ${MODEL_FILE}

Check HOST_MODEL_DIR and LLAMA_MODEL_PATH in .env.
EOF
  exit 1
fi

echo "OK model: ${MODEL_FILE}"

if [[ -n "${HF_MMPROJ_FILE:-}" || -f "${MMPROJ_FILE}" ]]; then
  if [[ ! -f "${MMPROJ_FILE}" ]]; then
    cat >&2 <<EOF
Missing mmproj file:
  ${MMPROJ_FILE}

Check HF_MMPROJ_FILE and LLAMA_MMPROJ_PATH in .env.
EOF
    exit 1
  fi
  echo "OK mmproj: ${MMPROJ_FILE}"
fi
