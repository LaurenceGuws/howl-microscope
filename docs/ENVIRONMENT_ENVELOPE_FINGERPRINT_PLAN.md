# Environment-envelope fingerprint (PH1-M23)

## Objective

Add a **deterministic environment-envelope fingerprint** to **`run.json` root** so replay tooling can compare a **single handle** that binds the PH1-M22 **session-envelope** digest to a **phase-1 environment contract tag** for the primary `run.json` artifact, without hashing nested **`transport`** or **`results`** bodies.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`environment_envelope_fingerprint_digest`** / **`environment_envelope_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: replacing upstream fingerprint plans; hashing full **`results`** or **`transport`** JSON.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `environment_envelope_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `environment_envelope_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`session_envelope_fingerprint_version`**, before the nested **`transport`** object: **`environment_envelope_fingerprint_digest`**, **`environment_envelope_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M23/environment-envelope/fp/v1`
2. **`session_envelope_fingerprint_digest`** (64 lowercase hex), then a line **`1`** (phase-1 schema revision for that layer).
3. Fixed **environment contract** line (phase-1 primary run artifact): `environment:run.json:v0.2`

Digest lines use the same bytes as the corresponding root JSON string value for **`session_envelope_fingerprint_digest`** (after **`session_envelope_fingerprint.populate`**).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Ordering contract**: new environment contract tags or schema bumps require **`environment_envelope_fingerprint_version`** migration notes.
- **Coupling**: the environment-envelope digest changes when the **session-envelope** digest changes or when the **environment contract** line changes (intended for audit).

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same **`session_envelope_fingerprint_digest`** and contract tag **`1`** → identical **`environment_envelope_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
