# Transport fingerprint (PH1-M14)

## Objective

Add a **deterministic transport fingerprint** to **`run.json` root** (alongside existing nested **`transport`** metadata) so integrity checks can compare the **effective transport configuration and experiment snapshot** without re-parsing nested objects.

## Boundaries

- **In scope**: SHA-256 over a documented canonical text; root fields **`transport_fingerprint_digest`** / **`transport_fingerprint_version`**; `report` + `compare` coverage.
- **Out of scope**: replacing or duplicating nested **`transport`** JSON; hashing TLS material; cross-host transport attestation.

## Field contract (root metadata)

| Key | Type | Rule |
|-----|------|------|
| `transport_fingerprint_digest` | string | **64** lowercase hex chars (SHA-256 of canonical payload). |
| `transport_fingerprint_version` | string | **`1`** (legacy), **`2`** (**PH1-M35**: preflight lines), or **`3`** (**PH1-M36**: path normalization line after preflight path). |

**Serialization order**: immediately after **`resultset_fingerprint_version`**, before the nested **`transport`** object: **`transport_fingerprint_digest`**, **`transport_fingerprint_version`** (lexicographic among these two keys).

## Canonical payload (version `2`, PH1-M35+)

Same as version **`1`**, except:

1. Literal prefix: `PH1-M14/transport/fp/v2` (replaces `v1`).

When **`mode`** is **`pty_guarded`**, after **`terminal_launch_outcome`** (line 14 in the v1 guarded appendix), append:

15. **`terminal_launch_preflight_ok`**: `true`, `false`, or literal `null`.
16. **`terminal_launch_preflight_reason`**: string body, or literal `null`.
17. **`terminal_exec_resolved_path`**: string body (resolved probe path), or literal `null`.

For **`none`** / **`pty_stub`**, the prefix is still **`v2`**; lines 8–17 are not appended (same shape as v1 non-guarded).

## Canonical payload (version `3`, PH1-M36+)

Same as version **`2`**, except:

1. Literal prefix: `PH1-M14/transport/fp/v3` (replaces `v2`).

When **`mode`** is **`pty_guarded`**, after line 17 (**`terminal_exec_resolved_path`**), append:

18. **`terminal_exec_resolved_path_normalization`**: `canonical`, `literal`, or literal `null`.

For **`none`** / **`pty_stub`**, the prefix is still **`v3`**; guarded-only lines 8–18 are not appended (same shape as v1 non-guarded).

## Canonical payload (version `1`)

UTF-8 lines, each terminated by `\n`, in order:

1. Literal prefix: `PH1-M14/transport/fp/v1`
2. Transport **`mode`** tag (`none`, `pty_stub`, or `pty_guarded`).
3. Root **`timeout_ms`** as decimal ASCII (same integer recorded under `transport.timeout_ms`).
4. Effective **`guarded_opt_in`** (`true` / `false`) — same boolean written under `transport.guarded_opt_in`.
5. Effective **`guarded_state`** string (`na`, `scaffold_only`, or `experiment_linux_pty`) — same value written under `transport.guarded_state`.
6. **Handshake token** line: stub/guarded handshake string when emitted, else the literal `null` (three ASCII characters).
7. **`handshake_latency_ns`** as decimal ASCII (same synthetic value as `transport.handshake_latency_ns`, including `run_id` coupling for stub modes).

When **`mode`** is **`pty_guarded`**, append these lines in order (mirroring harness emission for the guarded branch):

8. **`pty_capability_notes`**: string body, or literal `null`.
9. **`pty_experiment_attempt`**: decimal ASCII, or literal `null`.
10. **`pty_experiment_elapsed_ns`**: decimal ASCII, or literal `null`.
11. **`pty_experiment_error`**: string body, or literal `null`.
12. **`pty_experiment_host_machine`**: raw bytes from the harness buffer (not JSON-escaped), or literal `null` when scaffold-only omits host fields.
13. **`pty_experiment_host_release`**: raw bytes from the harness buffer, or literal `null` when scaffold-only omits host fields.
14. **`pty_experiment_open_ok`**: `true`, `false`, or literal `null`.

When **`mode`** is **`none`** or **`pty_stub`**, **do not** append lines 8–14 (canonical length reflects the smaller `transport` object).

Then **SHA-256**; emit **lowercase hex**.

## Risks

- **Guarded experiment variability**: wall-clock nanoseconds and OS-dependent PTY outcomes change the digest (by design).
- **Handshake latency coupling**: stub latency may depend on `run_id` exactly as in `transport_stub` — fingerprint must use the same `run_id` passed to `writeRun`.

## Acceptance checks

- `zig build` / `zig build test` pass.
- Same `RunContext` + `run_id` → identical **`transport_fingerprint_digest`**.
- **`report`** rejects non-64-hex or wrong version; **`compare`** surfaces digest/version rows.
