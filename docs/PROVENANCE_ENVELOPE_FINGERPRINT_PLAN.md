# Provenance-envelope fingerprint (PH1-M25)

## Objective

Add a **deterministic provenance-envelope fingerprint** to **`run.json` root** so replay tooling can compare a **single handle** that binds the PH1-M24 **artifact-manifest** digest to a **phase-1 provenance contract tag** for the primary `run.json` artifact, without hashing nested **`transport`** or **`results`** bodies.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`provenance_envelope_fingerprint_digest`** / **`provenance_envelope_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: replacing upstream fingerprint plans; hashing full **`results`** or **`transport`** JSON.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `provenance_envelope_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `provenance_envelope_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`artifact_manifest_fingerprint_version`**, before the nested **`transport`** object: **`provenance_envelope_fingerprint_digest`**, **`provenance_envelope_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M25/provenance-envelope/fp/v1`
2. **`artifact_manifest_fingerprint_digest`** (64 lowercase hex), then a line **`1`** (phase-1 schema revision for that layer).
3. Fixed **provenance contract** line (phase-1 primary run artifact): `provenance:run.json:v0.2`

Digest lines use the same bytes as the corresponding root JSON string value for **`artifact_manifest_fingerprint_digest`** (after **`artifact_manifest_fingerprint.populate`**).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Ordering contract**: new provenance contract tags or schema bumps require **`provenance_envelope_fingerprint_version`** migration notes.
- **Coupling**: the provenance-envelope digest changes when the **artifact-manifest** digest changes or when the **provenance contract** line changes (intended for audit).

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same **`artifact_manifest_fingerprint_digest`** and contract tag **`1`** → identical **`provenance_envelope_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
