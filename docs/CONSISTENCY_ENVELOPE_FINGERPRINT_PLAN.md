# Consistency-envelope fingerprint (PH1-M27)

## Objective

Add a **deterministic consistency-envelope fingerprint** to **`run.json` root** so replay tooling can compare a **single handle** that binds the PH1-M26 **integrity-envelope** digest to a **phase-1 consistency contract tag** for the primary `run.json` artifact, without hashing nested **`transport`** or **`results`** bodies.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`consistency_envelope_fingerprint_digest`** / **`consistency_envelope_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: replacing upstream fingerprint plans; hashing full **`results`** or **`transport`** JSON.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `consistency_envelope_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `consistency_envelope_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`integrity_envelope_fingerprint_version`**, before the nested **`transport`** object: **`consistency_envelope_fingerprint_digest`**, **`consistency_envelope_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M27/consistency-envelope/fp/v1`
2. **`integrity_envelope_fingerprint_digest`** (64 lowercase hex), then a line **`1`** (phase-1 schema revision for that layer).
3. Fixed **consistency contract** line (phase-1 primary run artifact): `consistency:run.json:v0.2`

Digest lines use the same bytes as the corresponding root JSON string value for **`integrity_envelope_fingerprint_digest`** (after **`integrity_envelope_fingerprint.populate`**).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Ordering contract**: new consistency contract tags or schema bumps require **`consistency_envelope_fingerprint_version`** migration notes.
- **Coupling**: the consistency-envelope digest changes when the **integrity-envelope** digest changes or when the **consistency contract** line changes (intended for audit).

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same **`integrity_envelope_fingerprint_digest`** and contract tag **`1`** → identical **`consistency_envelope_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
