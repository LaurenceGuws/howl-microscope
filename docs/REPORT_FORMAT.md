# Run artifacts and report format

Every run emits machine-readable and human-readable outputs under the artifact root (see `src/report/artifact_paths.zig` for path policy).

## Artifact directory layout

```text
artifacts/
  YYYY-MM-DD/
    run-XXX/
      run.json
      summary.md
      transcript.log   (optional, phase-1 may omit)
      env.json         (optional)
```

`run-XXX` is a zero-padded sequence per day. The harness must not collide with existing run directories for the same date.

## `run.json` (required)

Top-level JSON object with at least:

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | string | Format version for tooling. |
| `run_id` | string | Unique id for this run directory. |
| `started_at` | string | RFC3339 / ISO8601 timestamp. |
| `ended_at` | string | RFC3339 / ISO8601 timestamp. |
| `platform` | string | OS identifier (e.g. `linux`). |
| `terminal` | object | Identity: `name`, optional `version`. |
| `term` | string | Value of `TERM` if known. |
| `results` | array | One entry per probe/spec executed. |

**PH1-M10+ (root host identity)** — present on every harness `run.json` that writes artifacts (full run, not `--dry-run`):

| Field | Type | Description |
|-------|------|-------------|
| `host_identity_machine` | string | Non-empty `uname.machine` snapshot (truncated; JSON-escaped). |
| `host_identity_release` | string | Non-empty `uname.release` snapshot (truncated; JSON-escaped). |
| `host_identity_sysname` | string | Non-empty `uname.sysname` snapshot (truncated; JSON-escaped). |

**PH1-M33 (terminal profile metadata)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `terminal_profile_id` | string or `null` | Canonical adapter id when **`--terminal`** matches a built-in profile (e.g. `kitty`); **`null`** when unknown or not applicable. |
| `terminal_cmd_source` | string | One of: **`cli_override`** (non-empty **`--terminal-cmd`**), **`profile`** (adapter template), **`fallback`** (effective command is the **`--terminal`** string). |
| `resolved_terminal_cmd` | string | Effective launch summary: **space-joined** argv used for bounded launch / context fingerprint (JSON-escaped); backward-compatible with PH1-M33 string consumers. |

**PH1-M34 (executable profile templates)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `resolved_terminal_argv` | array of strings | argv passed to the bounded launcher (direct exec path) or materialized from resolution; JSON array of non-empty segments after splitting rules. |
| `terminal_exec_template_id` | string or `null` | Stable id when a built-in **executable template** applied (e.g. `kitty_exec_v1`); **`null`** for CLI split-only or fallback-only launches without a named template. |
| `terminal_exec_template_version` | string | Template table revision; phase-1 value **`1`** when **`terminal_exec_template_id`** is non-null. |

**PH1-M35 (launch preflight evidence)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `terminal_exec_resolved_path` | string or `null` | Path string used for the **`argv[0]`** probe when applicable (truncated/bounded); **`null`** when not applicable or unresolved. |
| `terminal_launch_preflight_ok` | boolean or `null` | **`true`** / **`false`** when a Linux preflight probe ran for the bounded argv launch; **`null`** when not applicable. |
| `terminal_launch_preflight_reason` | string or `null` | Static tag: **`na`**, **`ok`**, **`missing_executable`**, **`not_executable`** (see **`docs/LAUNCH_PREFLIGHT_PLAN.md`**); **`null`** when not applicable. |

**PH1-M36 (preflight strictness)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `terminal_exec_resolved_path_normalization` | string or `null` | **`canonical`** (**`realpath`** succeeded), **`literal`** (probe path retained), or **`null`** when **`terminal_exec_resolved_path`** is **`null`**. See **`docs/LAUNCH_PREFLIGHT_STRICTNESS_PLAN.md`**. |

**Serialization order**: after `execution_mode`, before `host_identity_machine`: `terminal_profile_id`, `terminal_cmd_source`, `resolved_terminal_cmd`, **`resolved_terminal_argv`**, **`terminal_exec_template_id`**, **`terminal_exec_template_version`**, **`terminal_exec_resolved_path`**, **`terminal_exec_resolved_path_normalization`**, **`terminal_launch_preflight_ok`**, **`terminal_launch_preflight_reason`**, then **`terminal_launch_diagnostics_*`** (PH1-M37), then `host_identity_machine`, `host_identity_release`, `host_identity_sysname` (lexicographic among the host triple). See **`docs/HOST_IDENTITY_PLAN.md`**, **`docs/TERMINAL_PROFILE_ADAPTER_PLAN.md`**, **`docs/TERMINAL_PROFILE_EXEC_TEMPLATE_PLAN.md`**, **`docs/LAUNCH_PREFLIGHT_PLAN.md`**, **`docs/LAUNCH_PREFLIGHT_STRICTNESS_PLAN.md`**, and **`docs/LAUNCH_FAILURE_ENVELOPE_PLAN.md`**.

**PH1-M37 (launch failure diagnostics envelope)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `terminal_launch_diagnostics_reason` | string or `null` | Normalized failure reason: **`ok`**, **`missing_executable`**, **`not_executable`**, **`spawn_failed`**, **`timeout`**, **`nonzero_exit`**, **`signaled`**, or **`null`** when not applicable (non-Linux, non-`pty_guarded`, or dry-run). See **`docs/LAUNCH_FAILURE_ENVELOPE_PLAN.md`**. |
| `terminal_launch_diagnostics_elapsed_ms` | number or `null` | Wall-time milliseconds from launch attempt start to final outcome (success or termination); clamped to **`maxInt(i64)`** for JSON. **`null`** when not applicable. |
| `terminal_launch_diagnostics_signal` | number or `null` | Signal number when outcome is **`signaled`** (e.g. **`9`** for SIGKILL); **`null`** otherwise. |

**Serialization order**: after `terminal_launch_preflight_reason`, before `host_identity_machine`: **`terminal_launch_diagnostics_reason`**, **`terminal_launch_diagnostics_elapsed_ms`**, **`terminal_launch_diagnostics_signal`** (lexicographic within terminal launch keys).

**PH1-M38 (launch diagnostics fingerprint)** — present on every harness `run.json` that writes artifacts and contains launch diagnostics envelope data:

| Field | Type | Description |
|-------|------|-------------|
| `terminal_launch_diagnostics_fingerprint_digest` | string or `null` | **64**-character lowercase hex SHA-256 of the canonical launch diagnostics fingerprint payload (see **`docs/LAUNCH_DIAGNOSTICS_FINGERPRINT_PLAN.md`**). Composed from **`terminal_launch_diagnostics_reason`**, **`elapsed_ms`**, and **`signal`** values. **`null`** when diagnostics envelope is not applicable (non-Linux, non-`pty_guarded`, or dry-run). |
| `terminal_launch_diagnostics_fingerprint_version` | string or `null` | Fingerprint schema revision; PH1-M38 value **`1`**. **`null`** when diagnostics fingerprint is absent. |

**Serialization order**: after `terminal_launch_diagnostics_signal`, before `run_fingerprint_digest`: **`terminal_launch_diagnostics_fingerprint_digest`**, **`terminal_launch_diagnostics_fingerprint_version`** (lexicographic).

**PH1-M39 (launch diagnostics canonicalization)** — hardening milestone that enforces canonical normalization for diagnostics fingerprint inputs:
- **`terminal_launch_diagnostics_reason`**: must be one of **`ok`**, **`missing_executable`**, **`not_executable`**, **`spawn_failed`**, **`timeout`**, **`nonzero_exit`**, **`signaled`** (lowercase, exact match) or **`null`**. Empty strings and misspelled tags are rejected by schema validation.
- **`terminal_launch_diagnostics_elapsed_ms`**: must be non-negative integer in range **`[0, maxInt(u32)]`** or **`null`**. Negative numbers and floating-point values are rejected by validation.
- **`terminal_launch_diagnostics_signal`**: must be integer in range **`[1, 128]`** (POSIX signal numbers) or **`null`**. Zero, negative numbers, and out-of-range values are rejected by validation.
- Fingerprint digest stability guarantee: identical diagnostics values (after validation) always produce identical fingerprints; different validated values always produce different fingerprints (see **`docs/LAUNCH_DIAGNOSTICS_CANONICALIZATION_PLAN.md`**).

**PH1-M40 (launch diagnostics compatibility envelope)** — compatibility tracking for diagnostics canonical conformance:

| Field | Type | Description |
|-------|------|-------------|
| `terminal_launch_diagnostics_compatible` | string | Overall compatibility status: **`compatible`** (all non-null fields are canonical), **`warning`** (at least one field is null/missing), **`incompatible`** (at least one field violates canonical rules). |
| `terminal_launch_diagnostics_reason_compatible` | boolean | **`true`** if reason is null or canonical tag (one of 7 valid tags); **`false`** if reason is non-canonical (empty string, uppercase, misspelled, etc.). |
| `terminal_launch_diagnostics_elapsed_compatible` | boolean | **`true`** if elapsed_ms is null or canonical integer **`[0, maxInt(u32)]`**; **`false`** if negative, float, or out-of-range. |
| `terminal_launch_diagnostics_signal_compatible` | boolean | **`true`** if signal is null or canonical integer **`[1, 128]`**; **`false`** if zero, negative, >128, or float. |

**Serialization order**: after `terminal_launch_diagnostics_fingerprint_version`, before next milestone fields: `terminal_launch_diagnostics_compatible`, then per-field flags (lexicographic).

**Cross-field invariants**:
- If `compatible="compatible"`, all three per-field flags must be **`true`**.
- If `compatible="warning"`, at least one field is null (per-field flag may be **`false`** for missing data).
- If `compatible="incompatible"`, at least one field violates canonical rules (per-field flag is **`false`**).
- Null fields are always compatible (null reason/elapsed/signal are canonical forms).

**PH1-M11+ (run fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `run_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/RUN_FINGERPRINT_PLAN.md`). |
| `run_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `host_identity_sysname`, before `transport`: `run_fingerprint_digest`, `run_fingerprint_version` (lexicographic).

**PH1-M12+ (spec-set fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `specset_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/SPECSET_FINGERPRINT_PLAN.md`). |
| `specset_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `run_fingerprint_version`, before `transport`: `specset_fingerprint_digest`, `specset_fingerprint_version` (lexicographic).

**PH1-M13+ (results-set fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `resultset_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/RESULTSET_FINGERPRINT_PLAN.md`). |
| `resultset_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `specset_fingerprint_version`, before the nested `transport` object: `resultset_fingerprint_digest`, `resultset_fingerprint_version` (lexicographic).

**PH1-M14+ (transport fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `transport_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/TRANSPORT_FINGERPRINT_PLAN.md`). |
| `transport_fingerprint_version` | string | Fingerprint schema revision; **`3`** after **PH1-M36** (preflight path normalization line); **`2`** after **PH1-M35** (preflight lines without normalization); legacy **`1`** only in older fixtures. |

**Serialization order**: after `resultset_fingerprint_version`, before root **`exec_summary_fingerprint_*`**, root **`context_summary_fingerprint_*`**, root **`metadata_envelope_fingerprint_*`**, root **`artifact_bundle_fingerprint_*`**, root **`report_envelope_fingerprint_*`**, root **`compare_envelope_fingerprint_*`**, root **`run_envelope_fingerprint_*`**, root **`session_envelope_fingerprint_*`**, root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `transport_fingerprint_digest`, `transport_fingerprint_version` (lexicographic).

**PH1-M15+ (execution-summary fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `exec_summary_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/EXEC_SUMMARY_FINGERPRINT_PLAN.md`). |
| `exec_summary_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `transport_fingerprint_version`, before root **`context_summary_fingerprint_*`**, root **`metadata_envelope_fingerprint_*`**, root **`artifact_bundle_fingerprint_*`**, root **`report_envelope_fingerprint_*`**, root **`compare_envelope_fingerprint_*`**, root **`run_envelope_fingerprint_*`**, root **`session_envelope_fingerprint_*`**, root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `exec_summary_fingerprint_digest`, `exec_summary_fingerprint_version` (lexicographic).

**PH1-M16+ (context-summary fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `context_summary_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/CONTEXT_SUMMARY_FINGERPRINT_PLAN.md`). |
| `context_summary_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `exec_summary_fingerprint_version`, before root **`metadata_envelope_fingerprint_*`**, root **`artifact_bundle_fingerprint_*`**, root **`report_envelope_fingerprint_*`**, root **`compare_envelope_fingerprint_*`**, root **`run_envelope_fingerprint_*`**, root **`session_envelope_fingerprint_*`**, root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `context_summary_fingerprint_digest`, `context_summary_fingerprint_version` (lexicographic).

**PH1-M17+ (metadata-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `metadata_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/METADATA_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `metadata_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `context_summary_fingerprint_version`, before root **`artifact_bundle_fingerprint_*`**, root **`report_envelope_fingerprint_*`**, root **`compare_envelope_fingerprint_*`**, root **`run_envelope_fingerprint_*`**, root **`session_envelope_fingerprint_*`**, root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `metadata_envelope_fingerprint_digest`, `metadata_envelope_fingerprint_version` (lexicographic).

**PH1-M18+ (artifact-bundle fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `artifact_bundle_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/ARTIFACT_BUNDLE_FINGERPRINT_PLAN.md`). |
| `artifact_bundle_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `metadata_envelope_fingerprint_version`, before root **`report_envelope_fingerprint_*`**, root **`compare_envelope_fingerprint_*`**, root **`run_envelope_fingerprint_*`**, root **`session_envelope_fingerprint_*`**, root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `artifact_bundle_fingerprint_digest`, `artifact_bundle_fingerprint_version` (lexicographic).

**PH1-M19+ (report-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `report_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/REPORT_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `report_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `artifact_bundle_fingerprint_version`, before root **`compare_envelope_fingerprint_*`**, root **`run_envelope_fingerprint_*`**, root **`session_envelope_fingerprint_*`**, root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `report_envelope_fingerprint_digest`, `report_envelope_fingerprint_version` (lexicographic).

**PH1-M20+ (compare-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `compare_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/COMPARE_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `compare_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `report_envelope_fingerprint_version`, before root **`run_envelope_fingerprint_*`**, root **`session_envelope_fingerprint_*`**, root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `compare_envelope_fingerprint_digest`, `compare_envelope_fingerprint_version` (lexicographic).

**PH1-M21+ (run-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `run_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/RUN_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `run_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `compare_envelope_fingerprint_version`, before root **`session_envelope_fingerprint_*`**, root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `run_envelope_fingerprint_digest`, `run_envelope_fingerprint_version` (lexicographic).

**PH1-M22+ (session-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `session_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/SESSION_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `session_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `run_envelope_fingerprint_version`, before root **`environment_envelope_fingerprint_*`**, root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `session_envelope_fingerprint_digest`, `session_envelope_fingerprint_version` (lexicographic).

**PH1-M23+ (environment-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `environment_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/ENVIRONMENT_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `environment_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `session_envelope_fingerprint_version`, before root **`artifact_manifest_fingerprint_*`**, root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `environment_envelope_fingerprint_digest`, `environment_envelope_fingerprint_version` (lexicographic).

**PH1-M24+ (artifact-manifest fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `artifact_manifest_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/ARTIFACT_MANIFEST_FINGERPRINT_PLAN.md`). |
| `artifact_manifest_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `environment_envelope_fingerprint_version`, before root **`provenance_envelope_fingerprint_*`**, root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `artifact_manifest_fingerprint_digest`, `artifact_manifest_fingerprint_version` (lexicographic).

**PH1-M25+ (provenance-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `provenance_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/PROVENANCE_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `provenance_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `artifact_manifest_fingerprint_version`, before root **`integrity_envelope_fingerprint_*`**, root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `provenance_envelope_fingerprint_digest`, `provenance_envelope_fingerprint_version` (lexicographic).

**PH1-M26+ (integrity-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `integrity_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/INTEGRITY_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `integrity_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `provenance_envelope_fingerprint_version`, before root **`consistency_envelope_fingerprint_*`**, root **`trace_envelope_fingerprint_*`**, root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`**, and the nested `transport` object: `integrity_envelope_fingerprint_digest`, `integrity_envelope_fingerprint_version` (lexicographic).

**PH1-M27+ (consistency-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `consistency_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/CONSISTENCY_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `consistency_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `integrity_envelope_fingerprint_version`, before the nested `transport` object: `consistency_envelope_fingerprint_digest`, `consistency_envelope_fingerprint_version` (lexicographic).

**PH1-M28+ (trace-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `trace_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/TRACE_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `trace_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `consistency_envelope_fingerprint_version`, before root **`lineage_envelope_fingerprint_*`**, root **`state_envelope_fingerprint_*`** and the nested `transport` object: `trace_envelope_fingerprint_digest`, `trace_envelope_fingerprint_version` (lexicographic).

**PH1-M29+ (lineage-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `lineage_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/LINEAGE_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `lineage_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `trace_envelope_fingerprint_version`, before root **`state_envelope_fingerprint_*`** and the nested `transport` object: `lineage_envelope_fingerprint_digest`, `lineage_envelope_fingerprint_version` (lexicographic).

**PH1-M30+ (state-envelope fingerprint)** — present on every harness `run.json` that writes artifacts:

| Field | Type | Description |
|-------|------|-------------|
| `state_envelope_fingerprint_digest` | string | **64**-character lowercase hex SHA-256 of the canonical payload (`docs/STATE_ENVELOPE_FINGERPRINT_PLAN.md`). |
| `state_envelope_fingerprint_version` | string | Fingerprint schema revision; phase-1 value **`1`**. |

**Serialization order**: after `lineage_envelope_fingerprint_version`, before the nested `transport` object: `state_envelope_fingerprint_digest`, `state_envelope_fingerprint_version` (lexicographic).

Each **result** object includes:

| Field | Type | Description |
|-------|------|-------------|
| `spec_id` | string | Probe `id` from spec. |
| `status` | string | One of: `pass`, `fail`, `manual`, `unsupported`, `error`. |
| `notes` | string | Freeform notes or error summary. |
| `observations` | object | Raw or structured observations (capture mode dependent). |

Phase-1 placeholder runs may use minimal values but must preserve these keys for tooling stability.

## `transport` object (`run.json`, PH1-M5+)

The harness emits a **`transport`** object alongside core run fields. Keys are stable for `report` / `compare`.

**Serialization order (PH1-M9+)**: when `mode` is `pty_guarded`, the harness writes transport keys in lexicographic order: `guarded_opt_in`, `guarded_state`, `handshake`, `handshake_latency_ns`, `mode`, `pty_capability_notes`, `pty_experiment_attempt`, `pty_experiment_elapsed_ns`, `pty_experiment_error`, `pty_experiment_host_machine`, `pty_experiment_host_release`, `pty_experiment_open_ok`, `terminal_launch_attempt`, `terminal_launch_elapsed_ns`, `terminal_launch_error`, `terminal_launch_exit_code`, `terminal_launch_ok`, `terminal_launch_outcome`, `timeout_ms`.

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | `none`, `pty_stub`, or `pty_guarded`. |
| `timeout_ms` | integer | Positive deadline budget (milliseconds). |
| `handshake` | string or `null` | Stub handshake token when applicable. |
| `handshake_latency_ns` | integer | Synthetic latency; `0` when `mode` is `none`. |
| `guarded_opt_in` | boolean | `true` only for `pty_guarded` runs that passed the opt-in gate. |
| `guarded_state` | string | `na` \| `scaffold_only` \| `experiment_linux_pty` (see `docs/CLI.md`). |

**PH1-M7+ (guarded Linux PTY experiment)** — present when `mode` is `pty_guarded`:

| Field | Type | Description |
|-------|------|-------------|
| `pty_capability_notes` | string or `null` | Human-readable note on what was attempted (e.g. Linux `/dev/ptmx` path); `null` when `guarded_state` is `scaffold_only`. |
| `pty_experiment_attempt` | integer or `null` | **PH1-M8+**: `null` when `scaffold_only`; otherwise **`1`** (single experiment attempt). |
| `pty_experiment_elapsed_ns` | integer or `null` | **PH1-M8+**: `null` when `scaffold_only`; else wall-time nanoseconds for the experiment block, clamped to signed JSON range (`≤ 2^63−1`). |
| `pty_experiment_error` | string or `null` | Short static reason when open failed; `null` on success or when not applicable. |
| `pty_experiment_host_machine` | string or `null` | **PH1-M9+**: `null` when `scaffold_only`; else non-empty `uname.machine` snapshot (truncated if needed). |
| `pty_experiment_host_release` | string or `null` | **PH1-M9+**: `null` when `scaffold_only`; else non-empty `uname.release` snapshot (truncated to harness buffer). |
| `pty_experiment_open_ok` | boolean or `null` | `null` when `guarded_state` is `scaffold_only`; otherwise whether the minimal PTY pair opened. |

See **`docs/PTY_EXPERIMENT_HARDENING_PLAN.md`** (PH1-M8) and **`docs/PTY_REPRODUCIBILITY_PLAN.md`** (PH1-M9).

**PH1-M31 (guarded Linux real terminal launch)** — present when `mode` is `pty_guarded` and the harness records process-level launch evidence (see **`docs/REAL_TERMINAL_LAUNCH_PLAN.md`**):

| Field | Type | Description |
|-------|------|-------------|
| `terminal_launch_attempt` | integer or `null` | **`1`** when a launch was attempted; **`null`** when not applicable (e.g. scaffold, non-Linux, non-guarded, empty `--terminal-cmd`). |
| `terminal_launch_elapsed_ns` | integer or `null` | Wall time for the launch attempt (nanoseconds), clamped to signed JSON range; **`null`** when no attempt. |
| `terminal_launch_error` | string or `null` | Short static reason (`timeout`, `spawn_failed`, …) or **`null`**. |
| `terminal_launch_exit_code` | integer or `null` | Child exit code when reaped normally; **`null`** on spawn failure or timeout before status. |
| `terminal_launch_ok` | boolean or `null` | **`true`** / **`false`** when a launch ran to completion; **`null`** when no attempt. |

**PH1-M32 (launch outcome class)** — when **`terminal_launch_attempt`** is **`1`**, **`terminal_launch_outcome`** is set (see **`docs/TERMINAL_LAUNCH_SEMANTICS_PLAN.md`**):

| Field | Type | Description |
|-------|------|-------------|
| `terminal_launch_outcome` | string or `null` | One of: **`ok`**, **`nonzero_exit`**, **`signaled`**, **`timeout`**, **`spawn_failed`**; **`null`** when no launch attempt. |

## `summary.md` (required)

Markdown document with:

1. Title line with run id and date.
2. Short **Environment** section: platform, terminal, `TERM`.
3. **Results** table or list: spec id, status, one-line note.
4. Optional **Next steps** for manual probes.

## Exit code policy (report command)

When reading `run.json`, `report` exits `0` on success, non-zero if the file is missing or invalid JSON (see `docs/CLI.md`).
