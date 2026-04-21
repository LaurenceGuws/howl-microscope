# Terminal profile adapter plan (PH1-M33)

## Objective

Provide **deterministic terminal profile adapters** so named local terminals resolve to **stable launch command strings** and **comparable metadata** in `run.json`, context fingerprints, and compare output—without inventing a full installation probe or VT data plane.

## In-scope terminals (PH1-M33-S1)

Canonical **`terminal_profile_id`** values (stable, lowercase, hyphenated where applicable):

| Profile ID | Default resolved command template |
|------------|-----------------------------------|
| `kitty` | `kitty` |
| `ghostty` | `ghostty` |
| `konsole` | `konsole` |
| `zide-terminal` | `zide-terminal` |

Matching is by **`--terminal`** identity string, **ASCII case-insensitive** against the profile id (and known aliases if listed in code). Unmatched names use the **fallback** path.

## Resolution precedence

1. **`--terminal-cmd`** (CLI override) — if non-empty, it is the **effective** command. Metadata records source **`cli_override`**. If `--terminal` still matches a known profile, **`terminal_profile_id`** is set for labeling; otherwise it is empty / null in artifacts.
2. **Profile adapter** — if no CLI override and `--terminal` matches a built-in profile, the **template** becomes the effective command. Source **`profile`**; **`terminal_profile_id`** is the canonical id above.
3. **Fallback** — effective command is the **`--terminal`** string verbatim (trimmed for storage caps). Source **`fallback`**; **`terminal_profile_id`** is empty.

Effective command is what the harness uses for **bounded real launch** (`/bin/sh -c …`) and for **context-summary fingerprint** `terminal_cmd` input.

## Artifacts

Root `run.json` fields (see `docs/REPORT_FORMAT.md`):

- **`terminal_profile_id`** — string or `null`
- **`terminal_cmd_source`** — `cli_override` \| `profile` \| `fallback`
- **`resolved_terminal_cmd`** — string (effective command; may be empty only in non-launch paths)

## Risks

- **False confidence**: a template is not proof the binary exists on `PATH`; launch telemetry still reports **`spawn_failed`** etc.
- **Naming drift**: terminals rename flags; adapters are versioned implicitly with the harness—document changes in release notes when templates change.
- **Case and aliases**: only documented matching rules are supported; exotic aliases belong in a later ticket.

## Acceptance checks

- Guarded Linux full run: after resolution, **effective command must be non-empty** (fail-closed unchanged in spirit).
- Compare: metadata deltas include new fields when left/right runs differ.
- Schema validation: rejects unknown **`terminal_cmd_source`** or inconsistent pairs as defined in `run_json_validate`.

## Non-goals (PH1-M33)

- Discovering install paths beyond fixed templates
- Per-distro package mapping
- Windows/macOS profile tables in this sprint
