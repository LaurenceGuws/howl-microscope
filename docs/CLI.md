# CLI contract

The `howl-microscope` binary (installed as `howl-microscope` via `zig build`) exposes a text-first control plane. Arguments are parsed after the subcommand name.

## Global behavior

- **Stdout**: primary user-facing output (lists, summaries).
- **Stderr**: diagnostics and errors.
- **Exit codes** (shared):
  - `0`: success.
  - `1`: usage / unknown subcommand / invalid arguments.
  - `2`: invalid spec or validation failure.
  - `3`: I/O or runtime failure (read/write errors, unexpected OS errors).

## Terminal target model (`run`, `run-suite`)

These flags identify **which terminal** is under test and how it would be invoked. PH1-M2 records them in artifacts even when the harness does not yet spawn a real PTY session.

| Flag | Meaning |
|------|---------|
| `--terminal <name>` | Short **logical id** for the terminal under test (e.g. `wezterm`, `alacritty`). Used in `run.json` / `env.json` and compare reports. |
| `--terminal-cmd <string>` | Optional launch string for automation. **PH1-M34** turns this into argv via **simple ASCII whitespace splitting** (see **`docs/TERMINAL_PROFILE_EXEC_TEMPLATE_PLAN.md`**); if splitting cannot fit harness caps, the harness may fall back to a **single argv token** or a **shell** execution path. May contain spaces; pass as a single flag argument. |
| `--platform <name>` | OS tag for the run (e.g. `linux`). Defaults to a sensible native tag when omitted. |

**Rules**

- `--terminal` is the primary key for comparison: two runs with different `--terminal` values are expected to differ in metadata even if specs match.
- **PH1-M33 profile resolution**: when **`--terminal-cmd`** is omitted, the harness resolves a **default launch command** from **`--terminal`** using built-in profile adapters (see **`docs/TERMINAL_PROFILE_ADAPTER_PLAN.md`**). When **`--terminal-cmd`** is set, it **wins** for the effective launch string; `run.json` records source **`cli_override`** vs **`profile`** vs **`fallback`**.
- **PH1-M34 executable templates**: built-in profiles yield a **deterministic argv** and optional **`terminal_exec_template_id`** / **`terminal_exec_template_version`** in **`run.json`** (see **`docs/TERMINAL_PROFILE_EXEC_TEMPLATE_PLAN.md`**). **`resolved_terminal_cmd`** remains a **space-joined** summary of that argv.
- **PH1-M35 launch preflight** (Linux, **`pty_guarded`** bounded argv path): before spawning the terminal child, the harness probes **`argv[0]`** for **PATH** / absolute resolution and executable permission. **`run.json`** records **`terminal_launch_preflight_*`** and **`terminal_exec_resolved_path`** (see **`docs/LAUNCH_PREFLIGHT_PLAN.md`**). If preflight fails (**missing** / **non-executable**), the harness writes artifacts then exits with code **2** (same category as invalid spec) without attempting launch.
- **PH1-M36 preflight strictness**: **`terminal_exec_resolved_path`** is normalized when possible (**`realpath`** → **`terminal_exec_resolved_path_normalization`** **`canonical`** vs **`literal`**), and **`terminal_launch_preflight_ok`** / **`terminal_launch_preflight_reason`** / **`transport`** launch telemetry stay mutually consistent (see **`docs/LAUNCH_PREFLIGHT_STRICTNESS_PLAN.md`**). **`transport_fingerprint_version`** **`3`** includes the normalization line in the canonical transport digest.
- **PH1-M37 launch failure diagnostics envelope**: the harness emits **`terminal_launch_diagnostics_reason`**, **`terminal_launch_diagnostics_elapsed_ms`**, and **`terminal_launch_diagnostics_signal`** fields that normalize failure evidence across preflight, spawn, and launch termination paths. These fields compose spawn/timeout/exit-code telemetry into one actionable diagnostic handle (see **`docs/LAUNCH_FAILURE_ENVELOPE_PLAN.md`** and **`docs/REPORT_FORMAT.md`**). **`transport_fingerprint_version`** **`4`** includes the diagnostics reason line in the canonical transport digest.
- **PH1-M38 launch diagnostics fingerprint**: the harness emits **`terminal_launch_diagnostics_fingerprint_digest`** and **`terminal_launch_diagnostics_fingerprint_version`** fields that compose the launch diagnostics envelope into a deterministic SHA-256 digest for structured comparison of diagnostics changes across runs. The fingerprint is computed from a canonical payload containing **`diagnostics_reason`**, **`elapsed_ms`**, and **`signal`** values (see **`docs/LAUNCH_DIAGNOSTICS_FINGERPRINT_PLAN.md`** and **`docs/REPORT_FORMAT.md`**). Compare output surfaces diagnostics fingerprint deltas alongside envelope field deltas.
- **PH1-M39 launch diagnostics canonicalization**: the harness enforces canonical normalization rules for diagnostics fingerprint inputs to prevent normalization drift across writer, validator, and compare paths. Canonical forms: **`reason`** must be one of `ok`, `missing_executable`, `not_executable`, `spawn_failed`, `timeout`, `nonzero_exit`, `signaled` (lowercase, exact match); **`elapsed_ms`** must be integer in range **`[0, maxInt(u32)]`**; **`signal`** must be integer in range **`[1, 128]`** or null. Invalid values are rejected by schema validation (see **`docs/LAUNCH_DIAGNOSTICS_CANONICALIZATION_PLAN.md`**).
- **PH1-M40 launch diagnostics compatibility envelope**: the harness emits **`terminal_launch_diagnostics_compatible`** (overall state: "compatible"|"warning"|"incompatible") and per-field compatibility flags (**`*_reason_compatible`**, **`*_elapsed_compatible`**, **`*_signal_compatible`**) that track whether diagnostics values conform to canonical forms. Compatibility=compatible when all non-null fields are canonical; compatibility=warning when fields are null (missing data); compatibility=incompatible when values violate canonical constraints (validation would reject). Useful for operators to identify and diagnose non-canonical data in runs (see **`docs/LAUNCH_DIAGNOSTICS_COMPATIBILITY_PLAN.md`**).
- Unknown or missing `--terminal` is recorded as `unknown` in artifacts unless a default is documented per command.

## Execution control flags (`run`, `run-suite`, PH1-M4+)

| Flag | Meaning |
|------|---------|
| `--dry-run` | Boolean flag (no value). Validates specs and runs the planning/execution path in memory, then exits **without** creating a run directory or writing `run.json` / `summary.md` / `env.json`. Exit **0** when planning succeeds. |
| `--strict` | Boolean flag (no value). Enables stricter validation for the invocation (exact rules evolve by milestone; see `docs/PROTO_EXEC_PLAN.md`). |
| `--exec-mode <mode>` | `placeholder` (default) or `protocol_stub` (PH1-M4+). Recorded in `run.json` as `execution_mode`. |

**PH1-M10 host identity (`run.json` root)**

- On full runs (artifacts written), the harness records **`host_identity_machine`**, **`host_identity_release`**, and **`host_identity_sysname`** from runtime **`uname`** (see **`docs/HOST_IDENTITY_PLAN.md`** and **`docs/REPORT_FORMAT.md`**).
- **`--dry-run`** does not write `run.json`; these keys are not applicable.

**PH1-M11 run fingerprint (`run.json` root)**

- Full runs include **`run_fingerprint_digest`** (64-char lowercase hex) and **`run_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/RUN_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; fingerprint keys are not applicable.

**PH1-M12 spec-set fingerprint (`run.json` root)**

- Full runs include **`specset_fingerprint_digest`** (64-char lowercase hex) and **`specset_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/SPECSET_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; spec-set fingerprint keys are not applicable.

**PH1-M13 results-set fingerprint (`run.json` root)**

- Full runs include **`resultset_fingerprint_digest`** (64-char lowercase hex) and **`resultset_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/RESULTSET_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; results-set fingerprint keys are not applicable.

**PH1-M14 transport fingerprint (`run.json` root)**

- Full runs include **`transport_fingerprint_digest`** (64-char lowercase hex) and **`transport_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/TRANSPORT_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; transport fingerprint keys are not applicable.

**PH1-M15 execution-summary fingerprint (`run.json` root)**

- Full runs include **`exec_summary_fingerprint_digest`** (64-char lowercase hex) and **`exec_summary_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/EXEC_SUMMARY_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; execution-summary fingerprint keys are not applicable.

**PH1-M16 context-summary fingerprint (`run.json` root)**

- Full runs include **`context_summary_fingerprint_digest`** (64-char lowercase hex) and **`context_summary_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/CONTEXT_SUMMARY_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; context-summary fingerprint keys are not applicable.

**PH1-M17 metadata-envelope fingerprint (`run.json` root)**

- Full runs include **`metadata_envelope_fingerprint_digest`** (64-char lowercase hex) and **`metadata_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/METADATA_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; metadata-envelope fingerprint keys are not applicable.

**PH1-M18 artifact-bundle fingerprint (`run.json` root)**

- Full runs include **`artifact_bundle_fingerprint_digest`** (64-char lowercase hex) and **`artifact_bundle_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/ARTIFACT_BUNDLE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; artifact-bundle fingerprint keys are not applicable.

**PH1-M19 report-envelope fingerprint (`run.json` root)**

- Full runs include **`report_envelope_fingerprint_digest`** (64-char lowercase hex) and **`report_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/REPORT_ENVELOPE_FINGERPRINT_PLAN.md`**).

**PH1-M20 compare-envelope fingerprint (`run.json` root)**

- Full runs include **`compare_envelope_fingerprint_digest`** (64-char lowercase hex) and **`compare_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/COMPARE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; compare-envelope fingerprint keys are not applicable.

**PH1-M21 run-envelope fingerprint (`run.json` root)**

- Full runs include **`run_envelope_fingerprint_digest`** (64-char lowercase hex) and **`run_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/RUN_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; run-envelope fingerprint keys are not applicable.

**PH1-M22 session-envelope fingerprint (`run.json` root)**

- Full runs include **`session_envelope_fingerprint_digest`** (64-char lowercase hex) and **`session_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/SESSION_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; session-envelope fingerprint keys are not applicable.

**PH1-M23 environment-envelope fingerprint (`run.json` root)**

- Full runs include **`environment_envelope_fingerprint_digest`** (64-char lowercase hex) and **`environment_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/ENVIRONMENT_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; environment-envelope fingerprint keys are not applicable.

**PH1-M24 artifact-manifest fingerprint (`run.json` root)**

- Full runs include **`artifact_manifest_fingerprint_digest`** (64-char lowercase hex) and **`artifact_manifest_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/ARTIFACT_MANIFEST_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; artifact-manifest fingerprint keys are not applicable.

**PH1-M25 provenance-envelope fingerprint (`run.json` root)**

- Full runs include **`provenance_envelope_fingerprint_digest`** (64-char lowercase hex) and **`provenance_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/PROVENANCE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; provenance-envelope fingerprint keys are not applicable.

**PH1-M26 integrity-envelope fingerprint (`run.json` root)**

- Full runs include **`integrity_envelope_fingerprint_digest`** (64-char lowercase hex) and **`integrity_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/INTEGRITY_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; integrity-envelope fingerprint keys are not applicable.

**PH1-M27 consistency-envelope fingerprint (`run.json` root)**

- Full runs include **`consistency_envelope_fingerprint_digest`** (64-char lowercase hex) and **`consistency_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/CONSISTENCY_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; consistency-envelope fingerprint keys are not applicable.

**PH1-M28 trace-envelope fingerprint (`run.json` root)**

- Full runs include **`trace_envelope_fingerprint_digest`** (64-char lowercase hex) and **`trace_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/TRACE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; trace-envelope fingerprint keys are not applicable.

**PH1-M29 lineage-envelope fingerprint (`run.json` root)**

- Full runs include **`lineage_envelope_fingerprint_digest`** (64-char lowercase hex) and **`lineage_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/LINEAGE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; lineage-envelope fingerprint keys are not applicable.

**PH1-M30 state-envelope fingerprint (`run.json` root)**

- Full runs include **`state_envelope_fingerprint_digest`** (64-char lowercase hex) and **`state_envelope_fingerprint_version`** (**`1`**) derived from a documented canonical payload (see **`docs/STATE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`--dry-run`** does not write `run.json`; state-envelope fingerprint keys are not applicable.

## Transport configuration (`run`, `run-suite`, PH1-M5+)

These flags describe the **transport seam** (how the harness would attach to a terminal for I/O). They complement **`--terminal`**, which names the *logical* terminal identity for comparison metadata.

| Flag | Meaning |
|------|---------|
| `--transport <mode>` | `none` (default): transport metadata reflects **no** stub handshake. `pty_stub`: emit deterministic **stub** handshake and synthetic latency in `run.json` under `transport` (still **no** real PTY; see `docs/TRANSPORT_PLAN.md`). `pty_guarded`: guarded transport (PH1-M6+): deterministic handshake/latency plus optional **Linux PTY experiment** (PH1-M7+); see `docs/REAL_TRANSPORT_GUARD_PLAN.md` and `docs/PTY_EXPERIMENT_PLAN.md`. |
| `--allow-guarded-transport` | Boolean flag (no value). **Required** (or env below) when `--transport pty_guarded` is set; otherwise the run fails closed before artifacts. |
| `--timeout-ms <n>` | Positive integer: deadline budget in milliseconds, stored as `transport.timeout_ms`. PH1-M5 records the value; wall-clock enforcement is deferred. |

**Environment (guarded transport)**

- `ANA_TERM_ALLOW_GUARDED_TRANSPORT=1` — satisfies the guarded-transport opt-in gate when set exactly to `1`, same as passing `--allow-guarded-transport`.

**`transport.guarded_state` promotion (PH1-M7+)**

Recorded under `transport` in `run.json` (see `docs/REPORT_FORMAT.md`):

| Value | When |
|-------|------|
| `na` | `none` or `pty_stub`. |
| `scaffold_only` | `pty_guarded` with **`--dry-run`**, or before a real PTY experiment runs. |
| `experiment_linux_pty` | `pty_guarded`, not dry-run, on a **Linux host** (per `uname`), after the minimal PTY open/close attempt. |

On **non-Linux** hosts, `pty_guarded` (non-dry-run) fails with exit **2** before writing artifacts. Opt-in rules are unchanged.

**PH1-M8 telemetry (`transport` in `run.json`)**

- **`pty_experiment_attempt`**: `null` for `scaffold_only`; **`1`** after a full Linux experiment run.
- **`pty_experiment_elapsed_ns`**: `null` for `scaffold_only`; non-negative nanoseconds (wall time) for the guarded PTY block on `experiment_linux_pty`, clamped for JSON integers.
- Invariants and risks: **`docs/PTY_EXPERIMENT_HARDENING_PLAN.md`** and **`docs/REPORT_FORMAT.md`**.

**PH1-M9 reproducibility (`transport` in `run.json`)**

- **`pty_experiment_host_machine`**, **`pty_experiment_host_release`**: `null` for `scaffold_only`; on `experiment_linux_pty`, non-empty snapshots from `uname` (truncated to harness buffers). See **`docs/PTY_REPRODUCIBILITY_PLAN.md`**.

**PH1-M31 real terminal launch (`transport` in `run.json`)**

- **When**: `pty_guarded`, not **`--dry-run`**, Linux host, **`guarded_state == experiment_linux_pty`**, and the **resolved** launch argv is non-empty (after **PH1-M33**/**PH1-M34** resolution; **`--terminal-cmd`** overrides profile/fallback). The harness runs the **resolved argv** directly when formed (**PH1-M34**); otherwise **`/bin/sh -c <resolved_terminal_cmd>`** (legacy string path), with wall-clock budget **`transport.timeout_ms`** (poll **`waitpid`**, **`SIGKILL`** on timeout); see **`docs/REAL_TERMINAL_LAUNCH_PLAN.md`**, **`docs/TERMINAL_PROFILE_ADAPTER_PLAN.md`**, and **`docs/TERMINAL_PROFILE_EXEC_TEMPLATE_PLAN.md`**.
- **Fail-closed**: a guarded **full** run on Linux **requires** a non-empty **resolved** command (from **`--terminal-cmd`**, a built-in profile, or **`--terminal`** fallback); otherwise the run exits before writing artifacts with a clear stderr message.
- **Telemetry**: **`terminal_launch_*`** fields under **`transport`** (attempt, elapsed ns, exit code, ok flag, short error tag, **PH1-M32** outcome class). Full contract: **`docs/REPORT_FORMAT.md`**.
- **PH1-M32 outcome class**: **`terminal_launch_outcome`** is one of **`ok`**, **`nonzero_exit`**, **`signaled`**, **`timeout`**, **`spawn_failed`** when a launch was attempted; it must agree with **`terminal_launch_ok`**, **`terminal_launch_error`**, and **`terminal_launch_exit_code`** per **`docs/TERMINAL_LAUNCH_SEMANTICS_PLAN.md`**.

## `list`

**Purpose**: Enumerate discovered `.toml` probe specs.

| Input | Description |
|-------|-------------|
| Positional paths | Optional directories or files to scan (default: `probes/`). |

| Output | Description |
|--------|-------------|
| Stdout | One path per line, sorted lexicographically. |

| Exit | Condition |
|------|-----------|
| 0 | Discovery completed (empty list is success). |
| 3 | Directory unreadable or I/O error. |

## `run`

**Purpose**: Run one or more specs through the phase-1 pipeline and write artifacts.

| Input | Description |
|-------|-------------|
| Path | Directory (e.g. `probes/smoke`) or single `.toml` file. |
| `--terminal <name>` | Optional; logical terminal id (see **Terminal target model**). |
| `--terminal-cmd <string>` | Optional in general; on **Linux** **`pty_guarded`** full runs, either this flag **or** a **PH1-M33** profile / fallback must yield a non-empty resolved command (see **Terminal target model**). |
| `--platform <name>` | Optional; OS tag recorded in artifacts. |
| `--capture <mode>` | Optional; one of `manual`, `text_observation`, `timed`. |
| `--dry-run` | Optional; validate and simulate without writing artifacts (PH1-M4+). |
| `--strict` | Optional; stricter validation where implemented (PH1-M4+). |
| `--exec-mode <mode>` | Optional; `placeholder` or `protocol_stub` (PH1-M4+). |
| `--transport <mode>` | Optional; `none`, `pty_stub`, or `pty_guarded` (PH1-M5+ / PH1-M6+). |
| `--allow-guarded-transport` | Optional; required for `pty_guarded` unless env opt-in is set (PH1-M6+). |
| `--timeout-ms <n>` | Optional; positive integer milliseconds (PH1-M5+). |

| Output | Description |
|--------|-------------|
| Artifact dir | `artifacts/YYYY-MM-DD/run-XXX/` with `run.json`, `summary.md`. |

| Exit | Condition |
|------|-----------|
| 0 | Run record written. |
| 2 | Spec missing required keys or validation failed. |
| 3 | Failed to create artifact directory or write files. |

## `run-suite`

**Purpose**: Run a named suite (future: maps to a list of specs or directories).

| Input | Description |
|-------|-------------|
| Suite name | Required identifier (phase-1 may stub with placeholder). |
| Optional flags | Same as **`run`** where applicable (`--capture`, `--terminal`, `--exec-mode`, `--transport`, `--allow-guarded-transport`, `--timeout-ms`, `--dry-run`, …). |

| Exit | Condition |
|------|-----------|
| 0 | Stub success or suite executed. |
| 1 | Unknown suite name in phase-1 stub. |

## `report`

**Purpose**: Render or validate a `run.json` and optionally refresh `summary.md`.

| Input | Description |
|-------|-------------|
| Path | Path to `run.json` or to a run directory containing it. |

| Output | Description |
|--------|-------------|
| Stdout | Short confirmation or validation message. |

| Exit | Condition |
|------|-----------|
| 0 | JSON valid and report step completed. |
| 2 | JSON invalid or missing required fields. |
| 3 | Read/write failure. |

## `doctor`

**Purpose**: Print environment and build diagnostics (Zig version, cwd, basic paths).

| Output | Description |
|--------|-------------|
| Stdout | Key-value or line-oriented diagnostic lines. |

| Exit | Condition |
|------|-----------|
| 0 | Always in phase-1 (informational). |
