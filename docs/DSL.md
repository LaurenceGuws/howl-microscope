# Probe spec DSL (TOML)

Phase-1 probe definitions are **TOML** files loaded by the harness. This document is the contract; the implementation in `src/dsl/` must reject invalid documents with actionable errors.

## Top-level keys

| Key | Required | Type | Rule |
|-----|----------|------|------|
| `id` | yes | string | Non-empty, stable identifier (e.g. dotted path). |
| `kind` | yes | string | One of: `vt_sequence`, `render_workload`, `input_probe`, `perf_probe` (see `src/probes/categories.zig`). |
| `title` | yes | string | Human-readable title. |
| `tags` | no | array of string | Optional labels for filtering. |
| `setup` | no | table | Optional setup flags (see below). |
| `steps` | yes | array of tables | At least one step; each step has allowed keys per phase-1 rules. |
| `expect` | no | array of tables | Expectations (e.g. manual notes); phase-1 may require at least one for certain kinds. |
| `report` | no | table | Optional reporting hints (e.g. `severity`). |

### `setup` table (optional)

| Key | Type | Rule |
|-----|------|------|
| `reset` | bool | Default false if omitted. |
| `alt_screen` | bool | Default false if omitted. |
| `raw_mode` | bool | Default false if omitted. |

### `steps` entries

Each element is a table. Phase-1 requires at least one of:

| Key | Type | Rule |
|-----|------|------|
| `write` | string | Bytes to send (may use `\u001b` escapes in TOML). |

Additional keys may be reserved for future phases; unknown keys at step level should yield a validation warning or error per validator policy.

### `expect` entries (optional in phase-1 minimal form)

| Key | Type | Rule |
|-----|------|------|
| `type` | string | e.g. `manual_note`. |
| `prompt` | string | Text shown to the operator for manual verification. |

### `report` table (optional)

| Key | Type | Rule |
|-----|------|------|
| `severity` | string | e.g. `core`, `extended`. |

## Validation errors

The validator must report problems with:

- **File path** of the spec.
- **Field or array index** (e.g. `steps[0].write`, `id`).
- **Message** describing what is wrong and what is expected.

Categories:

- Missing required key.
- Wrong type for a key.
- Empty `id` or invalid `kind`.
- `steps` missing or empty.

## Canonical example

```toml
id = "smoke.cursor.example"
kind = "vt_sequence"
title = "Example cursor step"
tags = ["smoke", "vt"]

[setup]
reset = true
alt_screen = false
raw_mode = false

[[steps]]
write = "\u001b[2J\u001b[HHello"

[[steps]]
write = "\u001b[1A"

[[expect]]
type = "manual_note"
prompt = "Cursor moved up by one row"

[report]
severity = "core"
```
