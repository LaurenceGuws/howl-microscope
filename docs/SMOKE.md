# Smoke workflow (PH1-M2 through PH1-M39)

Minimal operator path: run the **baseline-linux** suite twice with **different terminal identities**, then produce one **compare** report (markdown + JSON). **PH1-M3** adds strict `report` / `compare` checks and metadata-rich compare output. **PH1-M4** adds **execution modes** (`placeholder` vs `protocol_stub`), **`--dry-run`**, and deterministic stub **observations**—use **Section 6** when touching the runner seam. **PH1-M5** adds **transport** metadata (`none` vs **`pty_stub`**) and **`--timeout-ms`**—use **Section 7**. **PH1-M6** adds guarded transport scaffolding—use **Section 8**. **PH1-M7** adds a minimal Linux PTY open/close experiment—use **Section 9** (Linux host only). **PH1-M8** adds deterministic telemetry for that experiment—use **Section 10**. **PH1-M9** adds host **`uname`** snapshots on the guarded experiment path—use **Section 11**. **PH1-M10** adds root **`host_identity_*`** fields on every artifact run—use **Section 12**. **PH1-M11** adds deterministic **`run_fingerprint_*`** fields—use **Section 13**. **PH1-M12** adds deterministic **`specset_fingerprint_*`** fields—use **Section 14**. **PH1-M13** adds deterministic **`resultset_fingerprint_*`** fields—use **Section 15**. **PH1-M14** adds deterministic root **`transport_fingerprint_*`** fields—use **Section 16**. **PH1-M15** adds deterministic root **`exec_summary_fingerprint_*`** fields—use **Section 17**. **PH1-M16** adds deterministic root **`context_summary_fingerprint_*`** fields—use **Section 18**. **PH1-M17** adds deterministic root **`metadata_envelope_fingerprint_*`** fields—use **Section 19**. **PH1-M18** adds deterministic root **`artifact_bundle_fingerprint_*`** fields—use **Section 20**. **PH1-M19** adds deterministic root **`report_envelope_fingerprint_*`** fields—use **Section 21**. **PH1-M20** adds deterministic root **`compare_envelope_fingerprint_*`** fields—use **Section 22**. **PH1-M21** adds deterministic root **`run_envelope_fingerprint_*`** fields—use **Section 23**. **PH1-M22** adds deterministic root **`session_envelope_fingerprint_*`** fields—use **Section 24**. **PH1-M23** adds deterministic root **`environment_envelope_fingerprint_*`** fields—use **Section 25**. **PH1-M24** adds deterministic root **`artifact_manifest_fingerprint_*`** fields—use **Section 26**. **PH1-M25** adds deterministic root **`provenance_envelope_fingerprint_*`** fields—use **Section 27**. **PH1-M26** adds deterministic root **`integrity_envelope_fingerprint_*`** fields—use **Section 28**. **PH1-M27** adds deterministic root **`consistency_envelope_fingerprint_*`** fields—use **Section 29**. **PH1-M28** adds deterministic root **`trace_envelope_fingerprint_*`** fields—use **Section 30**. **PH1-M29** adds deterministic root **`lineage_envelope_fingerprint_*`** fields—use **Section 31**. **PH1-M30** adds deterministic root **`state_envelope_fingerprint_*`** fields—use **Section 32**. **PH1-M33** adds **terminal profile** resolution (`--terminal` adapters, **`terminal_profile_id`**, **`terminal_cmd_source`**, **`resolved_terminal_cmd`**)—use **Section 33**. **PH1-M34** adds **executable argv templates** (**`resolved_terminal_argv`**, **`terminal_exec_template_id`**, **`terminal_exec_template_version`**) for known profiles—use **Section 34**. **PH1-M35** adds **launch preflight** evidence (**`terminal_exec_resolved_path`**, **`terminal_launch_preflight_ok`**, **`terminal_launch_preflight_reason`**) and transport fingerprint **v2** canonical lines for guarded launches—use **Section 35**. **PH1-M36** adds **`terminal_exec_resolved_path_normalization`**, **`realpath`** canonicalization policy, **reason↔ok** consistency checks in **`report`**, and transport fingerprint **v3**—use **Section 36**. **PH1-M37** adds **`terminal_launch_diagnostics_*`** envelope fields that capture normalized launch failure evidence (reason, elapsed_ms, signal) across preflight, spawn, and termination paths—use **Section 37**. **PH1-M38** adds **`terminal_launch_diagnostics_fingerprint_*`** fields that compose the diagnostics envelope into a deterministic SHA-256 digest for structured change comparison—use **Section 38**.

## Prerequisites

- From the repo root, build the harness: `zig build`.
- Use `zig-out/bin/howl-microscope` (or install the binary and use `howl-microscope` on `PATH`).
- After code changes, run unit tests: `zig build test`.

## 1. First run

Pick a logical terminal id (for example `wezterm`). Artifacts land under `artifacts/YYYY-MM-DD/run-NNN/`.

```sh
zig-out/bin/howl-microscope run-suite baseline-linux --terminal wezterm
```

Note the printed run directory (or locate the newest `artifacts/*/run-*`).

## 2. Second run

Use a **different** `--terminal` value so metadata differs (for example `alacritty`). Optionally set `--terminal-cmd` to record how you would launch that terminal later.

```sh
zig-out/bin/howl-microscope run-suite baseline-linux --terminal alacritty --terminal-cmd "alacritty -e"
```

Again note the second run directory.

## 3. Compare

Point `compare` at each run’s `run.json` (or at the run directory; the command resolves `run.json` inside it).

```sh
zig-out/bin/howl-microscope compare path/to/first/run.json path/to/second/run.json
```

Outputs:

- `artifacts/compare/compare.md` — metadata table (terminal, suite, etc.), paths, then per-spec deltas.
- `artifacts/compare/compare.json` — `schema_version` **0.2** with `metadata_deltas` plus per-spec `deltas`.

## 4. Report validation (PH1-M3)

Schema-check a `run.json` (path to file or run directory):

```sh
zig-out/bin/howl-microscope report path/to/run-NNN
```

Expect `ok: validated …` and exit **0**. Malformed or incomplete JSON should exit **2** with a short schema reason on stderr (see `docs/REPORT_FORMAT.md`).

## 5. Compare expectations (PH1-M3)

- Each side must have a **unique** `spec_id` in `results`. Duplicate rows in one file should fail with `duplicate spec_id in results` and exit **2**.
- Rows must include string `spec_id` and `status`. Missing fields fail compare with exit **2**.

## 6. Protocol-stub regression (PH1-M4)

- **Dry-run** (validate + plan only; **no** artifact directory):

```sh
zig-out/bin/howl-microscope run-suite baseline-linux --dry-run
```

Expect `dry-run: ok, planned N spec(s)` and exit **0**.

- **Protocol stub** run (writes `run.json` with `execution_mode: protocol_stub` and non-empty deterministic `observations` per spec):

```sh
zig-out/bin/howl-microscope run-suite baseline-linux --exec-mode protocol_stub --terminal wezterm
```

Then `report` on that run directory must exit **0**.

- **Metadata compare**: run the suite once with default **`placeholder`** (omit `--exec-mode`) and once with **`--exec-mode protocol_stub`** (same or different `--terminal` as you like). Run **`compare`** on the two `run.json` paths. In **`compare.md`**, the **`execution_mode`** metadata row should show **`changed`** (and the same appears under **`metadata_deltas`** in **`compare.json`**).

## 7. Transport-stub regression (PH1-M5)

- **Default (`none`)**: omit **`--transport`** (or pass **`--transport none`**). `run.json` includes a **`transport`** object with `mode: none`, `handshake: null`, `handshake_latency_ns: 0`, and `timeout_ms` from defaults (see **`docs/CLI.md`**).

- **Stub transport** (still **no** real PTY; see **`docs/TRANSPORT_PLAN.md`**):

```sh
zig-out/bin/howl-microscope run-suite baseline-linux --transport pty_stub --timeout-ms 8000 --terminal wezterm
```

Expect `report` **0**; `transport.handshake` is a fixed stub string, `handshake_latency_ns` is deterministic from the run id.

- **Compare**: run once with **`none`** and once with **`pty_stub`** (same suite). **`compare`** metadata should show **`transport_mode`** (and related **`transport_*`** rows) as **changed**.

## 8. Guarded transport scaffolding (PH1-M6)

Still **no** real PTY; see **`docs/REAL_TRANSPORT_GUARD_PLAN.md`**.

- **Fail closed (negative)**: guarded mode without opt-in must exit **2** before writing artifacts:

```sh
zig-out/bin/howl-microscope run-suite baseline-linux --transport pty_guarded --terminal wezterm
```

- **Explicit opt-in (positive)**: pass **`--allow-guarded-transport`** or set **`HOWL_MICROSCOPE_ALLOW_GUARDED_TRANSPORT=1`**:

```sh
zig-out/bin/howl-microscope run-suite baseline-linux --transport pty_guarded --allow-guarded-transport --terminal wezterm
```

- **Dry-run**: add **`--dry-run`** to the opt-in command above. Exit **0**; no artifact directory is created.

- **Full run (Linux)**: omit **`--dry-run`**. After the run, **`report`** on the artifact directory exits **0**. In **`run.json`**, **`guarded_state`** is **`experiment_linux_pty`**, **`pty_experiment_open_ok`** is **`true`** (or **`false`** with **`pty_experiment_error`** set on failure), **`pty_capability_notes`** describes the POSIX path, and **PH1-M8** adds **`pty_experiment_attempt`** (**`1`**) and **`pty_experiment_elapsed_ns`** (non-negative wall time; see **Section 10**).

- **Compare**: run once with **`pty_stub`** and once with **`pty_guarded`** (with opt-in). Metadata should include **`guarded_opt_in`**, **`guarded_state`**, and **`pty_experiment_*`** (including attempt/elapsed) deltas alongside transport rows.

## 9. Guarded Linux PTY experiment (PH1-M7)

**Host must be Linux** (see **`docs/PTY_EXPERIMENT_PLAN.md`**). On non-Linux, a full **`pty_guarded`** run (without **`--dry-run`**) exits **2** before artifacts.

- **Negative (non-Linux or no opt-in)**: unchanged from **Section 8**; non-Linux full runs fail at preflight.

- **Positive (Linux, opt-in, full run)**:

```sh
zig-out/bin/howl-microscope run-suite baseline-linux --transport pty_guarded --allow-guarded-transport --terminal wezterm
```

Confirm with **`report`** on the run directory. Inspect **`transport.guarded_state`** and **`pty_experiment_open_ok`** in **`run.json`**.

## 10. PH1-M8 hardened PTY telemetry (Linux)

Same commands as **Section 9**. After a successful full run, open **`run.json`** and verify:

- **`pty_experiment_attempt`** is **`1`**.
- **`pty_experiment_elapsed_ns`** is present, non-negative, and fits a signed JSON integer (harness clamps if needed).
- Transport keys follow the lexicographic order documented in **`docs/REPORT_FORMAT.md`**.

**Compare**: two guarded full runs on the same host may show **`changed`** on **`pty_experiment_elapsed_ns`** (wall time); **`pty_experiment_attempt`** should remain **`1`** for both.

See **`docs/PTY_EXPERIMENT_HARDENING_PLAN.md`**.

## 11. PH1-M9 PTY host reproducibility snapshot (Linux)

Use the same full **`pty_guarded`** command as **Sections 9–10** (Linux host, opt-in, **no** **`--dry-run`**). After **`report`** exits **0**, open **`run.json`** → **`transport`** and verify:

- **`pty_experiment_host_machine`** and **`pty_experiment_host_release`** are **non-empty strings** (truncated snapshots from **`uname`** on the experiment path).
- **`--dry-run`** with opt-in still yields **`guarded_state`**: **`scaffold_only`** and both host fields **`null`**.
- Transport keys follow the lexicographic order in **`docs/REPORT_FORMAT.md`** (host fields immediately after **`pty_experiment_error`**, before **`pty_experiment_open_ok`**).

**Compare**: two full guarded runs on the same host should normally show **`unchanged`** for **`pty_experiment_host_machine`** and **`pty_experiment_host_release`** in **`compare.md`** / **`metadata_deltas`** in **`compare.json`** (unless the kernel identity changed between runs).

See **`docs/PTY_REPRODUCIBILITY_PLAN.md`**.

## 12. PH1-M10 root host identity (artifact runs)

After any full **`run-suite`** (or **`run`**) that writes **`run.json`** (**not** **`--dry-run`**), run **`report`** on the artifact directory and confirm exit **0**. Open **`run.json`** and verify root-level:

- **`host_identity_machine`**, **`host_identity_release`**, **`host_identity_sysname`** — non-empty strings (runtime **`uname`** snapshots; JSON-escaped).
- Serialization order: immediately after **`execution_mode`**, before **`transport`** (see **`docs/REPORT_FORMAT.md`**).

**Compare**: two runs on the same machine should normally show **`unchanged`** for these three metadata rows unless the kernel identity changed.

See **`docs/HOST_IDENTITY_PLAN.md`**.

## 13. PH1-M11 run fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`run_fingerprint_digest`**: **64** lowercase hex characters.
- **`run_fingerprint_version`**: **`1`**.
- Serialization order: after **`host_identity_sysname`**, before **`transport`** (see **`docs/REPORT_FORMAT.md`**).

**Compare**: identical runs (same **`run_id`**, suite, and ordered **`spec_id`** list, same host identity context) should yield the same digest; changing any canonical input should change **`run_fingerprint_digest`**.

See **`docs/RUN_FINGERPRINT_PLAN.md`**.

## 14. PH1-M12 spec-set fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`specset_fingerprint_digest`**: **64** lowercase hex characters.
- **`specset_fingerprint_version`**: **`1`**.
- Serialization order: after **`run_fingerprint_version`**, before **`transport`** (see **`docs/REPORT_FORMAT.md`**).

**Compare**: two runs with the same **suite label** (or both absent) and the same **ordered `spec_id` list** should yield the same **`specset_fingerprint_digest`**; reordering probes or changing the suite string should change the digest. **`metadata_deltas`** should include **`specset_fingerprint_digest`** when left and right digests differ.

See **`docs/SPECSET_FINGERPRINT_PLAN.md`**.

## 15. PH1-M13 results-set fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`resultset_fingerprint_digest`**: **64** lowercase hex characters.
- **`resultset_fingerprint_version`**: **`1`**.
- Serialization order: after **`specset_fingerprint_version`**, before root **`transport_fingerprint_*`**, root **`exec_summary_fingerprint_*`**, root **`context_summary_fingerprint_*`**, and the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: two runs with the same **ordered `results` rows** (same **`spec_id`**, **`status`**, **`capture_mode`**, and **`notes`** per row) should yield the same **`resultset_fingerprint_digest`**; changing status, notes, capture mode, or row order should change the digest. **`metadata_deltas`** should include **`resultset_fingerprint_digest`** when left and right digests differ.

See **`docs/RESULTSET_FINGERPRINT_PLAN.md`**.

## 16. PH1-M14 transport fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`transport_fingerprint_digest`**: **64** lowercase hex characters.
- **`transport_fingerprint_version`**: **`1`**.
- Serialization order: after **`resultset_fingerprint_version`**, before root **`exec_summary_fingerprint_*`**, root **`context_summary_fingerprint_*`**, and the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: identical **effective transport configuration** (mode, timeout, guarded flags, handshake/latency inputs, and guarded PTY snapshot fields when applicable) and the same **`run_id`** should yield the same **`transport_fingerprint_digest`**; changing mode, timeout, stub latency inputs, or guarded experiment fields should change the digest. **`metadata_deltas`** should include **`transport_fingerprint_digest`** when left and right digests differ.

See **`docs/TRANSPORT_FINGERPRINT_PLAN.md`**.

## 17. PH1-M15 execution-summary fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`exec_summary_fingerprint_digest`**: **64** lowercase hex characters.
- **`exec_summary_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`transport_fingerprint_version`**, before root **`context_summary_fingerprint_*`** and the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: two runs whose **execution-shaping inputs** match the canonical payload (for example same **`execution_mode`**, **`strict`**, **`platform`**, **`capture_mode`**, **`terminal`**, optional labels, **`transport.mode`**, and **`transport.timeout_ms`**) should yield the same **`exec_summary_fingerprint_digest`**; toggling **`--strict`**, changing **`--exec-mode`**, changing **`--terminal`**, or changing transport mode/timeout should change the digest when those fields diverge. **`metadata_deltas`** should include **`exec_summary_fingerprint_digest`** when left and right digests differ.

See **`docs/EXEC_SUMMARY_FINGERPRINT_PLAN.md`**.

## 18. PH1-M16 context-summary fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`context_summary_fingerprint_digest`**: **64** lowercase hex characters.
- **`context_summary_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`exec_summary_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: two runs whose **context canonical inputs** match (same root **`term`** as recorded, same **`terminal_cmd`**, same **`allow_guarded_transport`** / env gate, and same **`host_identity_*`** snapshot strings) should yield the same **`context_summary_fingerprint_digest`**; changing **`TERM`**, changing **`--terminal-cmd`**, toggling guarded opt-in, or changing host identity fields should change the digest when those inputs diverge. **`metadata_deltas`** should include **`context_summary_fingerprint_digest`** when left and right digests differ.

See **`docs/CONTEXT_SUMMARY_FINGERPRINT_PLAN.md`**.

## 19. PH1-M17 metadata-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`metadata_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical ordered stack of the six upstream root digests plus literal **`1`** version lines; see **`docs/METADATA_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`metadata_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`context_summary_fingerprint_version`**, before root **`artifact_bundle_fingerprint_*`** and the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when any upstream root digest (**`run`**, **`specset`**, **`resultset`**, **`transport`**, **`exec_summary`**, or **`context_summary`**) differs between runs, **`metadata_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`metadata_envelope_fingerprint_digest`** when left and right digests differ.

See **`docs/METADATA_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 20. PH1-M18 artifact-bundle fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`artifact_bundle_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over **`metadata_envelope_fingerprint_digest`** plus the phase-1 companion artifact manifest; see **`docs/ARTIFACT_BUNDLE_FINGERPRINT_PLAN.md`**).
- **`artifact_bundle_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`metadata_envelope_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`metadata_envelope_fingerprint_digest`** differs, **`artifact_bundle_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`artifact_bundle_fingerprint_digest`** when left and right digests differ.

See **`docs/ARTIFACT_BUNDLE_FINGERPRINT_PLAN.md`**.

## 21. PH1-M19 report-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`report_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`artifact_bundle_fingerprint_digest`** to the phase-1 report contract tag; see **`docs/REPORT_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`report_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`artifact_bundle_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`artifact_bundle_fingerprint_digest`** differs, **`report_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`report_envelope_fingerprint_digest`** (and **`report_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/REPORT_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 22. PH1-M20 compare-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`compare_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`report_envelope_fingerprint_digest`** to the phase-1 compare contract tag; see **`docs/COMPARE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`compare_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`report_envelope_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`report_envelope_fingerprint_digest`** differs, **`compare_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`compare_envelope_fingerprint_digest`** (and **`compare_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/COMPARE_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 23. PH1-M21 run-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`run_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`compare_envelope_fingerprint_digest`** to the phase-1 run contract tag; see **`docs/RUN_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`run_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`compare_envelope_fingerprint_version`**, before root **`session_envelope_fingerprint_*`** and the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`compare_envelope_fingerprint_digest`** differs, **`run_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`run_envelope_fingerprint_digest`** (and **`run_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/RUN_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 24. PH1-M22 session-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`session_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`run_envelope_fingerprint_digest`** to the phase-1 session contract tag; see **`docs/SESSION_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`session_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`run_envelope_fingerprint_version`**, before root **`environment_envelope_fingerprint_*`** and the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`run_envelope_fingerprint_digest`** differs, **`session_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`session_envelope_fingerprint_digest`** (and **`session_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/SESSION_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 25. PH1-M23 environment-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`environment_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`session_envelope_fingerprint_digest`** to the phase-1 environment contract tag; see **`docs/ENVIRONMENT_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`environment_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`session_envelope_fingerprint_version`**, before root **`artifact_manifest_fingerprint_*`** and the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`session_envelope_fingerprint_digest`** differs, **`environment_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`environment_envelope_fingerprint_digest`** (and **`environment_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/ENVIRONMENT_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 26. PH1-M24 artifact-manifest fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`artifact_manifest_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`environment_envelope_fingerprint_digest`** to the phase-1 artifact-manifest contract tag; see **`docs/ARTIFACT_MANIFEST_FINGERPRINT_PLAN.md`**).
- **`artifact_manifest_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`environment_envelope_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`environment_envelope_fingerprint_digest`** differs, **`artifact_manifest_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`artifact_manifest_fingerprint_digest`** (and **`artifact_manifest_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/ARTIFACT_MANIFEST_FINGERPRINT_PLAN.md`**.

## 27. PH1-M25 provenance-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`provenance_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`artifact_manifest_fingerprint_digest`** to the phase-1 provenance contract tag; see **`docs/PROVENANCE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`provenance_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`artifact_manifest_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`artifact_manifest_fingerprint_digest`** differs, **`provenance_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`provenance_envelope_fingerprint_digest`** (and **`provenance_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/PROVENANCE_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 28. PH1-M26 integrity-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`integrity_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`provenance_envelope_fingerprint_digest`** to the phase-1 integrity contract tag; see **`docs/INTEGRITY_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`integrity_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`provenance_envelope_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`provenance_envelope_fingerprint_digest`** differs, **`integrity_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`integrity_envelope_fingerprint_digest`** (and **`integrity_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/INTEGRITY_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 29. PH1-M27 consistency-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`consistency_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`integrity_envelope_fingerprint_digest`** to the phase-1 consistency contract tag; see **`docs/CONSISTENCY_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`consistency_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`integrity_envelope_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`integrity_envelope_fingerprint_digest`** differs, **`consistency_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`consistency_envelope_fingerprint_digest`** (and **`consistency_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/CONSISTENCY_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 30. PH1-M28 trace-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`trace_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`consistency_envelope_fingerprint_digest`** to the phase-1 trace contract tag; see **`docs/TRACE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`trace_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`consistency_envelope_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`consistency_envelope_fingerprint_digest`** differs, **`trace_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`trace_envelope_fingerprint_digest`** (and **`trace_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/TRACE_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 31. PH1-M29 lineage-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`lineage_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`trace_envelope_fingerprint_digest`** to the phase-1 lineage contract tag; see **`docs/LINEAGE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`lineage_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`trace_envelope_fingerprint_version`**, before root **`state_envelope_fingerprint_*`** and the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`trace_envelope_fingerprint_digest`** differs, **`lineage_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`lineage_envelope_fingerprint_digest`** (and **`lineage_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/LINEAGE_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 32. PH1-M30 state-envelope fingerprint (artifact runs)

After a full run that writes **`run.json`**, **`report`** must exit **0**. In **`run.json`** root metadata verify:

- **`state_envelope_fingerprint_digest`**: **64** lowercase hex characters (SHA-256 over the canonical payload binding **`lineage_envelope_fingerprint_digest`** to the phase-1 state contract tag; see **`docs/STATE_ENVELOPE_FINGERPRINT_PLAN.md`**).
- **`state_envelope_fingerprint_version`**: **`1`**.
- Serialization order: immediately after **`lineage_envelope_fingerprint_version`**, before the nested **`transport`** object (see **`docs/REPORT_FORMAT.md`**).

**Compare**: when **`lineage_envelope_fingerprint_digest`** differs, **`state_envelope_fingerprint_digest`** should differ. **`metadata_deltas`** should include **`state_envelope_fingerprint_digest`** (and **`state_envelope_fingerprint_version`** when applicable) when left and right values differ.

See **`docs/STATE_ENVELOPE_FINGERPRINT_PLAN.md`**.

## 33. PH1-M33 terminal profile adapters (multi-terminal compare)

Named terminals (**`kitty`**, **`ghostty`**, **`konsole`**, **`zide-terminal`**, case-insensitive) resolve to stable **`resolved_terminal_cmd`** values with **`terminal_cmd_source: profile`** and a non-null **`terminal_profile_id`**. Unknown names use **`terminal_cmd_source: fallback`** and **`resolved_terminal_cmd`** equal to the **`--terminal`** string.

- **Profile vs fallback**: run **`run-suite baseline-linux --terminal kitty`**, then **`run-suite baseline-linux --terminal alacritty`**. Each **`run.json`** must pass **`report`**. The kitty run should show **`terminal_cmd_source`** **`profile`** and **`terminal_profile_id`** **`kitty`**; the alacritty run should show **`fallback`** and a null **`terminal_profile_id`** (unless you override).

- **`--terminal-cmd`**: run with **`--terminal kitty --terminal-cmd "custom"`**. Expect **`terminal_cmd_source`** **`cli_override`**, **`resolved_terminal_cmd`** **`custom`**, and **`terminal_profile_id`** still **`kitty`**.

- **Compare**: **`compare`** the two **`run.json`** paths from a profile run and a fallback run. **`metadata_deltas`** should include **`terminal_cmd_source`**, **`resolved_terminal_cmd`**, and usually **`terminal_profile_id`** when those fields differ.

See **`docs/TERMINAL_PROFILE_ADAPTER_PLAN.md`**.

## 34. PH1-M34 executable profile templates (argv + template metadata)

Known **`--terminal`** profiles resolve to a deterministic **`resolved_terminal_argv`** (JSON array of strings) and, when the harness uses the built-in template, non-null **`terminal_exec_template_id`** / **`terminal_exec_template_version`** (currently **`1`**). **`resolved_terminal_cmd`** remains a space-joined summary of that argv.

- **Profile argv + template fields**: run **`run-suite baseline-linux --terminal kitty`** (or **`ghostty`**, **`konsole`**, **`zide-terminal`**). Each **`run.json`** must pass **`report`**. Expect non-empty **`resolved_terminal_argv`**, a matching **`terminal_exec_template_id`** for that profile, and **`terminal_exec_template_version`** **`1`**.

- **Fallback**: run **`--terminal alacritty`**. Expect **`resolved_terminal_argv`** with a single token matching the terminal name, **`terminal_exec_template_id`** and **`terminal_exec_template_version`** **`null`**.

- **CLI override**: **`--terminal kitty --terminal-cmd "custom"`** yields **`cli_override`**; argv reflects the split override string; template id/version are **`null`** when no built-in template applies to the override path.

- **Compare**: **`compare`** a profile **`run.json`** against a fallback **`run.json`**. **`metadata_deltas`** should include **`resolved_terminal_argv`**, **`terminal_exec_template_id`**, and **`terminal_exec_template_version`** when those fields differ.

See **`docs/TERMINAL_PROFILE_EXEC_TEMPLATE_PLAN.md`**.

## 35. PH1-M35 launch preflight (argv availability)

Before a guarded terminal spawn, the harness probes resolved **`argv[0]`** on Linux (**`PATH`** lookup or absolute path). **`run.json`** records **`terminal_exec_resolved_path`** (when resolved), boolean **`terminal_launch_preflight_ok`**, and **`terminal_launch_preflight_reason`** (**`na`**, **`ok`**, **`missing_executable`**, **`not_executable`**). When preflight fails, the run **does not** launch the terminal subprocess; artifacts still write and **`report`** must validate; exit code is **2** (see `docs/CLI.md`).

- **Happy path**: on Linux, run **`run-suite baseline-linux --terminal kitty`** (or another profile with a resolvable binary). Expect **`terminal_launch_preflight_ok`** **`true`**, **`terminal_launch_preflight_reason`** **`ok`**, and a non-null **`terminal_exec_resolved_path`** when the probe resolves a path. Root **`transport_fingerprint_version`** should be **`3`** on guarded paths that emit transport telemetry (PH1-M36+).

- **Compare**: **`compare`** two **`run.json`** files where preflight outcomes differ (for example **`ok`** vs **`missing_executable`**). **`metadata_deltas`** should include **`terminal_exec_resolved_path`**, **`terminal_launch_preflight_ok`**, and **`terminal_launch_preflight_reason`** when those fields differ.

See **`docs/LAUNCH_PREFLIGHT_PLAN.md`**.

## 36. PH1-M36 preflight strictness (normalization + reason fidelity)

When **`argv[0]`** resolves successfully on Linux, **`terminal_exec_resolved_path`** is **`realpath`**-canonicalized when possible (**`terminal_exec_resolved_path_normalization`**: **`canonical`**) or kept as the literal probe path (**`literal`**). **`report`** rejects inconsistent **`terminal_launch_preflight_ok`** / **`terminal_launch_preflight_reason`** pairs (for example **`true`** with **`missing_executable`**). **`transport_fingerprint_version`** **`3`** appends the normalization line to the canonical transport digest.

- **Report**: craft or capture a **`run.json`** and run **`report`** — invalid preflight combinations should exit **2** with a short reason.

- **Compare**: **`compare`** runs that differ only in **`canonical`** vs **`literal`** normalization (or path string) should list **`terminal_exec_resolved_path_normalization`** in **`metadata_deltas`** when that field differs.

See **`docs/LAUNCH_PREFLIGHT_STRICTNESS_PLAN.md`**.

## References

- Terminal flags and behavior: `docs/CLI.md`
- Suite contents: `docs/SUITES.md` and `examples/smoke/baseline-linux.txt`
- Comparison scope: `docs/COMPARE_PLAN.md`
- Run artifact fields: `docs/REPORT_FORMAT.md`
- Protocol execution seam: `docs/PROTO_EXEC_PLAN.md`
- Transport seam: `docs/TRANSPORT_PLAN.md`
- Guarded transport: `docs/REAL_TRANSPORT_GUARD_PLAN.md`
- Linux PTY experiment: `docs/PTY_EXPERIMENT_PLAN.md`
- PTY experiment hardening: `docs/PTY_EXPERIMENT_HARDENING_PLAN.md`
- PTY reproducibility (PH1-M9): `docs/PTY_REPRODUCIBILITY_PLAN.md`
- Host identity (PH1-M10): `docs/HOST_IDENTITY_PLAN.md`
- Run fingerprint (PH1-M11): `docs/RUN_FINGERPRINT_PLAN.md`
- Spec-set fingerprint (PH1-M12): `docs/SPECSET_FINGERPRINT_PLAN.md`
- Results-set fingerprint (PH1-M13): `docs/RESULTSET_FINGERPRINT_PLAN.md`
- Transport fingerprint (PH1-M14): `docs/TRANSPORT_FINGERPRINT_PLAN.md`
- Execution-summary fingerprint (PH1-M15): `docs/EXEC_SUMMARY_FINGERPRINT_PLAN.md`
- Context-summary fingerprint (PH1-M16): `docs/CONTEXT_SUMMARY_FINGERPRINT_PLAN.md`
- Metadata-envelope fingerprint (PH1-M17): `docs/METADATA_ENVELOPE_FINGERPRINT_PLAN.md`
- Artifact-bundle fingerprint (PH1-M18): `docs/ARTIFACT_BUNDLE_FINGERPRINT_PLAN.md`
- Report-envelope fingerprint (PH1-M19): `docs/REPORT_ENVELOPE_FINGERPRINT_PLAN.md`
- Compare-envelope fingerprint (PH1-M20): `docs/COMPARE_ENVELOPE_FINGERPRINT_PLAN.md`
- Run-envelope fingerprint (PH1-M21): `docs/RUN_ENVELOPE_FINGERPRINT_PLAN.md`
- Session-envelope fingerprint (PH1-M22): `docs/SESSION_ENVELOPE_FINGERPRINT_PLAN.md`
- Environment-envelope fingerprint (PH1-M23): `docs/ENVIRONMENT_ENVELOPE_FINGERPRINT_PLAN.md`
- Artifact-manifest fingerprint (PH1-M24): `docs/ARTIFACT_MANIFEST_FINGERPRINT_PLAN.md`
- Provenance-envelope fingerprint (PH1-M25): `docs/PROVENANCE_ENVELOPE_FINGERPRINT_PLAN.md`
- Integrity-envelope fingerprint (PH1-M26): `docs/INTEGRITY_ENVELOPE_FINGERPRINT_PLAN.md`
- Consistency-envelope fingerprint (PH1-M27): `docs/CONSISTENCY_ENVELOPE_FINGERPRINT_PLAN.md`
- Trace-envelope fingerprint (PH1-M28): `docs/TRACE_ENVELOPE_FINGERPRINT_PLAN.md`
- Lineage-envelope fingerprint (PH1-M29): `docs/LINEAGE_ENVELOPE_FINGERPRINT_PLAN.md`
- State-envelope fingerprint (PH1-M30): `docs/STATE_ENVELOPE_FINGERPRINT_PLAN.md`
- Terminal profile adapters (PH1-M33): `docs/TERMINAL_PROFILE_ADAPTER_PLAN.md`
- Executable profile templates (PH1-M34): `docs/TERMINAL_PROFILE_EXEC_TEMPLATE_PLAN.md`
- Launch preflight (PH1-M35): `docs/LAUNCH_PREFLIGHT_PLAN.md`
- Preflight strictness (PH1-M36): `docs/LAUNCH_PREFLIGHT_STRICTNESS_PLAN.md`
- Launch failure diagnostics (PH1-M37): `docs/LAUNCH_FAILURE_ENVELOPE_PLAN.md`
- Launch diagnostics fingerprint (PH1-M38): `docs/LAUNCH_DIAGNOSTICS_FINGERPRINT_PLAN.md`
