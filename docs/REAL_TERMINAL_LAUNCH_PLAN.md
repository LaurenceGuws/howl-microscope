# Real terminal launch (PH1-M31)

## Objective

Add a **bounded, deterministic process launch** of the operator-provided **`--terminal-cmd`** string on the **guarded Linux full-run** path so `run.json` records **process-level evidence** (attempt, elapsed time, exit status, short error tag) without changing the text-first artifact contract or requiring a full VT data plane.

## Boundaries

- **In scope**: documented launch model; `RunContext` telemetry; `/bin/sh -c` execution with **`transport.timeout_ms`** as the wall-clock budget; stable JSON under **`transport.*`**; `report` + `compare` coverage.
- **Out of scope**: attaching I/O to the spawned terminal; scraping window titles; screenshot/OCR; Windows/macOS launch (Linux-only guarded lane).

## Launch model (phase 1)

1. **When**: `transport.mode == pty_guarded`, non-**dry-run**, Linux host, **`guarded_state == experiment_linux_pty`**, and **`--terminal-cmd` is non-empty** (after the minimal PTY open/close experiment block).
2. **How**: spawn `"/bin/sh", "-c", <terminal_cmd>` with stdin/stdout/stderr ignored; poll **`waitpid(WNOHANG)`** until exit or until **`transport.timeout_ms`** elapses; on timeout send **`SIGKILL`** and reap.
3. **Mapping**:
   - **Spawn failure** → `terminal_launch_error` set to a short static tag (e.g. `spawn_failed`); exit code null; `terminal_launch_ok` false.
   - **Timeout** → `terminal_launch_error` = `timeout`; `terminal_launch_exit_code` null (or `-1` if we need a number—prefer null in JSON for unknown).
   - **Clean exit** → record `WEXITSTATUS`; `terminal_launch_ok` true iff status == 0.

## Field contract (`transport` object)

| Key | Type | Rule |
|-----|------|------|
| `terminal_launch_attempt` | integer or `null` | **`1`** when a launch was attempted; **`null`** when not applicable (scaffold, non-Linux, non-guarded, empty cmd). |
| `terminal_launch_elapsed_ns` | integer or `null` | Wall time for the launch attempt (nanoseconds, clamped to signed JSON range). |
| `terminal_launch_exit_code` | integer or `null` | Child exit code when reaped normally; **`null`** on spawn failure or timeout before status. |
| `terminal_launch_ok` | boolean or `null` | **`true`** / **`false`** when a launch ran to completion; **`null`** when no attempt. |
| `terminal_launch_error` | string or `null` | Short static reason (`timeout`, `spawn_failed`, …) or **`null`**. |

**Serialization order** (lexicographic among harness keys): after **`pty_experiment_open_ok`**, before **`timeout_ms`**: `terminal_launch_attempt`, `terminal_launch_elapsed_ns`, `terminal_launch_error`, `terminal_launch_exit_code`, `terminal_launch_ok`.

## Fail-closed prerequisite

A **guarded full run on Linux** (`pty_guarded`, not dry-run) **requires** **`--terminal-cmd`** so the launch lane can run. If it is missing, the harness **fails before writing artifacts** with a clear stderr message.

## Risks

- **User commands**: arbitrary shell; bounded only by timeout—document that operators should pass non-interactive or short-lived probes.
- **Determinism**: host shell and `PATH` affect behavior; fingerprints upstream already capture identity; launch records are operational evidence, not a cross-host identity digest.

## Acceptance checks

- `zig build` / `zig build test` pass on Linux.
- With prerequisites satisfied, `run.json` includes consistent `terminal_launch_*` fields and `report` validates.
- `compare` surfaces `terminal_launch_*` in metadata deltas when values differ.
