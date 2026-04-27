# Howl Microscope Active Queue

## Current State

Test framework and validation harness for session/terminal integration testing.

## TH2 (Test Hygiene Phase 2)

| Ticket | Status | Intent |
| --- | --- | --- |
| `TH2-1` | done | Baseline test inventory (TEST_HYGIENE_MATRIX.md) |
| `TH2-2` | done | VS Code workflow normalization (.vscode/ config) |
| `TH2-3` | done | Platform gating verification (libc dependency gated) |

### Test Hygiene Resolution (THF-1)

- Pattern gate policy finalized: Exclude semantic `source_fallback` terminal profile type
- Validation command: `rg -n "compat[^ib]|workaround|shim" --glob '*.zig' src` (fallback excluded)
- Rationale: `source_fallback` is domain enum-like value, not code workaround rule

### Known Intentional Limits

- No executable test declarations (file collection inventory only)
- Integration testing deferred (end-to-end session validation)
- Component tests require full build context
- Direct-file testing not applicable
- Semantic terminal source type uses "fallback" terminology (allowed, documented)

## TH (Test Hygiene) Closeout

**Phase complete.** Package-context test authority: `zig build test` (file collection inventory, no executable tests). Known intentional limits: file collection only (no assertions executed), integration testing deferred.

## Guardrail

- One ticket per commit
- Mandatory validation per ticket:
  - `zig build`
  - `zig build test`
  - No forbidden rules
