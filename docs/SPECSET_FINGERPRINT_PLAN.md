# Spec-set fingerprint (PH1-M12)

## Objective

Add a **deterministic spec-set fingerprint** to **`run.json` root** so suite integrity checks can compare *which* probe specs ran and in *which order*, independent of per-run wall-clock or transport experiment outcomes.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`specset_fingerprint_digest`** / **`specset_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: hashing full spec file contents or TOML bodies; Merkle proofs; cross-run deduplication service.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `specset_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `specset_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`run_fingerprint_version`**, before **`transport`**: **`specset_fingerprint_digest`**, **`specset_fingerprint_version`** (lexicographic).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M12/specset/fp/v1`
2. Suite label: the harness `suite` string if present, else the literal `null` (three ASCII characters, not JSON `null` token).
3. For each **`RunRecord`** in **emission order** (same order as `results` in `run.json`): `spec_id` line.

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Ordering**: any change to execution order changes the digest (by design).
- **Suite string vs JSON**: canonical uses raw suite name or literal `null` line as documented—do not JSON-escape here.

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same ordered `spec_id` list and suite label → identical **`specset_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
