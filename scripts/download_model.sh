#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source scripts/env.sh
load_env

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

if ! command -v huggingface-cli >/dev/null 2>&1; then
  cat >&2 <<'EOF'
huggingface-cli was not found.

Install it in a local environment:
  python3 -m venv .venv_hug
  source .venv_hug/bin/activate
  python -m pip install "huggingface_hub[cli]"

Then rerun:
  ./scripts/download_model.sh
EOF
  exit 127
fi

echo "Downloading ${HF_MODEL_REPO}/${HF_MODEL_FILE} -> ${MODEL_DIR}"
huggingface-cli download "${HF_MODEL_REPO}" "${HF_MODEL_FILE}" \
  --local-dir "${MODEL_DIR}" \
  --local-dir-use-symlinks False

if [[ -n "${HF_MMPROJ_FILE:-}" ]]; then
  echo "Downloading ${HF_MODEL_REPO}/${HF_MMPROJ_FILE} -> ${MODEL_DIR}"
  huggingface-cli download "${HF_MODEL_REPO}" "${HF_MMPROJ_FILE}" \
    --local-dir "${MODEL_DIR}" \
    --local-dir-use-symlinks False
fi

./scripts/validate_models.sh
