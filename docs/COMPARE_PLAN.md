# PH1-M2 comparison plan

This document bounds the first **real terminal comparison lane** for Howl Microscope: same probe suite, multiple terminals on **one OS**, with comparable machine-readable and markdown outputs.

## Scope (PH1-M2)

- Run a **named suite** (`baseline-linux`) that resolves to a fixed list of probe specs.
- Launch or target at least **two distinct terminal identities** on the same platform (e.g. two different terminal emulators or two invocation modes recorded as separate targets).
- Emit **per-run artifacts** (`run.json`, `summary.md`, `env.json`) that include terminal identity, suite name, and optional **comparison grouping** metadata.
- Provide a **`compare` command** that ingests two `run.json` files and emits **markdown** and **JSON** summaries of deltas (status changes, added/removed specs, notes).

## Non-goals (PH1-M2)

- Full PTY/ConPTY automation for every escape sequence or interactive scenario.
- Screenshot, OCR, or pixel-based comparison.
- Cross-OS matrix (single OS only in this milestone).
- Rich TUI or live diff UI; output remains **text artifacts** only.

## Success criteria

- Operator can produce **two runs** (different `--terminal` / `--terminal-cmd` targets) and one **compare report** with deterministic JSON ordering.
- Docs and manifests (`docs/SUITES.md`, `examples/smoke/baseline-linux.txt`) describe the suite unambiguously.
