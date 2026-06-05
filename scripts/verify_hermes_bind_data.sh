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
  ./scripts/verify_hermes_bind_data.sh run-host-uid
  ./scripts/verify_hermes_bind_data.sh down
  ./scripts/verify_hermes_bind_data.sh down-host-uid
  ./scripts/verify_hermes_bind_data.sh logs

This verifies whether a host bind-mounted Hermes data directory can be used as
/opt/data by the official Hermes-agent gateway container.

Default test paths:
  data: ./.hermes-runtime-bind-test
  env:  .env.hermes-bind-test

Host UID/GID test paths:
  data: ./.hermes-runtime-bind-host-uid
  env:  .env.hermes-bind-host-uid
EOF
}

compose() {
  docker compose -f "${BASE_COMPOSE_FILE}" -f "${BIND_COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

init_test_files() {
  local compose_project="$1"
  local container_name="$2"
  local data_dir="$3"
  local api_port="$4"
  local dashboard_port="$5"
  local uid="$6"
  local gid="$7"

  mkdir -p "${SEED_DIR}" "${data_dir}"

  if [[ ! -f "${SEED_DIR}/config.yaml" ]]; then
    cp "${CONFIG_TEMPLATE}" "${SEED_DIR}/config.yaml"
  fi
  if [[ ! -f "${SEED_DIR}/SOUL.md" ]]; then
    printf '%s\n' '# Hermes Local Runtime' '' 'Use the configured local LLM gateway for this runtime.' > "${SEED_DIR}/SOUL.md"
  fi

  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${ENV_TEMPLATE}" "${ENV_FILE}"
  fi

  set_env HERMES_COMPOSE_PROJECT_NAME "${compose_project}"
  set_env HERMES_CONTAINER_NAME "${container_name}"
  set_env HERMES_BIND_ENV_FILE "${ENV_FILE}"
  set_env HERMES_SEED_DIR "${SEED_DIR}"
  set_env HERMES_BIND_DATA_DIR "${data_dir}"
  set_env HERMES_DATA_VOLUME "${compose_project}-unused"
  set_env HERMES_API_PORT "${api_port}"
  set_env HERMES_DASHBOARD_PORT "${dashboard_port}"
  set_env HERMES_UID "${uid}"
  set_env HERMES_GID "${gid}"
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
  local container_name="$1"
  [[ "$(docker inspect -f '{{.State.Running}}' "${container_name}" 2>/dev/null || true)" == "true" ]]
}

run_test() {
  local compose_project="$1"
  local container_name="$2"
  local data_dir="$3"
  local api_port="$4"
  local dashboard_port="$5"
  local uid="$6"
  local gid="$7"

  init_test_files "${compose_project}" "${container_name}" "${data_dir}" "${api_port}" "${dashboard_port}" "${uid}" "${gid}"

  echo "Host bind data directory:"
  stat -c '  path=%n uid=%u gid=%g mode=%a fs=%T' "${data_dir}" || true
  echo "Container Hermes UID/GID: ${uid}:${gid}"

  echo "Starting Hermes bind-data test container"
  compose up -d --force-recreate

  echo "Waiting for container startup"
  sleep 12

  if ! container_is_running "${container_name}"; then
    echo "Container stopped during startup." >&2
    docker logs --tail 120 "${container_name}" >&2 || true
    exit 20
  fi

  echo "Container is still running; running Hermes smoke through bind-data container"
  HERMES_CONTAINER="${container_name}" \
  HERMES_API_READY_TIMEOUT_SECONDS="${HERMES_API_READY_TIMEOUT_SECONDS:-120}" \
    ./scripts/smoke_hermes_runtime.sh
}

down_test() {
  local env_file="$1"
  local compose_project="$2"
  local container_name="$3"
  local api_port="$4"
  local dashboard_port="$5"

  if [[ -f "${env_file}" ]]; then
    ENV_FILE="${env_file}" compose down
  else
    HERMES_COMPOSE_PROJECT_NAME="${compose_project}" \
    HERMES_CONTAINER_NAME="${container_name}" \
    HERMES_API_PORT="${api_port}" \
    HERMES_DASHBOARD_PORT="${dashboard_port}" \
    HERMES_BIND_ENV_FILE="${env_file}" \
    API_SERVER_KEY=change-me-local-hermes-key \
      docker compose -f "${BASE_COMPOSE_FILE}" -f "${BIND_COMPOSE_FILE}" down
  fi
}

command="${1:-run}"
case "${command}" in
  run)
    run_test local-llm-hermes-bind-test local-llm-hermes-bind-test "${DATA_DIR}" 28642 29119 10000 10000
    ;;
  run-host-uid)
    ENV_FILE="${HERMES_BIND_HOST_UID_ENV_FILE:-.env.hermes-bind-host-uid}"
    DATA_DIR="${HERMES_BIND_HOST_UID_DATA_DIR:-./.hermes-runtime-bind-host-uid}"
    run_test local-llm-hermes-bind-host-uid local-llm-hermes-bind-host-uid "${DATA_DIR}" 38642 39119 1000 1000
    ;;
  down)
    down_test "${ENV_FILE}" local-llm-hermes-bind-test local-llm-hermes-bind-test 28642 29119
    ;;
  down-host-uid)
    down_test "${HERMES_BIND_HOST_UID_ENV_FILE:-.env.hermes-bind-host-uid}" local-llm-hermes-bind-host-uid local-llm-hermes-bind-host-uid 38642 39119
    ;;
  logs)
    docker logs --tail 200 "${HERMES_CONTAINER_NAME:-local-llm-hermes-bind-test}"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
