# Metadata-envelope fingerprint (PH1-M17)

## Objective

Add a **deterministic metadata-envelope fingerprint** to **`run.json` root** so replay tooling can compare a **single rollup** over the ordered stack of phase-1 root fingerprint digests (run, specset, resultset, transport, execution-summary, and context-summary), without re-hashing nested **`transport`** JSON or per-probe **`results`**.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`metadata_envelope_fingerprint_digest`** / **`metadata_envelope_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: replacing or duplicating the individual upstream fingerprint plans; hashing full **`results`**; hashing the nested **`transport`** object verbatim.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `metadata_envelope_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `metadata_envelope_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`context_summary_fingerprint_version`**, before the nested **`transport`** object: **`metadata_envelope_fingerprint_digest`**, **`metadata_envelope_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M17/metadata-envelope/fp/v1`
2. **`run_fingerprint_digest`** (64 lowercase hex), then a line **`1`** (phase-1 schema revision for that layer).
3. **`specset_fingerprint_digest`**, then **`1`**.
4. **`resultset_fingerprint_digest`**, then **`1`**.
5. **`transport_fingerprint_digest`**, then **`1`**.
6. **`exec_summary_fingerprint_digest`**, then **`1`**.
7. **`context_summary_fingerprint_digest`**, then **`1`**.

Digest lines use the same bytes as the corresponding root JSON string values (after each upstream `populate`).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Ordering contract**: any new root fingerprint pair inserted before the nested **`transport`** object must be reflected in this canonical sequence and bump **`metadata_envelope_fingerprint_version`** with migration notes.
- **Coupling**: the envelope digest changes when **any** upstream fingerprint digest changes (intended for audit rollup).

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same upstream digest stack → identical **`metadata_envelope_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
