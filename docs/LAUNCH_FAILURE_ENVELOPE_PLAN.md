# Launch failure diagnostics envelope (PH1-M37)

## Objective

Add deterministic **launch failure diagnostics envelope** fields so guarded runs provide **actionable, normalized failure evidence** across artifacts, report validation, and compare outputs — capturing failures from **preflight**, **spawn**, and **launch termination** in one consistent shape.

## Boundaries (PH1-M37-S1)

- **Scope**: Linux **`pty_guarded`** with bounded argv only; other modes/platforms yield **`null`** diagnostics envelope.
- **Failure taxonomy**: three failure stages — **preflight** (`missing_executable`, `not_executable`), **spawn** (`spawn_failed`), **launch termination** (`timeout`, `nonzero_exit`, `signaled`).
- **Envelope shape**: normalized reason, elapsed time, and optional exit signal for downstream diagnostics.
- **Transport fingerprint**: new schema revision includes diagnostics envelope canonical line on guarded payloads.
- **No change** to existing `terminal_launch_preflight_*`, `terminal_launch_*` outcome, or exit_code fields — diagnostics envelope **composes** them into one diagnostic handle.

## Failure stages and reason taxonomy

Guarded launch can fail at three distinct points:

### Stage 1: Preflight (`terminal_launch_preflight_*`)

- **`missing_executable`**: argv[0] resolved against PATH/cwd but file not found.
- **`not_executable`**: file exists but is not a regular executable file.
- **outcome**: preflight failure → harness **does not spawn**, writes artifacts, exits code **2**.

### Stage 2: Spawn (`terminal_launch_err` + `terminal_launch_outcome`)

- **`spawn_failed`**: fork/exec system call failed or process failed to spawn.
- **outcome**: spawn failure → `terminal_launch_attempt=1`, `err="spawn_failed"`, `outcome="spawn_failed"`.

### Stage 3: Launch termination (`terminal_launch_outcome` + `terminal_launch_exit_code`)

- **`timeout`**: process launched but exceeded bounded timeout before exit.
- **`nonzero_exit`**: process exited with code != 0.
- **`signaled`**: process terminated by signal (SIGTERM, SIGKILL, etc.).
- **`ok`**: process exited successfully (code 0).

## Diagnostics envelope fields

All fields present in `run.json` root when artifacts are written (not `--dry-run`), regardless of success/failure path.

### New fields (PH1-M37)

| Field | Type | Description |
|-------|------|-------------|
| `terminal_launch_diagnostics_reason` | string or `null` | Normalized failure reason: **`ok`**, **`missing_executable`**, **`not_executable`**, **`spawn_failed`**, **`timeout`**, **`nonzero_exit`**, **`signaled`**, or **`null`** when not applicable (non-Linux, non-guarded, or dry-run). Deterministic single-point summary across all failure stages. |
| `terminal_launch_diagnostics_elapsed_ms` | number or `null` | Wall-time milliseconds from launch attempt start to final outcome (success or termination). Clamped to **`maxInt(i64)`** for JSON. **`null`** when not applicable. |
| `terminal_launch_diagnostics_signal` | number or `null` | Signal number when outcome is **`signaled`** (e.g. **`9`** for SIGKILL); **`null`** otherwise. Present only when process was killed by signal. |

### Serialization order

After `terminal_launch_preflight_reason`, before `host_identity_machine`:

1. `terminal_launch_diagnostics_reason`
2. `terminal_launch_diagnostics_elapsed_ms`
3. `terminal_launch_diagnostics_signal`

(Lexicographic within terminal launch keys.)

## Mapping failure stages to diagnostics envelope

| Preflight | Spawn | Termination | `diagnostics_reason` | `diagnostics_elapsed_ms` | `diagnostics_signal` | `transport.terminal_launch_attempt` |
|-----------|-------|-------------|----------------------|--------------------------|----------------------|-------------------------------------|
| **missing** / **not** | — | — | `missing_executable` / `not_executable` | **`0`** | **`null`** | **`null`** (no spawn attempt) |
| **ok** | **failed** | — | `spawn_failed` | **`0`** | **`null`** | **`1`** |
| **ok** | **ok** | **timeout** | `timeout` | **timeout_ms** | **`null`** | **`1`** |
| **ok** | **ok** | **exit 0** | `ok` | **actual_elapsed_ms** | **`null`** | **`1`** |
| **ok** | **ok** | **exit ≠0** | `nonzero_exit` | **actual_elapsed_ms** | **`null`** | **`1`** |
| **ok** | **ok** | **signaled** | `signaled` | **actual_elapsed_ms** | **signal_number** | **`1`** |

## Invariants (report + compare validation)

1. **Preflight block**: if `terminal_launch_preflight_reason` is **`missing_executable`** or **`not_executable`**:
   - `terminal_launch_diagnostics_reason` **MUST** be the same reason string.
   - `terminal_launch_attempt` **MUST** be **`null`** (no spawn).
   - `terminal_launch_diagnostics_elapsed_ms` **MUST** be **`0`**.
   - `terminal_launch_diagnostics_signal` **MUST** be **`null`**.

2. **Spawn block**: if `terminal_launch_diagnostics_reason` is **`spawn_failed`**:
   - `terminal_launch_outcome` **MUST** be **`spawn_failed`**.
   - `terminal_launch_attempt` **MUST** be **`1`**.
   - `terminal_launch_diagnostics_elapsed_ms` **MUST** be **`0`**.
   - `terminal_launch_diagnostics_signal` **MUST** be **`null`**.

3. **Termination alignment**:
   - If `terminal_launch_diagnostics_reason` is **`timeout`**, `terminal_launch_outcome` **MUST** be **`timeout`**.
   - If `terminal_launch_diagnostics_reason` is **`nonzero_exit`**, `terminal_launch_outcome` **MUST** be **`nonzero_exit`** AND `terminal_launch_exit_code` **MUST** be non-zero.
   - If `terminal_launch_diagnostics_reason` is **`signaled`**, `terminal_launch_outcome` **MUST** be **`signaled`** AND `terminal_launch_diagnostics_signal` **MUST** be non-null and match signal logic.
   - If `terminal_launch_diagnostics_reason` is **`ok`**, `terminal_launch_outcome` **MUST** be **`ok`** AND `terminal_launch_exit_code` **MUST** be **`0`**.

4. **Diagnostics signal cardinality**:
   - `terminal_launch_diagnostics_signal` is **non-null** **if and only if** `terminal_launch_diagnostics_reason` is **`signaled`**.

## Pipeline changes

1. **RunContext** gains three new optional fields (PH1-M37):
   - `terminal_launch_diagnostics_reason_buf`, `terminal_launch_diagnostics_reason_len`
   - `terminal_launch_diagnostics_elapsed_ms` (u32 or null)
   - `terminal_launch_diagnostics_signal` (u32 or null)

2. **Launch path** (before `run_json_writer`):
   - After preflight: if blocked, set `diagnostics_reason` and `diagnostics_elapsed_ms = 0`.
   - After spawn: if failed, set `diagnostics_reason = spawn_failed`, `diagnostics_elapsed_ms = 0`.
   - After termination: capture actual elapsed time, outcome, exit code, and signal; derive `diagnostics_reason` from outcome.

3. **Transport fingerprint** v4 (PH1-M37): append one canonical line for **`terminal_launch_diagnostics_reason`** when present on guarded runs (similar to v3 preflight normalization line).

4. **Report validator** (PH1-M37): enforce all invariants above; reject JSON with inconsistent state.

5. **Compare** (PH1-M37): include diagnostics reason and signal in metadata rows for diff output.

## Artifact and report validation

- **`report`** rejects JSON that violates any invariant in **Invariants (report + compare validation)** or contains unknown **`terminal_launch_diagnostics_reason`** values.
- **`compare`** includes **`terminal_launch_diagnostics_reason`** and **`terminal_launch_diagnostics_signal`** in metadata deltas.

## Acceptance checks

- **`zig build`** / **`zig build test`** pass with new diagnostics envelope model.
- **`docs/SMOKE.md`** references diagnostics envelope checks for missing-binary, non-executable, spawn-fail, timeout, and exit-code paths.
- **`transport_fingerprint_version`** **`4`** for new harness output; **`1`**–**`3`** remain valid for legacy fixtures.
- `run.json` schema version remains **`1.0`** (additive fields).
- All existing compare/report fixtures pass with new envelope fields populated.

## Non-goals (PH1-M37)

- Changing preflight reason taxonomy beyond classification into the envelope.
- Per-signal diagnostics (e.g. SIGTERM vs SIGKILL details beyond signal number).
- Windows ConPTY diagnostics envelope; non-Linux has **`null`** envelope.
- Screenshot/OCR failure capture.
- Rich TUI failure reporting.
