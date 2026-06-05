#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${HERMES_RUNTIME_COMPOSE_FILE:-docker-compose.hermes-runtime.example.yml}"
ENV_FILE="${HERMES_RUNTIME_ENV_FILE:-.env.hermes-runtime}"
DATA_DIR="${HERMES_HOME_DIR:-./.hermes-runtime-example}"
CONFIG_TEMPLATE="${HERMES_RUNTIME_CONFIG_TEMPLATE:-examples/hermes-agent/config.local-llm.yaml}"
ENV_TEMPLATE="${HERMES_RUNTIME_ENV_TEMPLATE:-examples/hermes-agent/hermes-runtime.env.example}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_hermes_runtime_example.sh init
  ./scripts/run_hermes_runtime_example.sh up
  ./scripts/run_hermes_runtime_example.sh down
  ./scripts/run_hermes_runtime_example.sh status
  ./scripts/run_hermes_runtime_example.sh smoke
  ./scripts/run_hermes_runtime_example.sh logs

This manages the example full Hermes-agent gateway runtime in this repository.
It writes runtime state under ./.hermes-runtime-example, which is gitignored.
EOF
}

init_runtime() {
  mkdir -p "${DATA_DIR}"

  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${ENV_TEMPLATE}" "${ENV_FILE}"
    echo "Created ${ENV_FILE}"
  fi

  if [[ ! -f "${DATA_DIR}/config.yaml" ]]; then
    cp "${CONFIG_TEMPLATE}" "${DATA_DIR}/config.yaml"
    echo "Created ${DATA_DIR}/config.yaml"
  else
    echo "Keeping existing ${DATA_DIR}/config.yaml"
  fi

  if [[ ! -f "${DATA_DIR}/SOUL.md" ]]; then
    printf '%s\n' '# Hermes Local Runtime' '' 'Use the configured local LLM gateway for this runtime.' > "${DATA_DIR}/SOUL.md"
    echo "Created ${DATA_DIR}/SOUL.md"
  fi
}

compose() {
  docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

load_env_file() {
  if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "${ENV_FILE}"
    set +a
  fi
}

command="${1:-}"
case "${command}" in
  init)
    init_runtime
    ;;
  up)
    init_runtime
    compose up -d
    ;;
  down)
    compose down
    ;;
  status)
    compose ps
    ;;
  smoke)
    load_env_file
    HERMES_CONTAINER="${HERMES_CONTAINER:-${HERMES_CONTAINER_NAME:-local-llm-hermes}}" \
      ./scripts/smoke_hermes_runtime.sh
    ;;
  logs)
    compose logs -f hermes
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
