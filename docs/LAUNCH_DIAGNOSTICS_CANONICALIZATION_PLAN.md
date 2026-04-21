# Launch Diagnostics Canonicalization Plan (PH1-M39)

## Objective

Harden launch diagnostics fingerprint stability by enforcing canonical normalization rules for reason/elapsed/signal inputs so normalization drift is prevented across run emission, schema validation, and compare metadata.

## Context

PH1-M38 introduced `terminal_launch_diagnostics_fingerprint_*` fields that compose the diagnostics envelope into a deterministic SHA-256 digest. However, without explicit canonicalization rules, subtle differences in how different code paths handle null/zero/invalid values could cause:
- The same logical diagnostics state → different fingerprints (false negatives)
- Different logical diagnostics states → same fingerprint (false positives)

This milestone prevents normalization drift by defining canonical forms and enforcing them across all code paths.

## Scope

### 1. Canonical Forms

**Reason field** (string or null):
- **Valid tags** (string, one of): `ok`, `missing_executable`, `not_executable`, `spawn_failed`, `timeout`, `nonzero_exit`, `signaled`
- **Canonical form**: lowercase ASCII, exact tag match (no spaces, no extra characters)
- **Null form**: absent from canonical payload (rendered as "null" string in serialization)
- **Invalid forms**: empty string, misspelled tags, uppercase variants — must be rejected by validation

**Elapsed field** (number or null):
- **Valid range**: `0` to `maxInt(u32)` milliseconds (non-negative integers only)
- **Canonical form**: decimal integer, no leading zeros (except for `0`), no whitespace
- **Null form**: absent (rendered as "null" string in serialization)
- **Invalid forms**: negative numbers, floating-point, scientific notation — must be rejected by validation
- **Edge case**: `0` is a valid canonical value (allowed for preflight failures with no elapsed time)

**Signal field** (number or null):
- **Valid range**: `1` to `128` (standard POSIX signal numbers)
- **Canonical form**: decimal integer, no leading zeros, no whitespace
- **Null form**: absent (rendered as "null" string in serialization)
- **Invalid forms**: negative numbers, zero, >128, floating-point — must be rejected by validation
- **Edge case**: zero is NOT valid (signals start at 1; zero is reserved for "no signal")

### 2. Normalization Rules

#### JSON Parsing (run_json_validate.zig)
- Reject any diagnostics reason value that is not an exact lowercase tag match
- Reject any elapsed_ms that is negative, non-integer, or >maxInt(u32)
- Reject any signal that is negative, zero, non-integer, or >128
- Allow null for all three fields (no rejection of missing fields)

#### Fingerprint Composition (launch_diagnostics_fingerprint.zig)
- Convert null reason/elapsed/signal to string "null" in canonical payload
- For non-null values: use the JSON number representation as-is (already normalized by parser)
- No additional formatting or rounding allowed

#### JSON Emission (json_writer.zig)
- Output diagnostics_reason as JSON string or null
- Output diagnostics_elapsed_ms as JSON number or null
- Output diagnostics_signal as JSON number or null
- No type coercion (u32→string, etc.)

#### Compare Parsing (compare/run_json.zig)
- Read diagnostics fields as strings (for metadata delta comparison)
- Store as-is without re-canonicalization (canonical form already enforced by validation)
- Compare field values as exact string matches

### 3. Cross-File Invariants

**Writer ↔ Validator invariant**:
- Every diagnostics value written to JSON must be acceptable to schema validation
- No valid-on-write → invalid-on-read transitions allowed

**Validator ↔ Fingerprint invariant**:
- Every diagnostics value accepted by validation must be reproducibly serialized in canonical form
- Same diagnostics values (after validation) must always produce identical canonical payloads

**Fingerprint ↔ Compare invariant**:
- Fingerprint digest computed from canonical payload must match digests of runs with identical diagnostics (after validation)
- Compare metadata rows must show no delta for runs with identical validated diagnostics

### 4. Integration Points

#### RunContext (src/cli/run_context.zig)
No changes needed (fields already canonical as stored from telemetry).

#### LaunchTelemetry (src/runner/real_terminal_launch.zig)
No changes needed (values already in canonical form from spawn/timeout/exit logic).

#### JSON Writer (src/report/json_writer.zig)
Verify fields are output as-is (no normalization needed post-validation).

#### Schema Validation (src/report/run_json_validate.zig)
**ADD**: Strict canonical form checks for all three fields.
- Reason: exact tag match (one of the 7 valid values)
- Elapsed: non-negative integer in range [0, maxInt(u32)]
- Signal: integer in range [1, 128]

#### Fingerprint Population (src/report/launch_diagnostics_fingerprint.zig)
**ADD**: Document that inputs are pre-validated; assume canonical form.

**ANA-3905 Pipeline Threading**: Canonicalized inputs from validation flow through fingerprint populate() unchanged:
- validate() in run_json_validate.zig enforces canonical forms (reason tags, elapsed range, signal range)
- populate() in launch_diagnostics_fingerprint.zig receives canonicalized values
- Canonical payload serialization guarantees determinism: same validated inputs → identical fingerprints
- Fingerprint digest flows to JSON writer and compare parsing without re-normalization
- Invariant: fingerprint determinism is preserved if and only if validation enforces canonical forms

#### Compare Parsing (src/compare/run_json.zig)
**ADD**: Edge-case metadata rows for:
- Reason mismatch with same fingerprint (indicates canonicalization bug)
- Elapsed/signal mismatch with same fingerprint (indicates canonicalization bug)

### 5. Acceptance Criteria

- [x] Plan complete with explicit canonical forms and cross-file invariants
- [ ] Canonicalization rules enforced in schema validation
- [ ] Normalization drift tests added to regression suite
- [ ] Compare metadata surfaces canonicalization edge cases
- [ ] All 228 tests pass
- [ ] Smoke documentation updated with canonicalization checks

## Non-Goals (PH1-M39)

- Timezone handling for elapsed timestamps
- Locale-dependent number formatting
- Signal name lookups (e.g., `SIGKILL` → `9`)
- Unicode normalization for reason strings (reason values are ASCII only)

## Boundaries and Edges

### Well-Defined (No Error)
- null reason + 0 elapsed + null signal (preflight failure with no runtime elapsed)
- "ok" reason + 100 elapsed + null signal (successful launch with measured elapsed)
- "signaled" reason + 50 elapsed + 9 signal (process killed with elapsed time)

### Undefined Behavior (Error on Parse/Validation)
- empty string reason (must use null instead)
- reason value with uppercase letters (must be lowercase)
- negative elapsed_ms (must be ≥0)
- signal value of 0 (must be in range [1, 128])
- reason="timeout" + signal=9 (signal should be null for timeout outcome)

### Detection (Regression Tests)
- Write with canonical form → read back with exact match
- Same logical diagnostics → identical fingerprints
- Different diagnostics → different fingerprints
- Edge cases (zero elapsed, high signal numbers) handled consistently

## Implementation Status (PH1-M39 Execution)

### ANA-3905: Pipeline Threading
- Status: ✓ Implemented in ANA-3904 validation
- Canonicalized inputs flow through fingerprint population unchanged
- Fingerprint logic assumes pre-validated canonical form

### ANA-3906: Schema Validation Enforcement  
- Status: ✓ Implemented in ANA-3904
- Schema validation enforces all canonicalization invariants
- Reason must match exact tags (case-sensitive lowercase)
- Elapsed must be non-negative integer ≤ maxInt(u32)
- Signal must be integer in range [1, 128]
