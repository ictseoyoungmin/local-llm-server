# Local Model Server Work Queue

## Active

- [x] Verify `docker-compose.gpu-mtp.example.yml` with
  `qwen3.5-2b-mtp-q4-xl` and confirm llama.cpp no longer logs
  `no implementations specified for speculative decoding`.
- [ ] Run a longer MTP on/off benchmark at `LLAMA_CTX_SIZE=130000`; the short
  2-token check confirmed activation but was not a useful speed test.
- [x] Add persistent benchmark records for every benchmark attempt.
- [ ] Test `LLAMA_CACHE_TYPE_K=q8_0` and `LLAMA_CACHE_TYPE_V=q8_0` for VRAM and
  speed tradeoffs.
- [ ] Add a Hermes-agent smoke test that calls
  `http://host.docker.internal:18080/v1`.

## Next

- [x] Add profile listing to `scripts/run_model_profile.sh`.
- [x] Add a small status command that prints current model, ctx, health, and
  VRAM.
- [ ] Decide whether `.env` should remain the default manual configuration or
  be generated from selected model profiles.
- [ ] Add Qwen Q8 profile if Q4 XL quality is insufficient.

## Later

- [ ] Add llama.cpp image/version update support.
- [ ] Record the current known-good llama.cpp image digest before updating.
- [ ] Add rollback support to return to the previous llama.cpp image/tag/digest.
- [ ] Document the update/rollback command flow and failure recovery steps.
- [ ] Evaluate building llama.cpp from source only if the container image lacks
  required MTP flags.
