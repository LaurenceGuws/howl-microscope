# Howl Microscope Active Queue

## Current State

Test framework and validation harness for session/terminal integration testing.

## TH2 (Test Hygiene Phase 2)

| Ticket | Status | Intent |
| --- | --- | --- |
| `TH2-1` | done | Baseline test inventory (TEST_HYGIENE_MATRIX.md) |
| `TH2-2` | done | VS Code workflow normalization (.vscode/ config) |
| `TH2-3` | done | Platform gating verification (libc dependency gated) |

### Known Intentional Limits

- No executable test declarations (file collection inventory only)
- Integration testing deferred (end-to-end session validation)
- Component tests require full build context
- Direct-file testing not applicable

## Guardrail

- One ticket per commit
- Mandatory validation per ticket:
  - `zig build`
  - `zig build test`
  - No forbidden patterns
