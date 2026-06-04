# Local Model Server Work Queue

## Active

- [x] Verify `docker-compose.gpu-mtp.example.yml` with
  `qwen3.5-2b-mtp-q4-xl` and confirm llama.cpp no longer logs
  `no implementations specified for speculative decoding`.
- [x] Run a longer MTP on/off benchmark at `LLAMA_CTX_SIZE=130000`; MTP was
  slower than the non-MTP Qwen Q4 XL profile for the recorded Hermes-summary
  workload.
- [x] Add persistent benchmark records for every benchmark attempt.
- [x] Test `LLAMA_CACHE_TYPE_K=q8_0` and `LLAMA_CACHE_TYPE_V=q8_0` for VRAM and
  speed tradeoffs. q8_0 lowered VRAM but was slower than f16 in recorded
  Hermes-routing benchmarks.
- [x] Add a Hermes-agent smoke test that calls
  `http://host.docker.internal:18080/v1`.

## Next

- [x] Add profile listing to `scripts/run_model_profile.sh`.
- [x] Add a small status command that prints current model, ctx, health, and
  VRAM.
- [x] Decide whether `.env` should remain the default manual configuration or
  be generated from selected model profiles. Decision: profiles are the source
  of truth for switching; `.env` remains a manual fallback and can be generated
  explicitly with `scripts/export_model_profile_env.sh`.
- [x] Add Qwen Q8 profile if Q4 XL quality is insufficient. Profile added as a
  quality fallback; default remains non-MTP Q4 XL based on current benchmarks.

## Later

- [ ] Add llama.cpp image/version update support.
- [ ] Record the current known-good llama.cpp image digest before updating.
- [ ] Add rollback support to return to the previous llama.cpp image/tag/digest.
- [ ] Document the update/rollback command flow and failure recovery steps.
- [ ] Evaluate building llama.cpp from source only if the container image lacks
  required MTP flags.
