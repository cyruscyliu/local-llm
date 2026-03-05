# Task 17: End-to-End Smoke Test (Reverse Proxy → LiteLLM → vLLM)

## Goal

Add a single command that proves the platform is actually usable end-to-end (ingress works, the API gateway is reachable, and the model backend is wired correctly).

## Dependencies

- `09_setup_reverse_proxy`

## Steps

1. Create `scripts/smoke_test.sh`:
   - Verify Nginx is reachable on `https://localhost/` (accept self-signed with `-k`)
   - Verify LiteLLM health via `https://localhost/api/health`
   - Verify the OpenAI-compatible models list via `https://localhost/api/v1/models`
   - (Optional) If `SMOKE_TEST_RUN_COMPLETION=1` is set:
     - Send a minimal chat completion request and assert a non-empty response
2. Ensure the script:
   - exits non-zero on failures
   - prints a short failure hint (which hop failed)
   - is safe to re-run (idempotent)
3. Document the smoke test in `README.md` (one command).

## Expected Outcome

- `scripts/smoke_test.sh` reliably fails when routing is broken.
- A new user can validate “is this platform up?” in under 30 seconds.

## Verification

```bash
test -x scripts/smoke_test.sh
bash scripts/smoke_test.sh
```

## Outputs

- `smoke_test`: "scripts/smoke_test.sh"

