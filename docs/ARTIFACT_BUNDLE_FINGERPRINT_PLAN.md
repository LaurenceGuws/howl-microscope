# Artifact-bundle fingerprint (PH1-M18)

## Objective

Add a **deterministic artifact-bundle fingerprint** to **`run.json` root** so replay tooling can compare a **single handle** that binds the PH1-M17 **metadata-envelope** digest to the **phase-1 companion artifact filenames** written alongside `run.json` (`env.json`, `summary.md`), without hashing file bodies (avoids circular dependency with `run.json` content).

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`artifact_bundle_fingerprint_digest`** / **`artifact_bundle_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: hashing **`results`** or nested **`transport`** JSON; replacing upstream fingerprint plans; content hashing of `summary.md` / `env.json` in phase-1.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `artifact_bundle_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `artifact_bundle_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`metadata_envelope_fingerprint_version`**, before the nested **`transport`** object: **`artifact_bundle_fingerprint_digest`**, **`artifact_bundle_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M18/artifact-bundle/fp/v1`
2. **`metadata_envelope_fingerprint_digest`** (64 lowercase hex), then a line **`1`** (phase-1 schema revision for that layer).
3. Fixed **artifact manifest** lines (lexicographic order, one relative path per line, each prefixed with `artifact:`):
   - `artifact:env.json`
   - `artifact:run.json`
   - `artifact:summary.md`

Digest lines use the same bytes as the corresponding root JSON string value for **`metadata_envelope_fingerprint_digest`** (after **`metadata_envelope_fingerprint.populate`**).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Ordering contract**: new companion artifacts in phase-1 require an updated manifest and a **`artifact_bundle_fingerprint_version`** bump with migration notes.
- **Coupling**: the bundle digest changes when the **metadata-envelope** digest changes or when the **manifest** contract changes (intended for audit).

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same **`metadata_envelope_fingerprint_digest`** and manifest **`1`** → identical **`artifact_bundle_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
