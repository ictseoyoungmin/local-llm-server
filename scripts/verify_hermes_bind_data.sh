#!/usr/bin/env bash
set -euo pipefail

BASE_COMPOSE_FILE="${HERMES_RUNTIME_COMPOSE_FILE:-docker-compose.hermes-runtime.example.yml}"
BIND_COMPOSE_FILE="${HERMES_BIND_COMPOSE_FILE:-docker-compose.hermes-runtime.bind-test.yml}"
ENV_FILE="${HERMES_BIND_ENV_FILE:-.env.hermes-bind-test}"
SEED_DIR="${HERMES_SEED_DIR:-./.hermes-runtime-example}"
DATA_DIR="${HERMES_BIND_DATA_DIR:-./.hermes-runtime-bind-test}"
CONFIG_TEMPLATE="${HERMES_RUNTIME_CONFIG_TEMPLATE:-examples/hermes-agent/config.local-llm.yaml}"
ENV_TEMPLATE="${HERMES_RUNTIME_ENV_TEMPLATE:-examples/hermes-agent/hermes-runtime.env.example}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/verify_hermes_bind_data.sh run
  ./scripts/verify_hermes_bind_data.sh down
  ./scripts/verify_hermes_bind_data.sh logs

This verifies whether a host bind-mounted Hermes data directory can be used as
/opt/data by the official Hermes-agent gateway container.

Default test paths:
  data: ./.hermes-runtime-bind-test
  env:  .env.hermes-bind-test
EOF
}

compose() {
  docker compose -f "${BASE_COMPOSE_FILE}" -f "${BIND_COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

init_test_files() {
  mkdir -p "${SEED_DIR}" "${DATA_DIR}"

  if [[ ! -f "${SEED_DIR}/config.yaml" ]]; then
    cp "${CONFIG_TEMPLATE}" "${SEED_DIR}/config.yaml"
  fi
  if [[ ! -f "${SEED_DIR}/SOUL.md" ]]; then
    printf '%s\n' '# Hermes Local Runtime' '' 'Use the configured local LLM gateway for this runtime.' > "${SEED_DIR}/SOUL.md"
  fi

  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${ENV_TEMPLATE}" "${ENV_FILE}"
  fi

  set_env HERMES_COMPOSE_PROJECT_NAME local-llm-hermes-bind-test
  set_env HERMES_CONTAINER_NAME local-llm-hermes-bind-test
  set_env HERMES_SEED_DIR "${SEED_DIR}"
  set_env HERMES_BIND_DATA_DIR "${DATA_DIR}"
  set_env HERMES_DATA_VOLUME local-llm-hermes-bind-test-unused
  set_env HERMES_API_PORT 28642
  set_env HERMES_DASHBOARD_PORT 29119
  set_env HERMES_UID 10000
  set_env HERMES_GID 10000
}

set_env() {
  local key="$1"
  local value="$2"
  local tmp_file
  tmp_file="$(mktemp)"
  if [[ -f "${ENV_FILE}" ]] && grep -q "^${key}=" "${ENV_FILE}"; then
    sed "s#^${key}=.*#${key}=${value}#" "${ENV_FILE}" > "${tmp_file}"
  else
    if [[ -f "${ENV_FILE}" ]]; then
      cp "${ENV_FILE}" "${tmp_file}"
    fi
    printf '%s=%s\n' "${key}" "${value}" >> "${tmp_file}"
  fi
  cp "${tmp_file}" "${ENV_FILE}"
  rm -f "${tmp_file}"
}

container_is_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' local-llm-hermes-bind-test 2>/dev/null || true)" == "true" ]]
}

run_test() {
  init_test_files

  echo "Host bind data directory:"
  stat -c '  path=%n uid=%u gid=%g mode=%a fs=%T' "${DATA_DIR}" || true

  echo "Starting Hermes bind-data test container"
  compose up -d --force-recreate

  echo "Waiting for container startup"
  sleep 12

  if ! container_is_running; then
    echo "Container stopped during startup." >&2
    docker logs --tail 120 local-llm-hermes-bind-test >&2 || true
    exit 20
  fi

  echo "Container is still running; running Hermes smoke through bind-data container"
  HERMES_CONTAINER=local-llm-hermes-bind-test \
  HERMES_API_READY_TIMEOUT_SECONDS="${HERMES_API_READY_TIMEOUT_SECONDS:-120}" \
    ./scripts/smoke_hermes_runtime.sh
}

command="${1:-run}"
case "${command}" in
  run)
    run_test
    ;;
  down)
    if [[ -f "${ENV_FILE}" ]]; then
      compose down
    else
      HERMES_COMPOSE_PROJECT_NAME=local-llm-hermes-bind-test \
      HERMES_CONTAINER_NAME=local-llm-hermes-bind-test \
      HERMES_API_PORT=28642 \
      HERMES_DASHBOARD_PORT=29119 \
        docker compose -f "${BASE_COMPOSE_FILE}" -f "${BIND_COMPOSE_FILE}" down
    fi
    ;;
  logs)
    docker logs --tail 200 local-llm-hermes-bind-test
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
