# Test Hygiene Baseline - Howl Microscope

## Overview

Test framework and validation harness for end-to-end session/terminal testing.

## Test Entrypoints

| Entrypoint | Status | Count | Classification |
| --- | --- | --- | --- |
| `zig build test` | ✓ builds | 0 executed | Package-aware; file collection only |
| Direct file `zig test src/tests_root.zig` | ✗ fails | - | Import context + libc dependency |

## Test Failure Classification

**Module-path/import-context**: Direct-file testing fails due to cross-module imports

**Dependency wiring**: 
- tests_root.zig uses `_ = @import(...)` rule (file collection, not unit tests)
- Actual tests in component files require build context

**libc/platform gating**: 
- `link_libc = true` in build.zig
- Tests depend on POSIX (PTY, process management)

**Test/assertion regressions**: 
- No actual test declarations found in tests_root.zig
- Test collection is inventory-only (no assertions executed)

## Direct-File Test Limitations

Not unit-testable directly. tests_root.zig is a file collection harness, not a test suite. Actual tests (if any) are in component modules and require full build context.

## Architecture Safety Notes

- No platform types in public APIs ✓
- libc dependency properly gated (build.zig linkLibC) ✓
- Component modules are integration-focused ✓

## Pattern Gate Policy (Repo-Local)

**Validation Command:**
```
rg -n "compat[^ib]|workaround|shim" --glob '*.zig' src
```

**Allowed Semantic Uses (excluded from gate):**
- `source_fallback` in terminal_profile.zig: Enum-like terminal command source type (not a code workaround)
- Context: Terminal profile resolution can fall back to default shell command source
- This is domain terminology, not a fallback code rule

## Known Intentional Limits

- Test count is 0 (no actual test declarations)
- No unit test assertions in tests_root.zig
- File collection only (inventory check)
- Direct-file testing not applicable
- Full integration testing (end-to-end session validation) deferred

## Status

Test infrastructure present but no executable tests yet. File collection serves as build-time compilation check only. Component testing deferred to integration harness phase. Pattern validation uses repo-local policy excluding semantic fallback uses.
