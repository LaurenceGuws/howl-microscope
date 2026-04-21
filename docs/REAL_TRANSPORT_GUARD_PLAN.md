# Real transport guard plan (PH1-M6)

This document defines guardrails for introducing **real** terminal transport (PTY / ConPTY and related I/O) into Howl Microscope without weakening deterministic artifacts or safety defaults.

## Objectives

- Allow a **named** transport mode (`pty_guarded`) to exist in the harness **before** any production PTY data plane ships.
- Require **explicit human or automation opt-in** before guarded transport paths execute (fail-closed otherwise).
- Keep **default** transport mode **`none`** so casual runs never imply a real session.
- Record **guarded state** in `run.json` so reports and compares remain auditable.

## Threat model (abuse and accidents)

| Risk | Mitigation (PH1-M6) |
|------|---------------------|
| Unintended PTY or child process creation | No real PTY open in PH1-M6; scaffolding only. Later: single gate function, tests, and smoke checks. |
| Credential or environment leakage into terminal | Defer to future milestone; document that real transport must reuse least-privilege and sanitized env policies. |
| Nondeterministic artifacts | Guarded mode still uses deterministic stub handshake/latency in reports until a real handshake is specified. |
| CI or scripts accidentally enabling transport | Opt-in only via dedicated flag **or** explicit env (`ANA_TERM_ALLOW_GUARDED_TRANSPORT=1`); default remains off. |

## Boundaries for PH1-M6

**In scope**

- `transport_mode` value `pty_guarded` in code and CLI.
- Preflight that **refuses** `pty_guarded` unless opt-in is present.
- `run.json` fields describing guarded opt-in and scaffold state (`scaffold_only`).
- Schema validation and compare metadata for those fields.
- Smoke documentation for negative (rejected) and positive (allowed) invocations.

**Out of scope**

- Opening a real PTY or attaching to a live terminal process.
- Resize, signal, or clipboard integration.
- Cross-platform ConPTY-specific behavior.

## Opt-in contract

- **Flag:** `--allow-guarded-transport` (boolean; documented in `docs/CLI.md`).
- **Environment:** `ANA_TERM_ALLOW_GUARDED_TRANSPORT=1` (exact string; documented in `docs/CLI.md`).

Either satisfies preflight when `--transport pty_guarded` is selected. Absent both, the harness exits with validation failure (exit code **2**) before writing run artifacts.

## Future work (post PH1-M6)

- Replace `guarded_state: scaffold_only` with state machine values as the real transport is implemented.
- Add integration tests that assert no PTY fd is created when mode is `none` or `pty_stub`.
- Align with `docs/TRANSPORT_PLAN.md` and `docs/Vision.md` for promotion criteria to minimal real PTY experiments.
