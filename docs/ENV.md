# Environment contract (`env.json`)

Each run may emit `env.json` next to `run.json` under the run directory. It captures **portable launch context** so comparisons can explain *how* the terminal was targeted without embedding shell-specific secrets.

## Required fields (PH1-M2)

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | string | Format version (e.g. `0.1`). |
| `platform` | string | OS tag (`linux`, etc.). |
| `term` | string | Value of `TERM` when observed (or empty). |
| `terminal` | object | See below. |

## `terminal` object

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Logical id from `--terminal` (or `unknown`). |
| `version` | string | Reported terminal version when known; else empty. |
| `command` | string | Optional argv0 or full `--terminal-cmd` string for reproducibility. |

## Optional fields

| Field | Type | Description |
|-------|------|-------------|
| `comparison_id` | string | When set, links runs intended to be compared (see `docs/COMPARE_PLAN.md`). |
| `suite` | string | Suite name when run via `run-suite`. |

## Non-goals

- Storing API keys, raw PTY transcripts, or full process environments.
- Guaranteeing identical `env.json` across machines; the file is **hints plus identity**, not a reproducible container spec.
