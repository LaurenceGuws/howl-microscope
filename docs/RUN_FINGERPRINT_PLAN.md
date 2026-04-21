# Run fingerprint (PH1-M11)

## Objective

Add **deterministic root-level run fingerprint** fields to **`run.json`** so operators and tooling can correlate runs, detect accidental duplication, and diff metadata without relying on opaque file paths alone.

## Boundaries

- **In scope**: stable string fields on every artifact-producing run; SHA-256 over a documented canonical payload; **`compare`** / **`report`** schema coverage.
- **Out of scope**: signing or HMAC; Merkle trees over result bodies; cross-host attestation; embedding the fingerprint inside `transport`.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `run_fingerprint_version` | string | Phase-1 value **`1`** (must match canonical prefix revision below). |
| `run_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |

**Serialization order**: immediately after **`host_identity_sysname`**, before **`transport`**: **`run_fingerprint_digest`**, **`run_fingerprint_version`** (lexicographic: `digest` before `version`).

**Dry-run**: no `run.json`; fields not emitted.

## Canonical payload (version `1`)

UTF-8 text, trailing newline on each logical line, in order:

1. Literal prefix line: `PH1-M11/fp/v1`
2. `run_id`
3. `platform` (harness `run.json` root)
4. `execution_mode` tag
5. `transport.mode` tag
6. `host_identity_machine` (raw snapshot bytes, not JSON-escaped)
7. `host_identity_release`
8. `host_identity_sysname`
9. For each **`RunRecord`** in emission order: `spec_id` line

Then **SHA-256** the UTF-8 bytes; emit **lowercase hex** (no `0x`).

## Risks

- **Canonical drift**: any change to this payload format requires bumping **`run_fingerprint_version`** and the prefix line.
- **Host identity must be captured before hashing** (`captureHostIdentity` before fingerprint populate).
- **Empty `spec_id`**: forbidden by harness; if present, it still participates in the payload.

## Acceptance checks

- `zig build` / `zig build test` pass.
- Identical inputs (same `run_id`, context fields, ordered `spec_id` list) yield identical **`run_fingerprint_digest`**.
- **`report`** validates digest length and hex charset; **`compare`** lists fingerprint rows.
