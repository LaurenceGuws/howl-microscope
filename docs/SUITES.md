# Suites

Named suites map to **manifest files** that list probe specs (paths to `.toml` files) in run order.

## `baseline-linux`

- **Purpose**: First cross-terminal comparison lane on Linux using the shared smoke probes.
- **Manifest path**: `examples/smoke/baseline-linux.txt`
- **Format**: One path per line, UTF-8. Lines starting with `#` are comments. Empty lines ignored. Paths are relative to the repository root (or cwd when resolved).
- **Probes**: Defaults to the five files under `probes/smoke/` (reset, cursor, alt-screen, truecolor, input placeholder).

## Resolution rules

1. Strip comments and whitespace.
2. Reject duplicate paths after normalization.
3. Each entry must end with `.toml` and exist when the suite runs (validation error otherwise).

## `run-suite`

```text
howl-microscope run-suite baseline-linux [flags...]
```

Flags match `run` for terminal targeting (`--terminal`, `--terminal-cmd`, `--platform`, `--capture`) and are recorded in artifacts.
