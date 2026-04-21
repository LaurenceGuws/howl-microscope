# Run-envelope fingerprint (PH1-M21)

## Objective

Add a **deterministic run-envelope fingerprint** to **`run.json` root** so replay tooling can compare a **single handle** that binds the PH1-M20 **compare-envelope** digest to a **phase-1 run contract tag** for the primary `run.json` artifact, without hashing nested **`transport`** or **`results`** bodies.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`run_envelope_fingerprint_digest`** / **`run_envelope_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: replacing upstream fingerprint plans; hashing full **`results`** or **`transport`** JSON.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `run_envelope_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `run_envelope_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`compare_envelope_fingerprint_version`**, before the nested **`transport`** object: **`run_envelope_fingerprint_digest`**, **`run_envelope_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M21/run-envelope/fp/v1`
2. **`compare_envelope_fingerprint_digest`** (64 lowercase hex), then a line **`1`** (phase-1 schema revision for that layer).
3. Fixed **run contract** line (phase-1 primary run artifact): `run:run.json:v0.2`

Digest lines use the same bytes as the corresponding root JSON string value for **`compare_envelope_fingerprint_digest`** (after **`compare_envelope_fingerprint.populate`**).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Ordering contract**: new run contract tags or schema bumps require **`run_envelope_fingerprint_version`** migration notes.
- **Coupling**: the run-envelope digest changes when the **compare-envelope** digest changes or when the **run contract** line changes (intended for audit).

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same **`compare_envelope_fingerprint_digest`** and contract tag **`1`** → identical **`run_envelope_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
