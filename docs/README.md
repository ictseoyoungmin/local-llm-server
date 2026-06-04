# Local LLM Server Docs

## Folders

- `dev-log/`: chronological notes from implementation and experiments.
- `specs/`: intended behavior and interface contracts.
- `verification/`: commands, observed outputs, and test results.
- `work-queue/`: pending work, deferred decisions, and follow-up tasks.

## Current Focus

The active planning target is a local model switching interface for Hermes-agent.
Hermes-agent should keep using a stable OpenAI-compatible endpoint while this
project owns model profiles, llama.cpp runtime settings, and update/rollback
workflows.

Benchmark records live under `verification/benchmarks/` and should be appended
for every meaningful runtime change.
