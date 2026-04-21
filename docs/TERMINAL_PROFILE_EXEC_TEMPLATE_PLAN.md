# Terminal profile executable launch templates (PH1-M34)

## Objective

Evolve PH1-M33 **profile adapters** from opaque **shell command strings** into **deterministic argv templates** so **`pty_guarded`** bounded launch uses direct **`exec`-style argv** where possible, with explicit **template identity** and **version** in artifacts for compare and validation.

## In-scope (PH1-M34-S1)

- Built-in profiles: **`kitty`**, **`ghostty`**, **`konsole`**, **`zide-terminal`** (same matching rules as PH1-M33: ASCII case-insensitive **`--terminal`**).
- **Resolution precedence** unchanged: **`--terminal-cmd`** \> **profile template** \> **fallback** (verbatim **`--terminal`** as a single argv element).
- **Guarded Linux** bounded launch: use **argv execution** when resolved; preserve **PH1-M31/32** telemetry and outcome taxonomy (`ok`, `nonzero_exit`, `signaled`, `timeout`, `spawn_failed`).

## Template model

Each profile maps to:

- **`terminal_exec_template_id`** — stable string id (e.g. `kitty_exec_v1`); **`null`** when the effective launch is not a built-in template (CLI override split or fallback-only).
- **`terminal_exec_template_version`** — harness revision for the template table; phase-1 value **`1`** when a template id is present.
- **`resolved_terminal_argv`** — JSON array of strings: the argv passed to the bounded launcher (non-empty when launch is attempted).
- **`resolved_terminal_cmd`** — retained as a **single-string summary** (ASCII **space-joined** argv) for backward compatibility with PH1-M33 consumers and fingerprints that key on a string.

**CLI override (`--terminal-cmd`)**: argv is formed by **simple ASCII whitespace splitting** (no full shell quoting). If splitting would overflow fixed caps, the harness **falls back** to a **single argv element** holding the full string, or to **shell execution** only when argv cannot be formed (documented fail-closed paths).

## Risks

- **Whitespace split** does not implement shell quoting; operators must avoid spaces inside a single argv token or accept single-token fallback.
- **Template flags** may differ by upstream terminal releases; bump **`terminal_exec_template_version`** or template id when defaults change.
- **PATH**: templates still assume the binary name is on **`PATH`**; missing binaries yield **`spawn_failed`** as today.

## Acceptance checks

- **`run.json`**: `resolved_terminal_argv`, `terminal_exec_template_id` (nullable), `terminal_exec_template_version` (when id set), plus existing PH1-M33 fields; **`report`** validation enforces shape and basic consistency.
- **`compare`**: metadata deltas include template fields when runs differ.
- **Unit tests**: profile argv materialization, CLI split / overflow, guarded launcher uses argv path.
- **Smoke**: operator can verify template-bearing vs fallback runs differ in **`resolved_terminal_argv`** / template fields.

## Non-goals (PH1-M34)

- Full POSIX shell tokenization for **`--terminal-cmd`**
- Per-distro absolute paths or `.desktop` parsing
- Windows/macOS template tables in this sprint
