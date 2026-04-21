# Launch preflight (PH1-M35)

## Objective

Add **deterministic preflight** before the bounded **argv** terminal launch on Linux so **missing binaries** and **non-executable paths** are recorded explicitly in **`run.json`** (and related fingerprints) instead of only appearing indirectly as **`spawn_failed`**.

## In-scope (PH1-M35-S1)

- **Linux only** for the availability probe; other platforms leave preflight fields **`null`** / **`na`** as documented.
- **`argv[0]`** from the resolved PH1-M34 launch argv (after profile / CLI / fallback resolution).
- **Lookup rules**:
  - If **`argv[0]`** contains a **`/`**, treat it as a **relative or absolute path** and test that path for existence and executable bit.
  - Otherwise resolve via **`PATH`** (from the process environment at preflight time): probe each directory in order with **`access(path, X_OK)`** semantics (existence + executable for regular files).
- **Reason taxonomy** (static strings, lowercase snake_case):
  - **`na`** — preflight not applicable (e.g. dry-run scaffold, non-Linux, empty argv, non-**`pty_guarded`** launch path).
  - **`ok`** — resolved target exists and is executable.
  - **`missing_executable`** — no candidate path found or file missing.
  - **`not_executable`** — path exists but is not executable (e.g. directory or missing **`+x`**).

## Artifact fields (root `run.json`)

| Key | Type | Rule |
|-----|------|------|
| `terminal_launch_preflight_ok` | boolean or `null` | **`true`** / **`false`** when preflight ran; **`null`** when **`na`**. |
| `terminal_launch_preflight_reason` | string or `null` | One of the taxonomy values above; **`null`** when not applicable. |
| `terminal_exec_resolved_path` | string or `null` | Filesystem path used for the probe when resolved (may be relative path normalized by the harness); **`null`** when not applicable or unresolved. |

**Serialization**: with other root terminal metadata; **`report`** validation enforces shape and consistency with **`transport`** context.

## Transport fingerprint (PH1-M35)

Canonical transport fingerprint payload gains a **schema revision** (**`transport_fingerprint_version` `2`**) that appends **preflight canonical lines** after existing **`pty_guarded`** launch telemetry lines (see **`docs/TRANSPORT_FINGERPRINT_PLAN.md`** update).

## Pipeline behavior

- Preflight runs **before** **`runBoundedArgvCommand`** when a launch would otherwise be attempted.
- **Fail-closed**: if preflight fails (**`missing_executable`** / **`not_executable`**), the harness **does not** spawn the terminal child; launch telemetry remains unset for that attempt; the CLI exits with **exit code 2** (`invalid_spec`) after writing **`run.json`** so evidence is preserved.

## Risks

- **PATH vs. login shell**: preflight uses the harness process environment only; interactive shells may differ.
- **TOCTOU**: availability at preflight time may differ from spawn time (documented limitation).

## Acceptance checks

- **`zig build`** / **`zig build test`** pass.
- **`report`** rejects inconsistent preflight shapes.
- **`compare`** surfaces preflight fields in metadata deltas when runs differ.
- **`docs/SMOKE.md`** documents a missing-binary check path.

## Non-goals (PH1-M35)

- Full **`execve`** resolution (interpreters, `#!`, **`LD_LIBRARY_PATH`**).
- Non-Linux availability probes in this sprint.
- Changing **`spawn_failed`** semantics for cases preflight did not cover.
