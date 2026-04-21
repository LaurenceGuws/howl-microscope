# Launch preflight strictness (PH1-M36)

## Objective

Tighten **PH1-M35** preflight so **reason tags**, **resolved path strings**, and **terminal launch telemetry** cannot drift into inconsistent combinations, and so **`terminal_exec_resolved_path`** uses a **deterministic normalization policy** on Linux (canonical absolute path when resolvable).

## Boundaries (PH1-M36-S1)

- **Linux** guarded argv probe path only for normalization; other platforms leave normalization **`null`** (same as no path).
- **No change** to which probe outcomes exist (`na`, `ok`, `missing_executable`, `not_executable`) — only **fidelity rules** between fields and **path canonicalization** after a successful probe.
- **Transport fingerprint** gains a new schema revision (**`3`**) that appends one canonical line for path normalization on **`pty_guarded`** payloads (see **`docs/TRANSPORT_FINGERPRINT_PLAN.md`**).

## Path normalization

After **`argv[0]`** resolves to an existing regular executable file, the harness attempts **`realpath(3)`** semantics (via `std.posix.realpath`) on that path string:

| `terminal_exec_resolved_path_normalization` | When |
|---------------------------------------------|------|
| **`canonical`** | **`realpath`** succeeded; **`terminal_exec_resolved_path`** is the absolute canonical path. |
| **`literal`** | Probe succeeded but **`realpath`** failed or was not applied; stored path is the literal probe path (may be relative). |
| **`null`** | No resolved path is emitted (**`terminal_exec_resolved_path`** is **`null`**). |

**Serialization**: root field **`terminal_exec_resolved_path_normalization`** — string or **`null`**, immediately after **`terminal_exec_resolved_path`** (lexicographic among terminal preflight keys).

## Reason fidelity (root + `transport`)

These rules apply when the harness emits a full artifact run (**not** `--dry-run`).

1. **`terminal_launch_preflight_ok`** and **`terminal_launch_preflight_reason`**:
   - If **`ok`** is **`true`**, **`reason`** MUST be **`ok`**.
   - If **`ok`** is **`false`**, **`reason`** MUST be **`missing_executable`** or **`not_executable`** (never **`ok`**).
   - If **`ok`** is **`null`**, **`reason`** MUST be **`null`** or **`na`**.
2. **Preflight failure (blocked launch)** — when **`reason`** is **`missing_executable`** or **`not_executable`** on a path where preflight ran for guarded launch:
   - **`transport.terminal_launch_attempt`** MUST be **`null`** (no spawn).
   - All sibling launch telemetry fields that are **`null`** when attempt is **`null`** MUST remain **`null`** (existing transport validator rules).
3. **Preflight success** — when **`ok`** is **`true`** and **`reason`** is **`ok`** on Linux **`pty_guarded`** with non-empty argv and **`experiment_linux_pty`**:
   - The harness MUST record a launch attempt (**`transport.terminal_launch_attempt`** **`1`**) or document a single controlled omission (phase-1: attempt is **`1`** after successful spawn path).

## Pipeline

On Linux **`pty_guarded`** with resolved argv, if the probe returns **`!ok`** for **any** reason, the run is **fail-closed** (exit **2** after artifacts) — same as PH1-M35 for missing / not executable; **`na`** remains unreachable on this branch for Linux + non-empty argv.

## Artifact and report validation

- **`report`** rejects JSON that violates the mutual constraints in **Reason fidelity** or unknown **`terminal_exec_resolved_path_normalization`** values.
- **`compare`** includes **`terminal_exec_resolved_path_normalization`** in metadata deltas.

## Acceptance checks

- **`zig build`** / **`zig build test`** pass.
- **`docs/SMOKE.md`** references path normalization and fidelity checks.
- **`transport_fingerprint_version`** **`3`** for new harness output; **`1`** / **`2`** remain valid for legacy fixtures where applicable.

## Non-goals (PH1-M36)

- Changing **`spawn_failed`** root cause analysis beyond consistency with preflight.
- Non-Linux **`realpath`** policy in this sprint.
