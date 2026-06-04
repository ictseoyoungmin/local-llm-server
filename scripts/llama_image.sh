#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LOCK_FILE="${LLAMA_IMAGE_LOCK_FILE:-llama-image.lock}"
IMAGE_TAG="${LLAMA_GPU_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-cuda}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/llama_image.sh status
  ./scripts/llama_image.sh record-known-good
  ./scripts/llama_image.sh update
  ./scripts/llama_image.sh rollback

Commands:
  status             Print local tag and lock-file digest information.
  record-known-good  Record the current local image digest into llama-image.lock.
  update             Pull the configured llama.cpp image tag.
  rollback           Tag the locked digest back to the configured image tag.
EOF
}

image_digest() {
  docker image inspect "${IMAGE_TAG}" --format '{{range .RepoDigests}}{{println .}}{{end}}' \
    | awk 'NR == 1 {print; exit}'
}

load_lock() {
  if [[ ! -f "${LOCK_FILE}" ]]; then
    echo "Missing lock file: ${LOCK_FILE}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "${LOCK_FILE}"
}

status() {
  local digest
  digest="$(image_digest || true)"
  echo "image_tag=${IMAGE_TAG}"
  echo "local_digest=${digest:-missing}"
  if [[ -f "${LOCK_FILE}" ]]; then
    load_lock
    echo "locked_tag=${LLAMA_GPU_IMAGE_TAG:-}"
    echo "locked_digest=${LLAMA_GPU_IMAGE_DIGEST:-}"
  else
    echo "locked_digest=missing"
  fi
}

record_known_good() {
  local digest
  digest="$(image_digest)"
  if [[ -z "${digest}" ]]; then
    echo "No local digest found for ${IMAGE_TAG}" >&2
    exit 1
  fi
  cat > "${LOCK_FILE}" <<EOF
LLAMA_GPU_IMAGE_TAG=${IMAGE_TAG}
LLAMA_GPU_IMAGE_DIGEST=${digest}
EOF
  echo "Recorded ${digest} in ${LOCK_FILE}"
}

update_image() {
  docker pull "${IMAGE_TAG}"
  status
}

rollback_image() {
  load_lock
  if [[ -z "${LLAMA_GPU_IMAGE_DIGEST:-}" ]]; then
    echo "LLAMA_GPU_IMAGE_DIGEST is missing in ${LOCK_FILE}" >&2
    exit 1
  fi
  docker pull "${LLAMA_GPU_IMAGE_DIGEST}"
  docker tag "${LLAMA_GPU_IMAGE_DIGEST}" "${IMAGE_TAG}"
  echo "Rolled back ${IMAGE_TAG} to ${LLAMA_GPU_IMAGE_DIGEST}"
}

command="${1:-}"
case "${command}" in
  status)
    status
    ;;
  record-known-good)
    record_known_good
    ;;
  update)
    update_image
    ;;
  rollback)
    rollback_image
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "Unknown command: ${command}" >&2
    usage >&2
    exit 2
    ;;
esac
