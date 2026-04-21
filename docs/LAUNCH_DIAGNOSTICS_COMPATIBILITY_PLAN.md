# Launch Diagnostics Compatibility Envelope Plan (PH1-M40)

## Objective

Add a launch diagnostics compatibility envelope that tracks canonicalization conformance status across run validation, fingerprinting, and compare output so operators can identify and diagnose non-canonical diagnostics values.

## Context

PH1-M39 introduced strict canonicalization rules for launch diagnostics (reason, elapsed_ms, signal) that are enforced at the validation boundary. However, operators need visibility into whether incoming runs conform to these rules. The compatibility envelope provides:

1. **Deterministic conformance tracking**: flags indicating canonical form for each field
2. **Structured diagnostics**: distinct "compatible", "warning", "incompatible" states
3. **Change detection**: compare metadata surfacing compatibility status shifts
4. **Audit trail**: full conformance history in artifacts and compare output

## Scope

### 1. Compatibility Envelope Model

**Structure**: Four new fields in `run.json` root metadata (separate from diagnostics values):

```
terminal_launch_diagnostics_compatible: "compatible" | "warning" | "incompatible"
terminal_launch_diagnostics_reason_compatible: boolean (true if canonical tag or null)
terminal_launch_diagnostics_elapsed_compatible: boolean (true if canonical u32 or null)
terminal_launch_diagnostics_signal_compatible: boolean (true if canonical [1,128] or null)
```

**Semantics**:

- `compatible`: all three diagnostics fields (if non-null) conform to canonical forms
- `warning`: at least one field is null (missing value is allowed but notable)
- `incompatible`: at least one field violates canonical constraints (validation would reject)

**Per-field compatibility**:
- `reason_compatible=true`: value is null OR one of {ok, missing_executable, not_executable, spawn_failed, timeout, nonzero_exit, signaled}
- `reason_compatible=false`: value is empty string, uppercase variant, misspelled tag, or any other non-canonical string
- `elapsed_compatible=true`: value is null OR integer in [0, maxInt(u32)]
- `elapsed_compatible=false`: value is negative, float, or scientific notation
- `signal_compatible=true`: value is null OR integer in [1, 128]
- `signal_compatible=false`: value is zero, negative, >128, or float

### 2. Integration Points

#### RunContext (src/cli/run_context.zig)
Add fields for compatibility status (bool flags, enum for overall state).

#### LaunchTelemetry (src/runner/real_terminal_launch.zig)
No changes needed (diagnostics values unchanged from PH1-M39).

#### Compatibility Envelope Population (new: src/report/launch_diagnostics_compatibility.zig)
Implement populate() function:
- Input: validated diagnostics fields from RunContext
- Logic: check each field against canonical constraints (reuse PH1-M39 validators)
- Output: fill compatibility flags and overall state
- Invariant: output reflects actual canonical conformance of input fields

#### JSON Emission (src/report/json_writer.zig)
Emit four new root fields after diagnostics fields:
- `terminal_launch_diagnostics_compatible` (string: "compatible"|"warning"|"incompatible")
- `terminal_launch_diagnostics_reason_compatible` (boolean)
- `terminal_launch_diagnostics_elapsed_compatible` (boolean)
- `terminal_launch_diagnostics_signal_compatible` (boolean)

#### Schema Validation (src/report/run_json_validate.zig)
Validate new fields:
- `compatible` must be exact string match ("compatible"|"warning"|"incompatible")
- `*_compatible` fields must be booleans
- Invariant: if overall=compatible, all per-field flags must be true
- Invariant: if all fields are null, overall must be "warning" or "compatible" (never "incompatible")
- Make fields optional for backward compatibility (pre-M40 artifacts may lack them)

#### Compare Metadata (src/compare/run_json.zig)
Add to RunMeta struct:
- `terminal_launch_diagnostics_compatible` (optional string)
- `terminal_launch_diagnostics_reason_compatible` (optional boolean)
- `terminal_launch_diagnostics_elapsed_compatible` (optional boolean)
- `terminal_launch_diagnostics_signal_compatible` (optional boolean)

Extend diffRunMeta:
- Add 4 rows to compare output showing per-field compatibility deltas
- Add 1 row showing overall compatibility status delta

### 3. Cross-File Invariants

**Validation → Compatibility invariant**:
- Schema validation accepts canonical values: compatibility=compatible
- Schema validation rejects non-canonical values: would have failed validation before population
- Compatibility envelope reflects canonical conformance of post-validation data

**Fingerprint → Compatibility invariant**:
- Fingerprint computed from canonical diagnostics values
- Compatibility=compatible guaranteed if fingerprint is non-null (implicitly canonical)
- Compatibility != compatible means fingerprint computation used canonicalized values

**Compare → Compatibility invariant**:
- Compatibility status deltas show when conformance changes between runs
- Incompatible status in either run is flagged for operator review

### 4. Acceptance Criteria

- [x] Plan complete with envelope model, integration points, and invariants
- [ ] Compatibility envelope fields added to RunContext
- [ ] Populate logic implements field-by-field canonical checks
- [ ] JSON emission includes all four compatibility fields
- [ ] Schema validation enforces compatibility field invariants
- [ ] Compare metadata extends with 5 compatibility rows
- [ ] Unit tests verify determinism and edge cases
- [ ] All tests pass (228 → 236 with new tests)
- [ ] Smoke documentation updated with M40 references

## Non-Goals (PH1-M40)

- Automatic repair of non-canonical values (validation still rejects them)
- Historical audit log (per-run compatibility snapshot only)
- Cross-artifact compatibility scoring
- Signal name translation (e.g., SIGKILL → 9)

## Boundaries and Edges

### Well-Defined (Compatible)
- null reason + null elapsed + null signal (all missing)
- "ok" reason + 100 elapsed + null signal (conformant values)
- "signaled" reason + 50 elapsed + 9 signal (conformant with signal)

### Warning
- null reason + null elapsed + 5 signal (mixed: some missing, some present)
- "ok" reason + null elapsed + null signal (only reason present)

### Incompatible
- "OK" reason (uppercase, non-canonical)
- -100 elapsed (negative, invalid range)
- 0 signal (zero not allowed, must be [1,128])
- "unknown" reason (unrecognized tag)

## Implementation Status (PH1-M40 Execution)

### ANA-4001: Plan (this document)
- Status: ✓ Complete
- Envelope model defined with clear conformance semantics
- Integration points specified
- Cross-file invariants documented

### ANA-4002: Documentation
- Status: Pending
- Update CLI.md with compatibility envelope concepts
- Update REPORT_FORMAT.md with field placement and types

### ANA-4003: Model Changes
- Status: Pending
- Add fields to RunContext
- Create helper type for compatibility state

### ANA-4004: Population Logic
- Status: Pending
- Implement src/report/launch_diagnostics_compatibility.zig
- Reuse canonical validators from PH1-M39

### ANA-4005: JSON Emission
- Status: Pending
- Emit four new root fields in json_writer.zig

### ANA-4006: Schema Validation
- Status: Pending
- Validate compatibility fields
- Enforce cross-field invariants

### ANA-4007: Compare Extension
- Status: Pending
- Add RunMeta fields
- Extend diffRunMeta to 89 rows (84 + 5 new)

### ANA-4008: Unit Tests
- Status: Pending
- Test populate() determinism
- Test edge cases and invariants

### ANA-4009: Regression Tests
- Status: Pending
- Add compatibility envelope edge case tests
- Update SMOKE.md

### ANA-4010: Checkpoint
- Status: Pending
- Finalize PH1_M40_CHECKPOINT.md
