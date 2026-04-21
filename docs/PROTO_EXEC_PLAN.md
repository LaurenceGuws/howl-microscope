# Protocol execution plan (PH1-M4)

This document bounds **protocol-aware execution seams** for Howl Microscope: how the harness records *how* specs were executed (placeholder vs protocol stub) while keeping **text-first, deterministic artifacts** suitable for `compare`.

## Scope (PH1-M4)

- **Execution mode** surface in CLI and `run.json`: `placeholder` (phase-1 scaffold, no transport) and `protocol_stub` (deterministic fake observations via a runner seam).
- **Runner seam** under `src/runner/`: a small module invoked by the `run` / `run-suite` pipeline when mode is `protocol_stub`, producing stable synthetic `observations` for each spec.
- **Flags** `--dry-run` and `--strict` (contract in `docs/CLI.md`): parsed and threaded so later milestones can tighten behavior without changing the artifact schema again.
- **Reporting**: `report` validation and `compare` metadata include **execution mode** so mismatches are visible in evidence.

## Non-goals (PH1-M4)

- Real **PTY / ConPTY** sessions, terminal spawning, or byte-accurate escape replay.
- Screenshot, OCR, or pixel comparison.
- Rich TUI or interactive debugging UI.

## Seam boundaries

| Layer | Responsibility |
|-------|----------------|
| CLI | Parse `--exec-mode`, `--dry-run`, `--strict`; build `RunContext`. |
| `run_pipeline` | Dispatch placeholder vs protocol-stub execution; honor dry-run (no artifact write). |
| `protocol_stub` | Deterministic `RunRecord` + `observations` only; no I/O to a real terminal. |
| `json_writer` / `markdown_writer` | Emit `execution_mode` and stable result rows. |
| `compare` / `run_json_validate` | Surface execution mode in metadata and enforce schema. |

## Success criteria

- Operator can run **`run-suite`** (or **`run`**) with **`--exec-mode protocol_stub`**, produce **`run.json`** that validates under **`report`**, and **`compare`** two runs with different execution modes shows a **metadata** delta on `execution_mode`.
- **`--dry-run`** exercises validation and planning without writing a new run directory (see `docs/SMOKE.md`).

## References

- CLI contract: `docs/CLI.md`
- Artifacts: `docs/REPORT_FORMAT.md`
- Comparison lane: `docs/COMPARE_PLAN.md`
