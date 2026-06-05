#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${HERMES_RUNTIME_COMPOSE_FILE:-docker-compose.hermes-runtime.example.yml}"
ENV_FILE="${HERMES_RUNTIME_ENV_FILE:-.env.hermes-runtime}"
HOSTUID_COMPOSE_FILE="${HERMES_HOSTUID_COMPOSE_FILE:-docker-compose.hermes-local-llm.yml}"
HOSTUID_ENV_FILE="${HERMES_HOSTUID_ENV_FILE:-.env.hermes-local-llm-hostuid}"
HOSTUID_ENV_TEMPLATE="${HERMES_HOSTUID_ENV_TEMPLATE:-examples/hermes-agent/hermes-local-llm.hostuid.env.example}"
SEED_DIR="${HERMES_SEED_DIR:-./.hermes-runtime-example}"
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
  ./scripts/run_hermes_runtime_example.sh init-hostuid
  ./scripts/run_hermes_runtime_example.sh up-hostuid
  ./scripts/run_hermes_runtime_example.sh down-hostuid
  ./scripts/run_hermes_runtime_example.sh status-hostuid
  ./scripts/run_hermes_runtime_example.sh smoke-hostuid
  ./scripts/run_hermes_runtime_example.sh logs-hostuid

This manages the example full Hermes-agent gateway runtime in this repository.
It stores Hermes runtime state in a Docker named volume. The gitignored
./.hermes-runtime-example directory is only a seed/config source.

The hostuid commands use docker-compose.hermes-local-llm.yml. They store Hermes
runtime state in a host bind directory and run the container as uid/gid 1000.
EOF
}

init_runtime() {
  mkdir -p "${SEED_DIR}"

  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${ENV_TEMPLATE}" "${ENV_FILE}"
    echo "Created ${ENV_FILE}"
  else
    migrate_env_defaults
  fi

  if [[ ! -f "${SEED_DIR}/config.yaml" ]]; then
    cp "${CONFIG_TEMPLATE}" "${SEED_DIR}/config.yaml"
    echo "Created ${SEED_DIR}/config.yaml"
  else
    echo "Keeping existing ${SEED_DIR}/config.yaml"
  fi

  if [[ ! -f "${SEED_DIR}/SOUL.md" ]]; then
    printf '%s\n' '# Hermes Local Runtime' '' 'Use the configured local LLM gateway for this runtime.' > "${SEED_DIR}/SOUL.md"
    echo "Created ${SEED_DIR}/SOUL.md"
  fi
}

migrate_env_defaults() {
  local tmp_file
  tmp_file="$(mktemp)"
  awk '
    /^HERMES_UID=1000$/ { print "HERMES_UID=10000"; changed=1; next }
    /^HERMES_GID=1000$/ { print "HERMES_GID=10000"; changed=1; next }
    /^HERMES_HOME_DIR=/ { print "HERMES_SEED_DIR=./.hermes-runtime-example"; print "HERMES_DATA_VOLUME=local-llm-hermes-data"; changed=1; next }
    { print }
    END { if (changed) exit 42 }
  ' "${ENV_FILE}" > "${tmp_file}" || {
    local status="$?"
    if [[ "${status}" -eq 42 ]]; then
      cp "${tmp_file}" "${ENV_FILE}"
      echo "Updated ${ENV_FILE} HERMES_UID/HERMES_GID defaults to 10000"
      rm -f "${tmp_file}"
      return
    fi
    rm -f "${tmp_file}"
    return "${status}"
  }
  rm -f "${tmp_file}"
}

compose() {
  docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

hostuid_compose() {
  docker compose -f "${HOSTUID_COMPOSE_FILE}" --env-file "${HOSTUID_ENV_FILE}" "$@"
}

load_env_file() {
  local env_file="$1"
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "${env_file}"
    set +a
  fi
}

env_value() {
  local key="$1"
  local default="$2"
  local env_file="${3:-${ENV_FILE}}"
  if [[ -f "${env_file}" ]]; then
    local value
    value="$(sed -n "s/^${key}=//p" "${env_file}" | tail -1)"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return
    fi
  fi
  printf '%s\n' "${default}"
}

port_is_listening() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn "sport = :${port}" | grep -q ":${port}"
    return
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi
  python3 - "${port}" <<'PY'
import socket
import sys

port = int(sys.argv[1])
with socket.socket() as sock:
    sock.settimeout(0.25)
    raise SystemExit(0 if sock.connect_ex(("127.0.0.1", port)) == 0 else 1)
PY
}

container_is_running() {
  local container="$1"
  [[ "$(docker inspect -f '{{.State.Running}}' "${container}" 2>/dev/null || true)" == "true" ]]
}

preflight_ports() {
  local env_file default_container default_api_port default_dashboard_port
  env_file="${1:-${ENV_FILE}}"
  default_container="${2:-local-llm-hermes}"
  default_api_port="${3:-8642}"
  default_dashboard_port="${4:-9119}"

  local container_name api_port dashboard_port
  container_name="$(env_value HERMES_CONTAINER_NAME "${default_container}" "${env_file}")"
  api_port="$(env_value HERMES_API_PORT "${default_api_port}" "${env_file}")"
  dashboard_port="$(env_value HERMES_DASHBOARD_PORT "${default_dashboard_port}" "${env_file}")"

  local conflict=0
  if port_is_listening "${api_port}" && ! container_is_running "${container_name}"; then
    echo "Port ${api_port} is already in use, and ${container_name} is not running." >&2
    conflict=1
  fi
  if port_is_listening "${dashboard_port}" && ! container_is_running "${container_name}"; then
    echo "Port ${dashboard_port} is already in use, and ${container_name} is not running." >&2
    conflict=1
  fi

  if [[ "${conflict}" -ne 0 ]]; then
    cat >&2 <<EOF
Edit ${env_file} before starting, for example:
  HERMES_API_PORT=18642
  HERMES_DASHBOARD_PORT=19119

If a failed example container is left behind, run:
  ./scripts/run_hermes_runtime_example.sh down
EOF
    exit 7
  fi
}

require_running_container() {
  local env_file default_container start_command
  env_file="${1:-${ENV_FILE}}"
  default_container="${2:-local-llm-hermes}"
  start_command="${3:-./scripts/run_hermes_runtime_example.sh up}"

  local container_name
  container_name="$(env_value HERMES_CONTAINER_NAME "${default_container}" "${env_file}")"
  if ! container_is_running "${container_name}"; then
    cat >&2 <<EOF
Hermes example container '${container_name}' is not running.

Start it with:
  ${start_command}

If startup failed because ports are already allocated, edit ${env_file}:
  HERMES_API_PORT=18642
  HERMES_DASHBOARD_PORT=19119
EOF
    exit 8
  fi
}

init_hostuid_runtime() {
  init_runtime

  if [[ ! -f "${HOSTUID_ENV_FILE}" ]]; then
    cp "${HOSTUID_ENV_TEMPLATE}" "${HOSTUID_ENV_FILE}"
    echo "Created ${HOSTUID_ENV_FILE}"
  else
    echo "Keeping existing ${HOSTUID_ENV_FILE}"
  fi
}

command="${1:-}"
case "${command}" in
  init)
    init_runtime
    ;;
  up)
    init_runtime
    preflight_ports
    compose up -d
    ;;
  down)
    compose down
    ;;
  status)
    compose ps
    ;;
  smoke)
    load_env_file "${ENV_FILE}"
    require_running_container
    HERMES_CONTAINER="${HERMES_CONTAINER:-${HERMES_CONTAINER_NAME:-local-llm-hermes}}" \
      ./scripts/smoke_hermes_runtime.sh
    ;;
  logs)
    compose logs -f hermes
    ;;
  init-hostuid)
    init_hostuid_runtime
    ;;
  up-hostuid)
    init_hostuid_runtime
    preflight_ports "${HOSTUID_ENV_FILE}" local-llm-hermes-local-hostuid 48642 49119
    hostuid_compose up -d
    ;;
  down-hostuid)
    hostuid_compose down
    ;;
  status-hostuid)
    hostuid_compose ps
    ;;
  smoke-hostuid)
    load_env_file "${HOSTUID_ENV_FILE}"
    require_running_container "${HOSTUID_ENV_FILE}" local-llm-hermes-local-hostuid "./scripts/run_hermes_runtime_example.sh up-hostuid"
    HERMES_CONTAINER="${HERMES_CONTAINER:-${HERMES_CONTAINER_NAME:-local-llm-hermes-local-hostuid}}" \
      ./scripts/smoke_hermes_runtime.sh
    ;;
  logs-hostuid)
    hostuid_compose logs -f hermes
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
