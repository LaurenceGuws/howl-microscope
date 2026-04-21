# Terminal launch semantics (PH1-M32)

## Objective

Harden **real terminal launch** telemetry so **`run.json`**, **`report`**, and **`compare`** expose a **small, explicit outcome taxonomy** that stays deterministic and operator-useful across **success**, **timeout**, **spawn failure**, **non-zero exit**, and **signal-terminated** paths.

## Boundaries

- **In scope**: documented outcome classes; stable string tags under **`transport.terminal_launch_outcome`**; consistent **`terminal_launch_ok`**, **`terminal_launch_error`**, and **`terminal_launch_exit_code`** relative to outcome; Linux bounded **`/bin/sh -c`** launch seam; schema validation and compare rows.
- **Out of scope**: capturing signal numbers in JSON (phase-1 uses outcome class **`signaled`** only); Windows/macOS launch; attaching to the child TTY or scraping UI.

## Outcome taxonomy

| `terminal_launch_outcome` | When |
|---------------------------|------|
| `ok` | Child exited normally (**`WIFEXITED`**) with status **0**. |
| `nonzero_exit` | Child exited normally with non-zero status. |
| `signaled` | Child terminated by a signal (**`WIFSIGNALED`**, including after **`SIGKILL`** from timeout). |
| `timeout` | Wall-clock budget (**`transport.timeout_ms`**) exhausted before a stable exit status was recorded; child **`SIGKILL`** and reap. |
| `spawn_failed` | Could not start the child (spawn / pre-exec / early parent error). |

## Field consistency (phase-1)

- **`terminal_launch_attempt`**: **`1`** when the launch lane ran; **`null`** when not applicable (scaffold, non-Linux, empty **`--terminal-cmd`**, etc.).
- **`terminal_launch_outcome`**: one of the tags above when **`attempt == 1`**; **`null`** when no attempt.
- **`terminal_launch_ok`**: **`true`** iff **`outcome == ok`**; **`false`** when **`attempt == 1`** and outcome is not **`ok`**; **`null`** when no attempt.
- **`terminal_launch_error`**: **`timeout`** or **`spawn_failed`** when outcome matches; otherwise **`null`** (including **`nonzero_exit`** and **`signaled`**).
- **`terminal_launch_exit_code`**: **`WEXITSTATUS`** when **`ok`** or **`nonzero_exit`**; **`null`** for **`timeout`**, **`spawn_failed`**, and **`signaled`** in phase-1.

## Risks

- **Shell and PATH**: **`nonzero_exit`** values depend on the command; outcome class stays stable; exit code varies.
- **Signal vs timeout**: both may **`SIGKILL`** the child; **`timeout`** is reserved for the harness deadline path before a clean exit status is known.

## Acceptance checks

- `zig build` / `zig build test` pass on Linux.
- **`report`** rejects **`run.json`** where outcome and companion fields disagree.
- **`compare`** includes **`terminal_launch_outcome`** in metadata diff rows.
