# HADARA + Local LLM + Hermes Extra Experiment

## Purpose

This is an extra curiosity experiment, not a primary Local LLM Server roadmap
item. The goal is to check whether a local model running through Hermes-agent
can use the npm package `hadara` as a coding workflow tool.

## Package Under Test

Registry metadata checked on 2026-06-07 KST:

| Field | Value |
| --- | --- |
| Package | `hadara` |
| Version | `0.2.0-rc.2` |
| Description | `HADARA: portable agentic development workbench` |
| CLI bin | `hadara` |
| Runtime requirement from README | Node.js 22 |
| Local host Node/npm | Node `v22.22.3`, npm `10.9.8` |

The package README describes HADARA as a portable agentic development workbench
with Task Capsules, Evidence Logs, Handoff Protocol, Policy Surfaces, CLI JSON
reports, and read-only MCP bridge surfaces.

## Direct CLI Smoke

Command shape:

```bash
npm exec --yes hadara@0.2.0-rc.2 -- doctor --json
npm exec --yes hadara@0.2.0-rc.2 -- tools list --json
```

Result:

- `doctor --json` ran in a temporary empty directory.
- It returned `ok:false` because `docs`, `tasks`, and
  `.hadara/context/HADARA_CONTEXT.md` were missing. This is expected for an
  uninitialized empty project.
- `tools list --json` returned CLI and MCP surfaces.

Init smoke:

```bash
npm exec --yes hadara@0.2.0-rc.2 -- init --profile basic
npm exec --yes hadara@0.2.0-rc.2 -- doctor --json
npm exec --yes hadara@0.2.0-rc.2 -- task list --json
```

Result:

- `init --profile basic` created `AGENTS.md`, `docs/`, and `tasks/`.
- `doctor --json` then reported `docs` and `tasks` as `ok`.
- `.hadara/context/HADARA_CONTEXT.md` remained missing, which is expected until
  context export is used.
- `task list --json` returned an empty task list with `ok:true`.

Direct conclusion: `hadara@0.2.0-rc.2` is installable and usable from npm in
this host environment.

## Hermes / Local LLM Setup

| Item | Value |
| --- | --- |
| Date | 2026-06-07 KST |
| Hermes runtime | `docker-compose.hermes-local-llm.yml` hostuid mode |
| Local model | `qwen3.5-2b-ud-q4-k-xl` |
| Context | `130000` requested, health reports `130048` |
| Workspace | `/opt/data/workspace/hadara-extra-coding` |
| Hermes toolset | `terminal` |

The hostuid runtime already mounts:

- this repo read-only at `/workspace/local-llm-server`
- Hermes data/workspace writable at `/opt/data`

## Hermes Attempt 1: Autonomous Coding Task

Session: `20260607_140733_cde6c8`

Prompt intent:

- create `/opt/data/workspace/hadara-extra-coding`
- run `hadara init --profile basic`
- create a tiny Node project with `src/add.mjs` and `test/add.test.mjs`
- run `npm test`
- run `hadara doctor --json`
- run `hadara task list --json`
- write `EXPERIMENT_RESULT.md`

Observed result:

- Hermes/Qwen ran `hadara init --profile basic` successfully.
- It created the HADARA scaffold and partial Node project files.
- It initially tried to write `test/add.test.mjs` before creating `test/`, then
  created the directory and wrote the file.
- It hit `max-turns=8` before running `npm test`, `doctor`, `task list`, or
  writing the result document.
- Its final summary incorrectly claimed `test/add.test.mjs` was not created.

Direct verification after the session:

```bash
cd /opt/data/workspace/hadara-extra-coding
npm test
```

Result:

- Failed.
- Test file imported `expect` from `node:test`, but Node's built-in test module
  does not export `expect`.
- The test file also did not import `add`.

Verdict: **failed autonomous coding task**.

## Hermes Attempt 2: Debug Existing Failure

Session: `20260607_141130_354f2f`

Prompt intent:

- run `npm test`
- inspect the failure
- fix tests using `node:test` and `node:assert/strict`
- run `npm test`
- run HADARA JSON checks
- write `EXPERIMENT_RESULT.md`

Observed result:

- The model diagnosed the rough class of failure.
- It did not make a valid tool call for the fix.
- It emitted a literal `<tool_call>` block in the final response.
- It reached `max-turns=10`.

Verdict: **failed debug/coding continuation**.

## Hermes Attempt 3: Exact Shell Recipe

Session: `20260607_141346_b47eba`

Prompt intent:

- run one exact shell command that overwrites the test file with an
  `assert/strict` version
- run `npm test`
- run HADARA JSON checks
- write `EXPERIMENT_RESULT.md`

Observed result:

- The model started the command as a background process and did not wait for
  completion.
- It checked for `EXPERIMENT_RESULT.md` too early.
- It then attempted more commands but still ended with a contradictory final
  summary.
- Direct verification showed `npm test` was still failing with the old
  `expect` import.

Verdict: **failed exact-recipe execution through the model**.

## Conclusion

`hadara` itself works in this environment. Hermes can also create and persist
files in `/opt/data/workspace`. The failure point is the current local model's
ability to drive even a small coding loop through Hermes terminal tools.

With `qwen3.5-2b-q4-xl`, the combination is not yet reliable for autonomous
`local LLM + Hermes + HADARA` coding. It can initialize HADARA and make partial
edits, but it loses task state, misreports command outcomes, and fails to
complete validation.

Practical rating for this extra experiment:

| Capability | Result |
| --- | --- |
| Direct `hadara` CLI use from host | pass |
| Hermes tool filesystem persistence | pass |
| Hermes/Qwen autonomous HADARA coding | fail |
| Hermes/Qwen debug/fix loop | fail |
| Hermes/Qwen exact shell recipe execution | fail in this run |

## Next Extra Experiments

- Repeat with `gemma4-e2b-q4` after ensuring the machine is idle.
- Add a stricter harness that checks tool exit codes after every Hermes turn.
- Use shorter prompts with a single required command per turn.
- Consider using HADARA as an external operator protocol first, then only let
  local LLMs execute narrow validated steps.
