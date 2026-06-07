# llama.cpp Server OpenAI-Compatible API Fixture

This deterministic fixture is used by local Hermes-agent tool-routing tests.
It avoids external network and URL drift so the benchmark measures tool
selection, file access, and final-answer discipline instead of web search
availability.

Verified fact for benchmark use:

- `llama-server` exposes an OpenAI-compatible HTTP API under `/v1`, including
  chat completion style requests through `/v1/chat/completions`.

Source path to cite in benchmark answers:

```text
/workspace/local-llm-server/docs/verification/benchmarks/fixtures/llama-server-openai-api.md
```
