#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

RESULTS_FILE="${AGENTCAP_RESULTS_FILE:-docs/verification/benchmarks/results/agent-capability-runs.jsonl}"
CTX_SIZE="${AGENTCAP_CTX_SIZE:-130000}"
DRY_RUN="${AGENTCAP_DRY_RUN:-0}"
HERMES_CONTAINER="${HERMES_CONTAINER:-local-llm-hermes-local-hostuid}"
HERMES_REPO_MOUNT="${HERMES_REPO_MOUNT:-/workspace/local-llm-server}"
HERMES_MODEL_PROVIDER="${HERMES_MODEL_PROVIDER:-custom}"
CHAT_BASE_URL="${AGENTCAP_CHAT_BASE_URL:-http://127.0.0.1:18080/v1}"
CHAT_API_KEY="${AGENTCAP_CHAT_API_KEY:-local-not-required}"
CHAT_RESULTS_FILE="${AGENTCAP_CHAT_RESULTS_FILE:-docs/verification/benchmarks/results/chat-benchmarks.jsonl}"
CHAT_BENCH_TIMEOUT="${AGENTCAP_CHAT_BENCH_TIMEOUT:-660}"
HERMES_TOOL_TIMEOUT="${HERMES_TOOL_TIMEOUT:-420}"
HERMES_LOOP_TIMEOUT="${HERMES_LOOP_TIMEOUT:-300}"
HERMES_WIKI_TIMEOUT="${HERMES_WIKI_TIMEOUT:-420}"

DEFAULT_PROFILES=(
  qwen3.5-2b-q4-xl
  gemma4-e2b-q4
  gemma4-e4b-it-qat-q2-xl
)

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_agent_capability_eval.sh [profile ...]

Runs the Hermes agent-capability harness for one or more model profiles:
  1. start selected local model profile
  2. start Hermes hostuid runtime
  3. verify the repository is mounted into the Hermes container
  4. run Hermes API smoke
  5. run speed, routing, multiturn, tool-routing, loop-resistance, and
     wiki/file-work tests

Environment:
  AGENTCAP_DRY_RUN=1          Print commands without running them.
  AGENTCAP_CTX_SIZE=130000    Context size passed to run_model_profile.sh.
  AGENTCAP_RESULTS_FILE=...   JSONL result file, ignored by git under results/.
  AGENTCAP_CHAT_RESULTS_FILE=...  benchmark_chat.py JSONL output.
  AGENTCAP_CHAT_BASE_URL=...   OpenAI-compatible local model base URL.
  HERMES_REPO_MOUNT=...       Repo path inside Hermes container.

Examples:
  AGENTCAP_DRY_RUN=1 ./scripts/run_agent_capability_eval.sh
  ./scripts/run_agent_capability_eval.sh qwen3.5-2b-q4-xl
EOF
}

profile_value() {
  local profile_path="$1"
  local key="$2"

  awk -F= -v key="${key}" '
    $1 == key {
      value = substr($0, length($1) + 2)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "${profile_path}"
}

is_truthy() {
  [[ "${1:-}" =~ ^(1|true|TRUE|True|yes|YES|Yes)$ ]]
}

run_cmd() {
  echo "+ $*"
  if is_truthy "${DRY_RUN}"; then
    return 0
  fi
  "$@"
}

append_json_record() {
  local profile="$1"
  local model="$2"
  local test_name="$3"
  local status="$4"
  local exit_code="$5"
  local elapsed_seconds="$6"
  local session_id="$7"
  local output_file="$8"
  local details_json="${9:-"{}"}"

  if is_truthy "${DRY_RUN}"; then
    return 0
  fi

  python3 - "$RESULTS_FILE" "$profile" "$model" "$test_name" "$status" "$exit_code" "$elapsed_seconds" "$session_id" "$output_file" "$details_json" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

path, profile, model, test_name, status, exit_code, elapsed, session_id, output_file, details_raw = sys.argv[1:]
try:
    details = json.loads(details_raw)
except json.JSONDecodeError:
    details = {"details_parse_error": details_raw}
record = {
    "recorded_at": datetime.now(timezone.utc).isoformat(),
    "profile": profile,
    "model": model,
    "test": test_name,
    "status": status,
    "exit_code": int(exit_code),
    "elapsed_seconds": float(elapsed),
    "session_id": session_id or None,
    "output_file": output_file,
    "details": details,
}
target = Path(path)
target.parent.mkdir(parents=True, exist_ok=True)
with target.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True))
    handle.write("\n")
PY
}

run_chat_benchmark() {
  local profile="$1"
  local model="$2"
  local preset="$3"
  local label="$4"
  local timeout_seconds="$5"

  local output_dir output_file started ended elapsed status exit_code
  output_dir="docs/verification/benchmarks/results/agentcap"
  output_file="${output_dir}/${profile}-${label}.json"
  mkdir -p "${output_dir}"

  echo
  echo "== ${profile}: ${preset} (${label}) =="
  echo "Output: ${output_file}"
  if is_truthy "${DRY_RUN}"; then
    echo "+ timeout ${timeout_seconds} ./scripts/benchmark_chat.py --profile ${profile} --model ${model} --preset ${preset} --label ${label}"
    append_json_record "${profile}" "${model}" "${label}" "dry-run" 0 0 "" "${output_file}" '{"kind":"chat-benchmark"}'
    return 0
  fi

  started="$(date +%s)"
  set +e
  timeout "${timeout_seconds}" \
    ./scripts/benchmark_chat.py \
      --base-url "${CHAT_BASE_URL}" \
      --api-key "${CHAT_API_KEY}" \
      --profile "${profile}" \
      --model "${model}" \
      --preset "${preset}" \
      --label "${label}" \
      --timeout "${timeout_seconds}" \
      --output "${CHAT_RESULTS_FILE}" \
    > "${output_file}" 2>&1
  exit_code="$?"
  set -e
  ended="$(date +%s)"
  elapsed="$((ended - started))"

  if [[ "${exit_code}" -eq 0 ]]; then
    status="success"
  elif [[ "${exit_code}" -eq 124 ]]; then
    status="timeout"
  else
    status="failed"
  fi

  append_json_record "${profile}" "${model}" "${label}" "${status}" "${exit_code}" "${elapsed}" "" "${output_file}" '{"kind":"chat-benchmark"}'
  echo "status=${status} elapsed=${elapsed}s"
  tail -30 "${output_file}" || true
  return "${exit_code}"
}

run_hermes_chat_test() {
  local profile="$1"
  local model="$2"
  local test_name="$3"
  local timeout_seconds="$4"
  local toolsets="$5"
  local max_turns="$6"
  local prompt="$7"
  shift 7

  local output_dir output_file started ended elapsed status exit_code session_id
  output_dir="docs/verification/benchmarks/results/agentcap"
  output_file="${output_dir}/${profile}-${test_name}.txt"
  mkdir -p "${output_dir}"

  echo
  echo "== ${profile}: ${test_name} =="
  echo "Output: ${output_file}"
  if is_truthy "${DRY_RUN}"; then
    echo "+ timeout ${timeout_seconds} docker exec -i ${HERMES_CONTAINER} hermes chat -Q ..."
    append_json_record "${profile}" "${model}" "${test_name}" "dry-run" 0 0 "" "${output_file}"
    return 0
  fi

  started="$(date +%s)"
  set +e
  timeout "${timeout_seconds}" \
    docker exec -i "${HERMES_CONTAINER}" \
    /opt/hermes/.venv/bin/hermes chat -Q \
      -q "${prompt}" \
      -m "${model}" \
      --provider "${HERMES_MODEL_PROVIDER}" \
      -t "${toolsets}" \
      --max-turns "${max_turns}" \
      "$@" \
    > "${output_file}" 2>&1
  exit_code="$?"
  set -e
  ended="$(date +%s)"
  elapsed="$((ended - started))"

  if [[ "${exit_code}" -eq 0 ]]; then
    status="success"
  elif [[ "${exit_code}" -eq 124 ]]; then
    status="timeout"
  else
    status="failed"
  fi
  session_id="$(sed -n 's/^session_id: //p' "${output_file}" | tail -1)"
  append_json_record "${profile}" "${model}" "${test_name}" "${status}" "${exit_code}" "${elapsed}" "${session_id}" "${output_file}" '{"kind":"hermes-chat"}'

  echo "status=${status} elapsed=${elapsed}s session_id=${session_id:-n/a}"
  tail -20 "${output_file}" || true
  return "${exit_code}"
}

verify_wiki_artifact() {
  local profile="$1"
  local model="$2"
  local artifact="/opt/data/workspace/agentcap/local-models/${profile}-hermes-model-selection.md"
  local started ended elapsed status exit_code details

  echo
  echo "== ${profile}: wiki-artifact-check =="
  if is_truthy "${DRY_RUN}"; then
    echo "+ docker exec ${HERMES_CONTAINER} test -s ${artifact}"
    append_json_record "${profile}" "${model}" "wiki-artifact-check" "dry-run" 0 0 "" "${artifact}" '{"kind":"artifact-check"}'
    return 0
  fi

  started="$(date +%s)"
  set +e
  docker exec "${HERMES_CONTAINER}" test -s "${artifact}"
  exit_code="$?"
  set -e
  ended="$(date +%s)"
  elapsed="$((ended - started))"

  if [[ "${exit_code}" -eq 0 ]]; then
    status="success"
    details='{"kind":"artifact-check","artifact_exists":true}'
  else
    status="failed"
    details='{"kind":"artifact-check","artifact_exists":false}'
  fi
  append_json_record "${profile}" "${model}" "wiki-artifact-check" "${status}" "${exit_code}" "${elapsed}" "" "${artifact}" "${details}"
  echo "status=${status} artifact=${artifact}"
  return "${exit_code}"
}

verify_repo_mount() {
  local expected="${HERMES_REPO_MOUNT}/docs/verification/benchmarks/agent-capability-protocol.md"
  run_cmd docker exec "${HERMES_CONTAINER}" test -r "${expected}"
}

run_profile() {
  local profile="$1"
  local profile_path model
  profile_path="model-profiles/${profile}.env"
  if [[ ! -f "${profile_path}" ]]; then
    echo "Unknown profile: ${profile}" >&2
    return 2
  fi
  model="$(profile_value "${profile_path}" PUBLIC_MODEL_NAME)"
  if [[ -z "${model}" ]]; then
    echo "Profile has no PUBLIC_MODEL_NAME: ${profile}" >&2
    return 2
  fi

  echo
  echo "###############################################################################"
  echo "Agent capability evaluation: ${profile} (${model})"
  echo "###############################################################################"

  run_cmd ./scripts/run_model_profile.sh "${profile}" "${CTX_SIZE}"
  run_cmd ./scripts/run_hermes_runtime_example.sh up-hostuid
  verify_repo_mount

  if ! is_truthy "${DRY_RUN}"; then
    HERMES_AGENT_MODEL="${model}" ./scripts/run_hermes_runtime_example.sh smoke-hostuid || true
  else
    echo "+ HERMES_AGENT_MODEL=${model} ./scripts/run_hermes_runtime_example.sh smoke-hostuid"
  fi

  run_chat_benchmark "${profile}" "${model}" "short-ready" "${profile}-agentcap-short-ready-cold" 300 || true
  run_chat_benchmark "${profile}" "${model}" "short-ready" "${profile}-agentcap-short-ready-warm" 300 || true
  run_chat_benchmark "${profile}" "${model}" "hermes-routing" "${profile}-agentcap-hermes-routing" "${CHAT_BENCH_TIMEOUT}" || true
  run_chat_benchmark "${profile}" "${model}" "local-agent-multiturn" "${profile}-agentcap-local-agent-multiturn" "${CHAT_BENCH_TIMEOUT}" || true

  local tool_prompt loop_prompt wiki_prompt
  tool_prompt="Use one public source to answer. Prefer terminal curl over browser. Fetch https://raw.githubusercontent.com/ggml-org/llama.cpp/master/examples/server/README.md if network works, then summarize one relevant fact in Korean about llama.cpp server OpenAI-compatible API, cite the URL, and stop after one concise answer."
  loop_prompt="Inspect ${HERMES_REPO_MOUNT}/docs/verification/benchmarks if needed. Do not modify files. Return at most three concrete next tasks for improving this local LLM project and stop."
  wiki_prompt="Read ${HERMES_REPO_MOUNT}/docs/verification/benchmarks/2026-06-06-agent-capability-3-models.md and ${HERMES_REPO_MOUNT}/docs/verification/benchmarks/agent-capability-protocol.md. Then write /opt/data/workspace/agentcap/local-models/${profile}-hermes-model-selection.md explaining which local model should be used for Hermes-agent today. Separate verified facts from assumptions, include dates, and stop after writing the file and summarizing the path."

  run_hermes_chat_test "${profile}" "${model}" "tool-routing" "${HERMES_TOOL_TIMEOUT}" "terminal,web,browser" 6 "${tool_prompt}" || true
  run_hermes_chat_test "${profile}" "${model}" "loop-resistance" "${HERMES_LOOP_TIMEOUT}" "terminal,file" 4 "${loop_prompt}" || true
  run_hermes_chat_test "${profile}" "${model}" "wiki-file-work" "${HERMES_WIKI_TIMEOUT}" "terminal,file" 8 "${wiki_prompt}" --yolo || true
  verify_wiki_artifact "${profile}" "${model}" || true
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  local profiles=("$@")
  if [[ "${#profiles[@]}" -eq 0 ]]; then
    profiles=("${DEFAULT_PROFILES[@]}")
  fi

  for profile in "${profiles[@]}"; do
    run_profile "${profile}"
  done

  echo
  echo "Results JSONL: ${RESULTS_FILE}"
}

main "$@"
