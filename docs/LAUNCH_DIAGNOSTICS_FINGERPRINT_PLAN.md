# Launch Diagnostics Fingerprint Plan (PH1-M38)

## Objective

Add a deterministic launch diagnostics fingerprint chain so changes in the launch diagnostics envelope (`terminal_launch_diagnostics_*` fields) are detectable, attributable, and comparable across artifacts and compare output.

## Context

PH1-M37 introduced the launch diagnostics envelope (reason, elapsed_ms, signal) to capture deterministic failure evidence during guarded launch execution. However, without fingerprint tracking, users cannot easily detect or compare diagnostics envelope changes across runs—they must visually inspect individual field deltas.

This milestone adds a canonical fingerprint composition that:
1. Captures the normalized diagnostics envelope state in a deterministic digest
2. Composes the diagnostics digest into run/compare metadata for auditability
3. Enables structured comparison of diagnostics changes across runs

## Scope

### 1. Canonical Payload (Deterministic Serialization)

The launch diagnostics fingerprint is computed from a canonical payload containing:

```
PH1-M38/launch-diagnostics-fingerprint/v1
<diagnostics_reason>
<diagnostics_elapsed_ms>
<diagnostics_signal>
EOF
```

Where:
- `<diagnostics_reason>`: string value (ok, missing_executable, not_executable, spawn_failed, timeout, nonzero_exit, signaled) or literal "null" if absent
- `<diagnostics_elapsed_ms>`: number value or literal "null" if absent
- `<diagnostics_signal>`: number value or literal "null" if absent

Each field is separated by newline (`\n`); the payload ends with EOF (no trailing newline after signal).

### 2. Fingerprint Computation

Digest: SHA-256 of canonical payload (hex-encoded, lowercase).
Version: `1` (fixed for PH1-M38, may increment if serialization changes).

Invariant: Two runs with identical diagnostics envelope values must produce identical fingerprints (determinism guarantee).

### 3. Integration Points

#### RunContext (src/cli/run_context.zig)
Add fields:
- `launch_diagnostics_fingerprint_digest: [64]u8` (SHA-256 hex)
- `launch_diagnostics_fingerprint_digest_len: u8`
- `launch_diagnostics_fingerprint_version: [1]u8`

#### LaunchTelemetry (src/runner/real_terminal_launch.zig)
Add fields:
- `launch_diagnostics_fingerprint_digest: [64]u8`
- `launch_diagnostics_fingerprint_digest_len: u8`
- `launch_diagnostics_fingerprint_version: [1]u8`

#### Population Seam (src/cli/run_pipeline.zig)
After `runBoundedArgvCommand` returns:
1. Construct canonical payload from LaunchTelemetry diagnostics fields
2. Compute SHA-256 digest
3. Copy digest and version to RunContext

#### JSON Emission (src/report/json_writer.zig)
Add three root-level fields in `run.json`:
- `terminal_launch_diagnostics_fingerprint_digest` (string, 64 hex chars)
- `terminal_launch_diagnostics_fingerprint_version` (string, "1")

Placement: After `terminal_launch_diagnostics_signal` and before `run_fingerprint_digest`.

#### Transport Fingerprint (src/report/transport_fingerprint.zig)
Include `launch_diagnostics_fingerprint_digest` in transport fingerprint v4 canonical payload (already included, verify consistency).

#### Schema Validation (src/report/run_json_validate.zig)
Validate:
- `terminal_launch_diagnostics_fingerprint_digest`: must be 64-char hex string or null
- `terminal_launch_diagnostics_fingerprint_version`: must be "1" or null

Invariant: If diagnostics_reason is non-null, fingerprint must be present and valid.

#### Compare Metadata (src/compare/run_json.zig)
Add to RunMeta:
- `launch_diagnostics_fingerprint_digest: ?[]const u8`
- `launch_diagnostics_fingerprint_version: ?[]const u8`

Add metadata delta rows in diffRunMeta:
- Row for digest comparison
- Row for version comparison (typically no delta)

### 4. Acceptance Criteria

- [x] Plan complete with explicit canonical payload, invariants, and scope boundaries
- [ ] RunContext and LaunchTelemetry augmented with fingerprint fields
- [ ] Fingerprint population logic implemented (canonical payload + SHA-256)
- [ ] JSON emission and validation complete
- [ ] Transport fingerprint includes diagnostics fingerprint
- [ ] Compare metadata rows added and tested
- [ ] Schema validation enforces invariants
- [ ] All regression tests pass
- [ ] Smoke documentation updated with diagnostics fingerprint checks

## Non-Goals (PH1-M38)

- Multi-field composite fingerprints (fingerprints of fingerprints)
- Incremental fingerprint updates or caching
- Windows or non-Linux diagnostics fingerprints (may be null on other platforms)
- Visualization of fingerprint diffs in TUI

## Tickets

```
ANA-3801: add docs/LAUNCH_DIAGNOSTICS_FINGERPRINT_PLAN.md
ANA-3802: document launch diagnostics fingerprint in CLI.md and REPORT_FORMAT.md
ANA-3803: add RunContext and LaunchTelemetry fingerprint fields
ANA-3804: implement fingerprint population logic
ANA-3805: emit fingerprint fields in run.json and summary
ANA-3806: enforce schema validation invariants
ANA-3807: extend compare metadata for fingerprint fields
ANA-3808: add unit tests for fingerprint determinism
ANA-3809: add regression tests and smoke updates
ANA-3810: finalize PH1_M38_CHECKPOINT.md
```

## Boundaries and Edges

### Undefined Behavior (Error)
- Fingerprint digest length != 64: validation error
- Fingerprint version != "1": validation error
- Diagnostics reason present but fingerprint absent: validation error

### Well-Defined Behavior (No Error)
- All three diagnostics fields null → fingerprint null (allowed pre-PH1-M37)
- Diagnostics fields present → fingerprint must be present (M38 invariant)
- Fingerprint computed same way on all platforms (canonical payload is platform-independent)
- Identical diagnostics values → identical fingerprint (SHA-256 guarantee)
