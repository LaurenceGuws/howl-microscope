# Linux PTY experiment plan (PH1-M7)

This document bounds the **first minimal real PTY** work in Howl Microscope: open and close a POSIX pseudoterminal pair on Linux only, behind the existing **guarded transport** opt-in. No interactive workload, no child process attachment, no ConPTY.

## Goals

- Prove the harness can obtain a valid **master/slave PTY pair** on Linux using `/dev/ptmx`, `grantpt`, `unlockpt`, and a slave open.
- Record **auditable metadata** in `run.json` (`guarded_state`, open result, short capability notes).
- Preserve **fail-closed** behavior: no guarded PTY path without explicit opt-in; non-Linux hosts refuse the experiment early.

## Linux-first constraints

- **Host OS**: Real PTY experiment runs only when the **running process** reports `Linux` via `uname` (not the `--platform` flag, which is logical metadata for reports).
- **API surface**: POSIX-style `grantpt` / `unlockpt` / `ptsname_r` (or equivalent sequence) after opening `/dev/ptmx`.
- **Scope**: Single open → immediate close in the harness. No `fork`, no shell, no I/O loop.

## Safety boundaries

- **Opt-in unchanged**: `--allow-guarded-transport` or `ANA_TERM_ALLOW_GUARDED_TRANSPORT=1` remains mandatory for `--transport pty_guarded`.
- **Dry-run**: Does **not** open a PTY; `guarded_state` stays **`scaffold_only`** in artifacts.
- **Non-Linux**: Refuse `pty_guarded` real experiment with a clear validation error (exit **2**) before spec execution or artifact write.
- **Resource hygiene**: Both master and slave fds are closed before writing `run.json`, even on failure paths where partial open succeeded.

## Explicit non-goals (PH1-M7)

- **Windows / ConPTY** (tracked as out of scope for this sprint).
- **Screenshot, OCR, or pixel capture**.
- **TUI polish** or full-screen alternate buffer tests through a real PTY.
- **Resizing**, **signals**, **job control**, or **clipboard** integration.
- **Attaching** the PTY to a real terminal emulator process for bidirectional I/O.

## Reporting contract

- **`scaffold_only`**: Guarded transport selected but no PTY experiment executed (e.g. `--dry-run`).
- **`experiment_linux_pty`**: Non-dry-run guarded run on Linux attempted the minimal PTY open/close; see `transport.pty_experiment_*` fields in `docs/REPORT_FORMAT.md` and `docs/CLI.md`.

## Future work

- Optional child process + stub command injection behind the same gates.
- Capability matrix (e.g. `TIOCGWINSZ`) recorded as structured notes.
- macOS / BSD PTY paths once Linux path is stable.
