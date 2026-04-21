# Harness architecture boundaries

This document defines module ownership for Howl Microscope. Each area has a single owner; cross-cutting concerns go through explicit seams (types, interfaces, and file boundaries), not by reaching into another module’s internals.

## Module boundary table

| Module | Owns | Must not own |
|--------|------|----------------|
| `core/` | Abstract harness concepts shared across layers: identifiers, error taxonomy, shared result shapes used by multiple modules. | Terminal I/O, spec parsing details, probe definitions, platform APIs. |
| `dsl/` | Text-defined probe specs: discovery, loading, validation, and the TOML (or future) schema contract. | Executing probes, capture mechanics, report rendering. |
| `runner/` | Orchestration of a run: planning steps, invoking capture hooks, assembling run records from probe outcomes. | Low-level PTY/ConPTY implementation (that is `platform/`). |
| `capture/` | Observation modes and how observations are recorded (manual, text, timed, etc.). | Spec syntax, JSON/markdown report layout. |
| `report/` | Emitting artifacts: JSON results, markdown summaries, paths under `artifacts/`. | Defining probe steps or DSL validation rules. |
| `probes/` | Concrete probe definitions (e.g. TOML files) and probe-specific helpers if needed. | Generic runner policy, global CLI routing. |
| `platform/` | OS and runtime differences: process spawning, PTY vs ConPTY, paths, env. | Probe semantics, report format fields. |

## Ownership rules

1. **Specs live in `dsl/` and `probes/`**: `dsl/` defines how specs are found and validated; `probes/` holds the actual probe content the harness loads.
2. **Execution policy lives in `runner/`**: what to run, in what order, and how results are aggregated—without embedding platform details beyond calls into `platform/`.
3. **Observations are modeled in `capture/`**: modes and observation records; `runner/` selects modes and passes them through.
4. **Outputs are finalized in `report/`**: stable paths and file shapes; `runner/` supplies data, not layout policy.
5. **`platform/` is the only place** for OS-specific terminal and process APIs used by the harness.

## Phase-1 boundary

Phase 1 implements seams and stubs: CLI, discovery/validation, run/capture/report scaffolding, and seed probes. Deep terminal automation and full platform coverage are explicitly out of scope until later milestones.
