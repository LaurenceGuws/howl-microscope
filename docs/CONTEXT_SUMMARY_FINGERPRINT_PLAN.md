# Context-summary fingerprint (PH1-M16)

## Objective

Add a **deterministic context-summary fingerprint** to **`run.json` root** so replay tooling can compare **ambient and host-snapshot context** that is not already covered by the execution-summary fingerprint (for example **`TERM`**, launch **`terminal_cmd`**, guarded-transport policy opt-in, and captured **`host_identity_*`** strings).

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`context_summary_fingerprint_digest`** / **`context_summary_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: repeating fields hashed by **`exec_summary_fingerprint_*`**, per-probe payloads, nested **`transport`** verbatim JSON, or PTY experiment telemetry (handled under transport fingerprints).

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `context_summary_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `context_summary_fingerprint_version` | string | Phase-1 value **`1`**. |

**Serialization order**: immediately after **`exec_summary_fingerprint_version`**, before the nested **`transport`** object: **`context_summary_fingerprint_digest`**, **`context_summary_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M16/context-summary/fp/v1`
2. **`term`**: same string written to root `term` (typically from the process `TERM` environment variable at artifact write time).
3. **`terminal_cmd`**: same string as `RunContext.terminal_cmd` (may be empty).
4. **`allow_guarded_transport`**: literal `true` or `false`.
5. **`host_identity_machine`**: same bytes as root `host_identity_machine` (after `captureHostIdentity`, may be empty before capture; artifact runs must capture before populate).
6. **`host_identity_release`**: same bytes as root `host_identity_release`.
7. **`host_identity_sysname`**: same bytes as root `host_identity_sysname`.

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **`TERM` coupling**: digest changes if the harness environment’s `TERM` differs even when other inputs match; document for CI matrices.
- **Field growth**: new context-shaping inputs require a new fingerprint version and migration notes.

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same `RunContext` snapshot and same **`term`** string → identical **`context_summary_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
