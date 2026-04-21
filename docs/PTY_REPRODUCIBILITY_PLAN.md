# PTY reproducibility plan (PH1-M9)

PH1-M9 improves **auditability** of the Linux guarded PTY experiment by recording a small, stable **host snapshot** alongside existing attempt/elapsed/error telemetry—without changing opt-in, preflight, or the open/close sequence from PH1-M7/PH1-M8.

## Boundaries

- **In scope**: `uname`-derived **`release`** and **`machine`** strings in `run.json` → `transport` (only for `pty_guarded` rows); schema + compare coverage; tests and smoke updates.
- **Out of scope**: full kernel config dumps, `/proc` scraping, libc versions, ConPTY, screenshots, child processes, PTY I/O.

## Risks

| Risk | Mitigation |
|------|------------|
| Long `uname.release` strings | Truncate to a fixed buffer (256 bytes) when copying; validator requires non-empty string after truncation (still useful for audit). |
| PII in `machine` | Field is the usual `uname.machine` (e.g. `x86_64`); document in `REPORT_FORMAT.md`. |
| Compare noise across kernels | **`pty_experiment_host_release`** is expected to **differ** between hosts or kernel upgrades; compare marks **`changed`**—this is intentional for reproducibility diffs. |

## Fields (PH1-M9)

| JSON key | When `null` | When set |
|----------|-------------|----------|
| `pty_experiment_host_machine` | `guarded_state` is `scaffold_only` | Non-empty string from `uname.machine` on experiment path. |
| `pty_experiment_host_release` | same | Non-empty string from `uname.release` (truncated if needed). |

Lexicographic order in `transport` inserts these keys **after** `pty_experiment_error` and **before** `pty_experiment_open_ok`.

## Acceptance checks

- `zig build` / `zig build test` pass on Linux.
- Full guarded run: both host fields present and non-empty; `report` **0**.
- Scaffold-only JSON fixtures: both fields **`null`**.
- Failure path: host snapshot still present (captured before PTY failure is irrelevant—we capture at start of experiment block so failure runs still get the same host context).
