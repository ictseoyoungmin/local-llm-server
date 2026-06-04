#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source scripts/env.sh
load_env

usage() {
  cat <<'EOF'
Usage:
  ./scripts/download_model.sh [preset]

Presets:
  qwen3.5-2b-mtp-q4-xl    Qwen3.5 2B MTP UD-Q4_K_XL
  qwen3.5-2b-mtp-q8       Qwen3.5 2B MTP Q8_0
  qwen3.5-2b-mtp-q8-xl    Qwen3.5 2B MTP UD-Q8_K_XL

Without a preset, set HF_MODEL_REPO, HF_MODEL_FILE, and LLAMA_MODEL_PATH
through .env or environment variables.
EOF
}

apply_preset() {
  case "${1:-}" in
    "")
      return
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    qwen3.5-2b-mtp-q4-xl)
      export HF_MODEL_REPO="unsloth/Qwen3.5-2B-MTP-GGUF"
      export HF_MODEL_FILE="Qwen3.5-2B-UD-Q4_K_XL.gguf"
      export LLAMA_MODEL_PATH="/models/qwen35/Qwen3.5-2B-UD-Q4_K_XL.gguf"
      export PUBLIC_MODEL_NAME="qwen3.5-2b-mtp-ud-q4-k-xl"
      ;;
    qwen3.5-2b-mtp-q8)
      export HF_MODEL_REPO="unsloth/Qwen3.5-2B-MTP-GGUF"
      export HF_MODEL_FILE="Qwen3.5-2B-Q8_0.gguf"
      export LLAMA_MODEL_PATH="/models/qwen35/Qwen3.5-2B-Q8_0.gguf"
      export PUBLIC_MODEL_NAME="qwen3.5-2b-mtp-q8-0"
      ;;
    qwen3.5-2b-mtp-q8-xl)
      export HF_MODEL_REPO="unsloth/Qwen3.5-2B-MTP-GGUF"
      export HF_MODEL_FILE="Qwen3.5-2B-UD-Q8_K_XL.gguf"
      export LLAMA_MODEL_PATH="/models/qwen35/Qwen3.5-2B-UD-Q8_K_XL.gguf"
      export PUBLIC_MODEL_NAME="qwen3.5-2b-mtp-ud-q8-k-xl"
      ;;
    *)
      echo "Unknown preset: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
}

apply_preset "${1:-}"

MODEL_DIR="$(host_model_dir)"
mkdir -p "${MODEL_DIR}"

if [[ -z "${HF_MODEL_REPO:-}" || -z "${HF_MODEL_FILE:-}" ]]; then
  cat >&2 <<'EOF'
HF_MODEL_REPO and HF_MODEL_FILE are required.

Example .env:
  HF_MODEL_REPO=owner/repo-name
  HF_MODEL_FILE=model.gguf
  HOST_MODEL_DIR=./models
  LLAMA_MODEL_PATH=/models/model.gguf

For gated repos, run `huggingface-cli login` first or export HF_TOKEN.
EOF
  exit 2
fi

HF_CLI="${HF_CLI:-hf}"
HF_PYTHON="${HF_PYTHON:-}"
if ! command -v "${HF_CLI}" >/dev/null 2>&1 && [[ -x ".venv_hug/bin/hf" ]]; then
  HF_CLI=".venv_hug/bin/hf"
fi
if ! command -v "${HF_CLI}" >/dev/null 2>&1 && [[ -x ".venv_hug/bin/huggingface-cli" ]]; then
  HF_CLI=".venv_hug/bin/huggingface-cli"
fi
if ! command -v "${HF_CLI}" >/dev/null 2>&1 && [[ -z "${HF_PYTHON}" && -x ".venv_hug/bin/python" ]]; then
  HF_PYTHON=".venv_hug/bin/python"
fi

if ! command -v "${HF_CLI}" >/dev/null 2>&1 && [[ -z "${HF_PYTHON}" ]]; then
  cat >&2 <<'EOF'
huggingface-cli and a usable Python huggingface_hub install were not found.

Install it in a local environment:
  python3 -m venv .venv_hug
  source .venv_hug/bin/activate
  python -m pip install "huggingface_hub[cli]"

Then rerun:
  ./scripts/download_model.sh
EOF
  exit 127
fi

hf_download() {
  local repo="$1"
  local file="$2"

  if command -v "${HF_CLI}" >/dev/null 2>&1 && [[ "$(basename "${HF_CLI}")" == "hf" ]]; then
    "${HF_CLI}" download "${repo}" "${file}" --local-dir "${MODEL_DIR}"
  elif command -v "${HF_CLI}" >/dev/null 2>&1; then
    "${HF_CLI}" download "${repo}" "${file}" \
      --local-dir "${MODEL_DIR}" \
      --local-dir-use-symlinks False
  else
    "${HF_PYTHON}" -c '
import os
import sys
from huggingface_hub import hf_hub_download

hf_hub_download(
    repo_id=sys.argv[1],
    filename=sys.argv[2],
    local_dir=sys.argv[3],
)
' "${repo}" "${file}" "${MODEL_DIR}"
  fi
}

place_downloaded_file() {
  local source_relpath="$1"
  local target_relpath="$2"
  local source_file="${MODEL_DIR}/${source_relpath}"
  local target_file="${MODEL_DIR}/${target_relpath}"

  if [[ "${source_file}" == "${target_file}" ]]; then
    return
  fi
  if [[ ! -f "${source_file}" || -f "${target_file}" ]]; then
    return
  fi

  mkdir -p "$(dirname "${target_file}")"
  mv "${source_file}" "${target_file}"
}

echo "Downloading ${HF_MODEL_REPO}/${HF_MODEL_FILE} -> ${MODEL_DIR}"
hf_download "${HF_MODEL_REPO}" "${HF_MODEL_FILE}"
place_downloaded_file "${HF_MODEL_FILE}" "$(container_model_relpath)"

if [[ -n "${HF_MMPROJ_FILE:-}" ]]; then
  echo "Downloading ${HF_MODEL_REPO}/${HF_MMPROJ_FILE} -> ${MODEL_DIR}"
  hf_download "${HF_MODEL_REPO}" "${HF_MMPROJ_FILE}"
  place_downloaded_file "${HF_MMPROJ_FILE}" "$(container_mmproj_relpath)"
fi

./scripts/validate_models.sh
