# Local LLM Server Docs

## Folders

- `dev-log/`: chronological notes from implementation and experiments.
- `specs/`: intended behavior and interface contracts.
- `verification/`: commands, observed outputs, and test results.
- `work-queue/`: pending work, deferred decisions, and follow-up tasks.

## Current Focus

The active planning target is a shared local model switching interface.
Consumers should keep using a stable OpenAI-compatible endpoint while this
project owns model profiles, llama.cpp runtime settings, and update/rollback
workflows.

Hermes-agent has dedicated compatibility docs because it is the highest-friction
consumer so far. Those docs are consumer-specific and do not redefine the
project scope.

Benchmark records live under `verification/benchmarks/` and should be appended
for every meaningful runtime change.

## Quick Commands

List available local model profiles:

```bash
./scripts/run_model_profile.sh list
```

Switch to Qwen or Gemma:

```bash
./scripts/run_model_profile.sh qwen3.5-2b-q4-xl 130000
./scripts/run_model_profile.sh gemma4-e2b-q4 130000
```

Check the stable endpoint:

```bash
./scripts/run_model_profile.sh status
curl -fsS http://127.0.0.1:18080/v1/health
```

Model switching recreates the `llama` and `gateway` containers. The endpoint
address stays stable, but there is short downtime while llama.cpp reloads the
selected GGUF and warms up the configured context.

Use these docs first:

- `specs/local-model-switching.md`: switching contract and profile list.
- `specs/hermes-agent-llama-cpp-compatibility.md`: Hermes custom endpoint,
  gateway sanitizer, and Docker smoke container contract.
- `specs/hermes-agent-runtime-integration.md`: non-sensitive operational notes
  imported from the local Hermes runtime repo.
- `verification/llama-runtime-compatibility.md`: llama.cpp version and model
  compatibility matrix.
- `verification/hermes-agent-compatibility.md`: observed Hermes-agent
  container connection results.
- `verification/hermes-storage-compatibility.md`: environment matrix for Hermes
  `/opt/data` storage backends.
- `verification/benchmarks/`: benchmark records and comparison notes.
