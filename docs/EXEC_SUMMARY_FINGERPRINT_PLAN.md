# Execution-summary fingerprint (PH1-M15)

## Objective

Add a **deterministic execution-summary fingerprint** to **`run.json` root** so replay tooling can compare *how* the harness was configured to execute (independent of per-probe outcomes and independent of the nested **`transport`** JSON blob).

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`exec_summary_fingerprint_digest`** / **`exec_summary_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: hashing full probe specs, `results` payloads, or nested **`transport`** verbatim JSON.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `exec_summary_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `exec_summary_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`transport_fingerprint_version`**, before the nested **`transport`** object: **`exec_summary_fingerprint_digest`**, **`exec_summary_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M15/exec-summary/fp/v1`
2. **`execution_mode`** tag (`placeholder` or `protocol_stub`).
3. **`strict`**: literal `true` or `false`.
4. **`platform`** harness tag (same string written to root `platform`).
5. **`capture_mode`** string (same as per-probe capture mode selection for the run).
6. **`terminal_name`** (logical terminal id string).
7. **`suite`**: suite name, or literal `null` (three ASCII characters) when absent.
8. **`comparison_id`**: string, or literal `null`.
9. **`run_group`**: string, or literal `null`.
10. **`transport_mode`** tag (`none`, `pty_stub`, or `pty_guarded`).
11. **`timeout_ms`** as decimal ASCII (same integer as root-adjacent transport budget / `transport.timeout_ms`).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Field growth**: adding new execution-shaping `RunContext` fields later requires a new fingerprint version and migration notes.
- **Optional labels**: `null` sentinel lines must stay stable vs JSON `null` tokens in other layers.

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same `RunContext` snapshot → identical **`exec_summary_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
