# Agent Capability Benchmark Protocol

## Purpose

This protocol evaluates whether a local model is useful as an agent model, not
only whether it can generate tokens quickly. It combines llama.cpp timing,
Hermes-agent tool behavior, loop resistance, task completion, and wiki/memory
quality.

Use this protocol when choosing the default local model for Hermes-agent or any
other local-agent consumer of this project.

## Model Candidates

Each comparison run should list the exact profiles under test. The first
planned three-model comparison uses:

- `qwen3.5-2b-q4-xl`
- `gemma4-e2b-q4`
- `gemma4-e4b-it-qat-q2-xl`

## Required Runtime Metadata

Record these for every model:

- profile name
- public model name
- GGUF file path and byte size
- `mmproj` file path and byte size, if used
- requested context size
- health-reported `n_ctx`
- llama.cpp version or Docker image digest
- container start time to healthy state
- cold VRAM/RAM before load
- loaded VRAM/RAM after health
- peak VRAM/RAM during benchmark if observable
- benchmark start/end timestamps

## Automation Harness

Use the maintained harness when repeating the Hermes-agent tool/file tests:

```bash
./scripts/run_agent_capability_eval.sh qwen3.5-2b-q4-xl
```

To preview commands without starting containers:

```bash
AGENTCAP_DRY_RUN=1 ./scripts/run_agent_capability_eval.sh
```

The harness starts each model profile, starts the hostuid Hermes runtime,
verifies the repository is mounted inside the Hermes container, runs the
hostuid smoke check, and then runs bounded one-shot tests for tool routing,
loop resistance, and wiki/file work. Raw JSONL records are appended to:

```text
docs/verification/benchmarks/results/agent-capability-runs.jsonl
```

The hostuid Hermes container should see this repository at:

```text
/workspace/local-llm-server
```

Override the mount path with `HERMES_REPO_DIR` and `HERMES_REPO_MOUNT` in
`.env.hermes-local-llm-hostuid` when testing a moved or USB-hosted checkout.

## Test Set

### 1. Speed Smoke

Goal: establish basic timing and cache behavior.

Run:

```bash
./scripts/benchmark_chat.py \
  --profile <profile> \
  --model <model> \
  --preset short-ready \
  --label <profile>-agentcap-short-ready-cold \
  --timeout 300

./scripts/benchmark_chat.py \
  --profile <profile> \
  --model <model> \
  --preset short-ready \
  --label <profile>-agentcap-short-ready-warm \
  --timeout 300
```

Record:

- elapsed ms
- prompt tok/s
- generation tok/s
- cache tokens
- success/failure

### 2. Hermes Routing

Goal: test local-agent planning under a compact but realistic instruction.

Run:

```bash
./scripts/benchmark_chat.py \
  --profile <profile> \
  --model <model> \
  --preset hermes-routing \
  --label <profile>-agentcap-hermes-routing \
  --timeout 420
```

Evaluate:

- whether the model returns a finite answer
- whether it produces executable steps
- whether it avoids vague filler
- whether the answer fits the requested format

### 3. Multiturn Planning

Goal: test whether the model keeps task state over multiple turns.

Run:

```bash
./scripts/benchmark_chat.py \
  --profile <profile> \
  --model <model> \
  --preset local-agent-multiturn \
  --label <profile>-agentcap-local-agent-multiturn \
  --timeout 600
```

Evaluate:

- state retention
- consistency across turns
- concrete next actions
- whether it forgets earlier constraints

### 4. Hermes Tool Routing

Goal: test whether Hermes-agent can use tools without wasteful loops.

Task prompt:

```text
Find one public source about the current local LLM benchmark target, summarize
the relevant fact in Korean, and cite the source URL. Use browser/search only
if needed. Stop after one concise answer.
```

Record:

- tools called
- number of tool calls
- whether tool use was necessary
- whether the model repeated the same tool call
- whether it cited a useful URL
- final answer quality
- total elapsed time

### 5. File Work / Wiki Update

Goal: test whether the model can build a useful local LLM wiki entry.

Task prompt:

```text
Read the existing benchmark docs, then create or update one wiki-style markdown
entry that explains which local model should be used for Hermes-agent today.
Separate verified facts from assumptions and include dates.
```

Expected target area:

```text
docs/wiki/local-models/
```

Record:

- files read
- files created/modified
- whether it avoided duplicate pages
- whether it separated facts, assumptions, and next checks
- whether the entry is useful to a future human/agent

### 6. Loop Resistance

Goal: check whether the model can shrink ambiguous work and stop.

Task prompt:

```text
Improve this local LLM project. You may inspect docs, but do not modify files.
Return at most three concrete next tasks and stop.
```

Record:

- whether it stops after three tasks
- whether it asks unnecessary questions
- whether it keeps inspecting files after enough context
- whether it repeats commands or tool calls
- whether it invents unrelated work

### 7. Mini Project Completion

Goal: measure end-to-end agent usefulness.

Task prompt:

```text
Using the available benchmark notes, produce a short model selection guide for
Hermes-agent. Include a recommendation, tradeoffs, and the next benchmark.
Save it as a markdown draft under the appropriate docs folder.
```

Record:

- final artifact path
- whether the recommendation follows evidence
- whether tradeoffs are concrete
- whether next benchmark is actionable
- whether the model stops after completing the artifact

## Scoring

Score each category from `0` to `5`.

| Score | Meaning |
| --- | --- |
| `0` | Did not run, crashed, or unusable |
| `1` | Completed only with severe errors or loops |
| `2` | Partially completed but unreliable |
| `3` | Usable with noticeable supervision |
| `4` | Good enough for normal use |
| `5` | Strong, efficient, and low-supervision |

Required categories:

- Speed
- Stability
- Instruction following
- Tool use
- Loop resistance
- Goal completion
- Answer quality
- Wiki/memory quality
- Operational fit

## Default Weighting

For Hermes-agent default model selection:

| Category | Weight |
| --- | ---: |
| Speed | `20%` |
| Stability | `20%` |
| Tool use | `20%` |
| Goal completion | `20%` |
| Loop resistance | `10%` |
| Wiki/memory quality | `10%` |

Answer quality should be recorded separately. A slower model can be retained as
a quality or wiki-building candidate, but the default Hermes-agent model should
not make routine tool work feel blocked.

## Failure Rules

Mark the model as unsuitable for default local-agent use if any of these occur:

- health does not become ready
- a warm short-ready request exceeds `30s`
- Hermes-routing exceeds `120s`
- the model repeats the same tool call more than twice without new information
- the model continues after the goal is complete
- the model writes unrelated files
- the model cannot produce a usable final answer

Do not delete failed records. Failed rows are evidence for runtime and model
selection decisions.
