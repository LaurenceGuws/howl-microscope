# Integrity-envelope fingerprint (PH1-M26)

## Objective

Add a **deterministic integrity-envelope fingerprint** to **`run.json` root** so replay tooling can compare a **single handle** that binds the PH1-M25 **provenance-envelope** digest to a **phase-1 integrity contract tag** for the primary `run.json` artifact, without hashing nested **`transport`** or **`results`** bodies.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`integrity_envelope_fingerprint_digest`** / **`integrity_envelope_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: replacing upstream fingerprint plans; hashing full **`results`** or **`transport`** JSON.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `integrity_envelope_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `integrity_envelope_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`provenance_envelope_fingerprint_version`**, before the nested **`transport`** object: **`integrity_envelope_fingerprint_digest`**, **`integrity_envelope_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M26/integrity-envelope/fp/v1`
2. **`provenance_envelope_fingerprint_digest`** (64 lowercase hex), then a line **`1`** (phase-1 schema revision for that layer).
3. Fixed **integrity contract** line (phase-1 primary run artifact): `integrity:run.json:v0.2`

Digest lines use the same bytes as the corresponding root JSON string value for **`provenance_envelope_fingerprint_digest`** (after **`provenance_envelope_fingerprint.populate`**).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Ordering contract**: new integrity contract tags or schema bumps require **`integrity_envelope_fingerprint_version`** migration notes.
- **Coupling**: the integrity-envelope digest changes when the **provenance-envelope** digest changes or when the **integrity contract** line changes (intended for audit).

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same **`provenance_envelope_fingerprint_digest`** and contract tag **`1`** → identical **`integrity_envelope_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
