# Transport plan (PH1-M5)

This document bounds **terminal transport ownership seams** for Howl Microscope: how runs record *which transport path* was used (`none` vs deterministic **`pty_stub`**) while staying **text-first**, **offline-safe**, and **compare-friendly**.

## Scope (PH1-M5)

- **Transport mode** in CLI and `RunContext`: `none` (no transport simulation) and `pty_stub` (deterministic stub handshake/latency; **no** real PTY).
- **`--timeout-ms`**: configured deadline budget recorded in artifacts (stub does not enforce wall-clock timeouts yet).
- **`run.json` `transport` object**: `mode`, `timeout_ms`, `handshake` (string or `null`), `handshake_latency_ns` (integer; synthetic for `pty_stub`).
- **Validation** in `report` and **metadata deltas** in `compare` so transport differences show up in evidence.

## Non-goals (PH1-M5)

- Production **PTY / ConPTY** integration or real child process I/O.
- Screenshot, OCR, or pixel comparison.
- Rich TUI or interactive transport debugger.

## Safety boundaries

- Stub transport **must not** open OS pseudoterminals or spawn shells by default; it only emits **deterministic** metadata suitable for regression tests.
- Operators opting into **`pty_stub`** still get **stub** semantics only until a later milestone promotes real transport (`docs/todo/implementation.md` → `PH1-M6`).

## Success criteria

- Two runs differing only by **`--transport`** (or timeout) produce **`compare`** metadata rows that surface the change.
- `docs/SMOKE.md` documents a short **transport-stub** regression path.

## References

- CLI: `docs/CLI.md`
- Protocol seam (prior milestone): `docs/PROTO_EXEC_PLAN.md`
- Artifacts: `docs/REPORT_FORMAT.md`
