# Host identity evidence (PH1-M10)

## Objective

Add **run-host** identity snapshots to **`run.json` root** (not under `transport`) so every artifact-producing run records deterministic **`uname(2)`**-derived strings for operator audit and compare, independent of the guarded PTY experiment block.

## Boundaries

- **In scope**: fields captured once per full run (when the harness writes `run.json`); same truncation policy as PH1-M9 PTY snapshots; JSON-escaped string emission; `report` schema + `compare` metadata rows.
- **Out of scope**: changing PTY `transport.pty_experiment_host_*` semantics; hostname/DNS; container-id probing; non-POSIX hosts beyond “best effort” `uname` where available.

## Field contract (root metadata)

| Key | Source | Caps (bytes) | Rule |
|-----|--------|--------------|------|
| `host_identity_machine` | `uname.machine` | 64 | Non-empty string on artifact runs. |
| `host_identity_release` | `uname.release` | 256 | Non-empty string on artifact runs. |
| `host_identity_sysname` | `uname.sysname` | 64 | Non-empty string on artifact runs. |

**Serialization order** (stable): immediately after `execution_mode`, before `transport`: `host_identity_machine`, `host_identity_release`, `host_identity_sysname` (lexicographic).

**Dry-run**: no `run.json`; no separate scaffold state for these keys.

## Risks

- **`uname` empty fields**: treat as harness bug on Linux; validator requires non-empty strings for phase-1 harness output.
- **Unicode / control characters**: must use JSON string encoding (same path as PTY host fields in `json_writer.zig`).
- **Divergence from `platform`**: root `platform` may reflect compile-time defaults; `host_identity_sysname` is runtime OS name—useful for spotting mismatches.

## Acceptance checks

- `zig build` and `zig build test` pass.
- Full run `run.json` validates with `report`; contains all three keys as non-empty strings.
- `compare` surfaces the three fields in metadata deltas.
- Docs: `REPORT_FORMAT.md`, `CLI.md`, `SMOKE.md` updated; checkpoint filed for `ANA-GATE-120`.
