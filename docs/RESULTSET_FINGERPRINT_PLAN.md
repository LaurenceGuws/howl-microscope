# Results-set fingerprint (PH1-M13)

## Objective

Add a **deterministic results-set fingerprint** to **`run.json` root** so artifact integrity checks can compare *what outcome rows* were recorded (per probe) and in *which order*, independent of transport experiment noise or run id.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`resultset_fingerprint_digest`** / **`resultset_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: hashing full `observations` JSON bodies; cross-run deduplication services; embedding raw file paths.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `resultset_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `resultset_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`specset_fingerprint_version`**, before **`transport`**: **`resultset_fingerprint_digest`**, **`resultset_fingerprint_version`** (lexicographic).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M13/resultset/fp/v1`
2. For each **`RunRecord`** in **emission order** (same order as the `results` array in `run.json`), emit **four** lines per record:
   - `spec_id`
   - `status`
   - `capture_mode`
   - `notes` (verbatim; may be empty)

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Freeform `notes`**: any change to notes changes the digest (by design).
- **Newlines inside fields**: embedded `\n` in `notes` is allowed and affects the canonical stream; tooling should treat payloads as opaque bytes.

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same ordered result rows → identical **`resultset_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
