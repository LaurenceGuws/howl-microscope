# PTY experiment hardening (PH1-M8)

PH1-M8 tightens the **Linux-only guarded PTY experiment** with stable telemetry, stricter `run.json` invariants, and repeatable smoke evidence—without changing opt-in or host-gating rules from PH1-M7.

## Boundaries

- **In scope**: transport-level telemetry (`attempt` count, `elapsed_ns` for the experiment block), schema validation, compare metadata, unit/regression tests, smoke updates.
- **Out of scope**: ConPTY/Windows, screenshots/OCR, TUI polish, child processes, PTY I/O loops, retry policies beyond a single attempt.

## Risks

| Risk | Mitigation |
|------|------------|
| JSON integer overflow for `elapsed_ns` | Clamp elapsed to `maxInt(i64)` before emit (same pattern as handshake latency). |
| Non-deterministic wall time in compare | Document that `pty_experiment_elapsed_ns` is wall-time; compare may show `changed` between runs. |
| Missing keys on older artifacts | Validator requires PH1-M8 keys only for new harness output; old files are not re-validated retroactively. |

## Telemetry (PH1-M8)

| Field | When non-null | Rule |
|-------|---------------|------|
| `pty_experiment_attempt` | `pty_guarded` always in `run.json` | `null` if `guarded_state` is `scaffold_only`; else integer **`1`** (single attempt). |
| `pty_experiment_elapsed_ns` | same | `null` if scaffold; else non-negative nanoseconds for open→close (or failure path), clamped to signed JSON range. |

## Acceptance checks (Engineer)

- `zig build` / `zig build test` pass on Linux.
- Guarded full run: `transport` keys present in documented order; `report` exits **0**.
- Guarded dry-run / non-Linux preflight behavior unchanged from PH1-M7.
- `docs/SMOKE.md` PH1-M8 section exercised manually or in CI where applicable.
