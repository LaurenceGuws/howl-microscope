const std = @import("std");
const terminal_profile = @import("../runner/terminal_profile.zig");
const launch_preflight = @import("../runner/launch_preflight.zig");
const real_terminal_launch = @import("../runner/real_terminal_launch.zig");
const launch_diagnostics_canonical = @import("../runner/launch_diagnostics_canonical.zig");

/// Returns `null` if `root` satisfies the phase-1 `run.json` contract (`docs/REPORT_FORMAT.md` + harness output); otherwise a static error description.
pub fn validateRunReport(root: std.json.Value) ?[]const u8 {
    const obj = switch (root) {
        .object => |o| o,
        else => return "expected top-level JSON object",
    };

    if (getString(obj, "schema_version") == null) return "missing or invalid schema_version (string required)";
    if (getString(obj, "run_id") == null) return "missing or invalid run_id (string required)";
    if (getString(obj, "started_at") == null) return "missing or invalid started_at (string required)";
    if (getString(obj, "ended_at") == null) return "missing or invalid ended_at (string required)";
    if (getString(obj, "platform") == null) return "missing or invalid platform (string required)";
    if (getString(obj, "term") == null) return "missing or invalid term (string required)";

    const exec_m = getString(obj, "execution_mode") orelse return "missing or invalid execution_mode (string required)";
    if (!std.mem.eql(u8, exec_m, "placeholder") and !std.mem.eql(u8, exec_m, "protocol_stub")) {
        return "execution_mode must be placeholder or protocol_stub";
    }

    const tpid_o = obj.get("terminal_profile_id") orelse return "missing terminal_profile_id";
    switch (tpid_o) {
        .string, .null => {},
        else => return "terminal_profile_id must be a string or null",
    }
    const tcs = getString(obj, "terminal_cmd_source") orelse return "terminal_cmd_source must be a string";
    const src_ok = std.mem.eql(u8, tcs, terminal_profile.source_cli_override) or
        std.mem.eql(u8, tcs, terminal_profile.source_profile) or
        std.mem.eql(u8, tcs, terminal_profile.source_fallback);
    if (!src_ok) return "terminal_cmd_source must be cli_override, profile, or fallback";
    _ = getString(obj, "resolved_terminal_cmd") orelse return "resolved_terminal_cmd must be a string";

    const rta_o = obj.get("resolved_terminal_argv") orelse return "missing resolved_terminal_argv";
    switch (rta_o) {
        .array => |arr| {
            for (arr.items) |el| {
                switch (el) {
                    .string => |_| {},
                    else => return "resolved_terminal_argv must be an array of strings",
                }
            }
        },
        else => return "resolved_terminal_argv must be a JSON array",
    }

    const tex_id_o = obj.get("terminal_exec_template_id") orelse return "missing terminal_exec_template_id";
    switch (tex_id_o) {
        .string, .null => {},
        else => return "terminal_exec_template_id must be a string or null",
    }
    const tex_ver_o = obj.get("terminal_exec_template_version") orelse return "missing terminal_exec_template_version";
    switch (tex_id_o) {
        .null => switch (tex_ver_o) {
            .null => {},
            else => return "terminal_exec_template_version must be null when terminal_exec_template_id is null",
        },
        .string => {
            const ver = switch (tex_ver_o) {
                .string => |s| s,
                else => return "terminal_exec_template_version must be a string when terminal_exec_template_id is set",
            };
            if (!std.mem.eql(u8, ver, terminal_profile.exec_template_version)) return "terminal_exec_template_version must be 1";
        },
        else => return "terminal_exec_template_id must be a string or null",
    }

    const terp_o = obj.get("terminal_exec_resolved_path") orelse return "missing terminal_exec_resolved_path";
    switch (terp_o) {
        .string, .null => {},
        else => return "terminal_exec_resolved_path must be a string or null",
    }
    const ternorm_o = obj.get("terminal_exec_resolved_path_normalization") orelse return "missing terminal_exec_resolved_path_normalization";
    switch (ternorm_o) {
        .string => |s| {
            const n_ok = std.mem.eql(u8, s, launch_preflight.path_normalization_canonical) or
                std.mem.eql(u8, s, launch_preflight.path_normalization_literal);
            if (!n_ok) return "terminal_exec_resolved_path_normalization must be canonical or literal";
        },
        .null => {},
        else => return "terminal_exec_resolved_path_normalization must be a string or null",
    }
    const tlpok_o = obj.get("terminal_launch_preflight_ok") orelse return "missing terminal_launch_preflight_ok";
    switch (tlpok_o) {
        .bool, .null => {},
        else => return "terminal_launch_preflight_ok must be a boolean or null",
    }
    const tlpr_o = obj.get("terminal_launch_preflight_reason") orelse return "missing terminal_launch_preflight_reason";
    switch (tlpr_o) {
        .string => |s| {
            const tags_ok = std.mem.eql(u8, s, launch_preflight.reason_na) or
                std.mem.eql(u8, s, launch_preflight.reason_ok) or
                std.mem.eql(u8, s, launch_preflight.reason_missing_executable) or
                std.mem.eql(u8, s, launch_preflight.reason_not_executable);
            if (!tags_ok) return "terminal_launch_preflight_reason must be na, ok, missing_executable, or not_executable";
        },
        .null => {},
        else => return "terminal_launch_preflight_reason must be a string or null",
    }

    // PH1-M36: root preflight reason ↔ ok mutual constraints
    switch (tlpok_o) {
        .bool => |b| {
            if (b) {
                const rs = switch (tlpr_o) {
                    .string => |s| s,
                    else => return "terminal_launch_preflight_reason must be ok when terminal_launch_preflight_ok is true",
                };
                if (!std.mem.eql(u8, rs, launch_preflight.reason_ok)) return "terminal_launch_preflight_reason must be ok when terminal_launch_preflight_ok is true";
            } else {
                const rs = switch (tlpr_o) {
                    .string => |s| s,
                    else => return "terminal_launch_preflight_reason must be a string when terminal_launch_preflight_ok is false",
                };
                if (!(std.mem.eql(u8, rs, launch_preflight.reason_missing_executable) or
                    std.mem.eql(u8, rs, launch_preflight.reason_not_executable)))
                    return "terminal_launch_preflight_reason must be missing_executable or not_executable when terminal_launch_preflight_ok is false";
            }
        },
        .null => {
            switch (tlpr_o) {
                .null => {},
                .string => |s| {
                    if (!std.mem.eql(u8, s, launch_preflight.reason_na)) return "terminal_launch_preflight_reason must be null or na when terminal_launch_preflight_ok is null";
                },
                else => return "terminal_launch_preflight_reason must be null or na when terminal_launch_preflight_ok is null",
            }
        },
        else => unreachable,
    }
    switch (terp_o) {
        .null => {
            if (ternorm_o != .null) return "terminal_exec_resolved_path_normalization must be null when terminal_exec_resolved_path is null";
        },
        .string => {
            if (ternorm_o == .null) return "terminal_exec_resolved_path_normalization must be set when terminal_exec_resolved_path is set";
        },
        else => unreachable,
    }

    // PH1-M37: validate diagnostics envelope fields (optional for backward compatibility).
    // PH1-M39: enforce canonical forms for reason, elapsed, signal.
    const tld_reason_o = obj.get("terminal_launch_diagnostics_reason") orelse .null;
    switch (tld_reason_o) {
        .string => |s| {
            // PH1-M39: use canonicalization helper to validate reason.
            if (!launch_diagnostics_canonical.isValidCanonicalReason(s)) {
                return "terminal_launch_diagnostics_reason must be one of: ok, missing_executable, not_executable, spawn_failed, timeout, nonzero_exit, signaled";
            }
        },
        .null => {},
        else => return "terminal_launch_diagnostics_reason must be a string or null",
    }
    const tld_elapsed_o = obj.get("terminal_launch_diagnostics_elapsed_ms") orelse .null;
    switch (tld_elapsed_o) {
        .integer => |i| {
            // PH1-M39: enforce non-negative, within u32 range.
            if (i < 0) return "terminal_launch_diagnostics_elapsed_ms must be non-negative";
            if (i > @as(i64, @intCast(std.math.maxInt(u32)))) return "terminal_launch_diagnostics_elapsed_ms exceeds maximum";
        },
        .float => return "terminal_launch_diagnostics_elapsed_ms must be integer, not float",
        .null => {},
        else => return "terminal_launch_diagnostics_elapsed_ms must be a number or null",
    }
    const tld_signal_o = obj.get("terminal_launch_diagnostics_signal") orelse .null;
    switch (tld_signal_o) {
        .integer => |i| {
            // PH1-M39: enforce canonical signal range [1, 128].
            if (i < 1 or i > 128) return "terminal_launch_diagnostics_signal must be in range [1, 128]";
        },
        .null => {},
        else => return "terminal_launch_diagnostics_signal must be an integer or null",
    }

    // PH1-M38: validate launch diagnostics fingerprint fields (optional for backward compatibility).
    const ldf_digest_o = obj.get("terminal_launch_diagnostics_fingerprint_digest") orelse .null;
    switch (ldf_digest_o) {
        .string => |s| {
            if (s.len != 64) return "terminal_launch_diagnostics_fingerprint_digest must be exactly 64 characters";
            for (s) |c| {
                if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f'))) {
                    return "terminal_launch_diagnostics_fingerprint_digest must be lowercase hex";
                }
            }
        },
        .null => {},
        else => return "terminal_launch_diagnostics_fingerprint_digest must be a string or null",
    }
    const ldf_version_o = obj.get("terminal_launch_diagnostics_fingerprint_version") orelse .null;
    switch (ldf_version_o) {
        .string => |s| {
            if (!std.mem.eql(u8, s, "1")) return "terminal_launch_diagnostics_fingerprint_version must be \"1\" or null";
        },
        .null => {},
        else => return "terminal_launch_diagnostics_fingerprint_version must be a string or null",
    }
    // Invariant: both should be present or both absent
    const has_digest = ldf_digest_o != .null;
    const has_version = ldf_version_o != .null;
    if (has_digest != has_version) return "terminal_launch_diagnostics_fingerprint_digest and _version must both be present or both absent";

    const term_o = obj.get("terminal") orelse return "missing terminal object";
    const term_obj = switch (term_o) {
        .object => |t| t,
        else => return "terminal must be a JSON object",
    };
    if (getString(term_obj, "name") == null) return "terminal.name must be a string";

    const him = getString(obj, "host_identity_machine") orelse return "host_identity_machine must be a string";
    if (him.len == 0) return "host_identity_machine must be non-empty";
    const hir = getString(obj, "host_identity_release") orelse return "host_identity_release must be a string";
    if (hir.len == 0) return "host_identity_release must be non-empty";
    const his = getString(obj, "host_identity_sysname") orelse return "host_identity_sysname must be a string";
    if (his.len == 0) return "host_identity_sysname must be non-empty";

    const rfd = getString(obj, "run_fingerprint_digest") orelse return "run_fingerprint_digest must be a string";
    if (rfd.len != 64) return "run_fingerprint_digest must be 64 lowercase hex characters";
    for (rfd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "run_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const rfv = getString(obj, "run_fingerprint_version") orelse return "run_fingerprint_version must be a string";
    if (!std.mem.eql(u8, rfv, "1")) return "run_fingerprint_version must be 1";

    const sfd = getString(obj, "specset_fingerprint_digest") orelse return "specset_fingerprint_digest must be a string";
    if (sfd.len != 64) return "specset_fingerprint_digest must be 64 lowercase hex characters";
    for (sfd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "specset_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const sfv = getString(obj, "specset_fingerprint_version") orelse return "specset_fingerprint_version must be a string";
    if (!std.mem.eql(u8, sfv, "1")) return "specset_fingerprint_version must be 1";

    const rsd = getString(obj, "resultset_fingerprint_digest") orelse return "resultset_fingerprint_digest must be a string";
    if (rsd.len != 64) return "resultset_fingerprint_digest must be 64 lowercase hex characters";
    for (rsd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "resultset_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const rsv = getString(obj, "resultset_fingerprint_version") orelse return "resultset_fingerprint_version must be a string";
    if (!std.mem.eql(u8, rsv, "1")) return "resultset_fingerprint_version must be 1";

    const tfd = getString(obj, "transport_fingerprint_digest") orelse return "transport_fingerprint_digest must be a string";
    if (tfd.len != 64) return "transport_fingerprint_digest must be 64 lowercase hex characters";
    for (tfd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "transport_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const tfv = getString(obj, "transport_fingerprint_version") orelse return "transport_fingerprint_version must be a string";
    if (!std.mem.eql(u8, tfv, "1") and !std.mem.eql(u8, tfv, "2") and !std.mem.eql(u8, tfv, "3")) return "transport_fingerprint_version must be 1, 2, or 3";

    const esfd = getString(obj, "exec_summary_fingerprint_digest") orelse return "exec_summary_fingerprint_digest must be a string";
    if (esfd.len != 64) return "exec_summary_fingerprint_digest must be 64 lowercase hex characters";
    for (esfd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "exec_summary_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const esfv = getString(obj, "exec_summary_fingerprint_version") orelse return "exec_summary_fingerprint_version must be a string";
    if (!std.mem.eql(u8, esfv, "1")) return "exec_summary_fingerprint_version must be 1";

    const csfd = getString(obj, "context_summary_fingerprint_digest") orelse return "context_summary_fingerprint_digest must be a string";
    if (csfd.len != 64) return "context_summary_fingerprint_digest must be 64 lowercase hex characters";
    for (csfd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "context_summary_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const csfv = getString(obj, "context_summary_fingerprint_version") orelse return "context_summary_fingerprint_version must be a string";
    if (!std.mem.eql(u8, csfv, "1")) return "context_summary_fingerprint_version must be 1";

    const mefd = getString(obj, "metadata_envelope_fingerprint_digest") orelse return "metadata_envelope_fingerprint_digest must be a string";
    if (mefd.len != 64) return "metadata_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (mefd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "metadata_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const mefv = getString(obj, "metadata_envelope_fingerprint_version") orelse return "metadata_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, mefv, "1")) return "metadata_envelope_fingerprint_version must be 1";

    const abfd = getString(obj, "artifact_bundle_fingerprint_digest") orelse return "artifact_bundle_fingerprint_digest must be a string";
    if (abfd.len != 64) return "artifact_bundle_fingerprint_digest must be 64 lowercase hex characters";
    for (abfd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "artifact_bundle_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const abfv = getString(obj, "artifact_bundle_fingerprint_version") orelse return "artifact_bundle_fingerprint_version must be a string";
    if (!std.mem.eql(u8, abfv, "1")) return "artifact_bundle_fingerprint_version must be 1";

    const refd = getString(obj, "report_envelope_fingerprint_digest") orelse return "report_envelope_fingerprint_digest must be a string";
    if (refd.len != 64) return "report_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (refd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "report_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const refv = getString(obj, "report_envelope_fingerprint_version") orelse return "report_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, refv, "1")) return "report_envelope_fingerprint_version must be 1";

    const cefd = getString(obj, "compare_envelope_fingerprint_digest") orelse return "compare_envelope_fingerprint_digest must be a string";
    if (cefd.len != 64) return "compare_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (cefd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "compare_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const cefv = getString(obj, "compare_envelope_fingerprint_version") orelse return "compare_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, cefv, "1")) return "compare_envelope_fingerprint_version must be 1";

    const refd_run = getString(obj, "run_envelope_fingerprint_digest") orelse return "run_envelope_fingerprint_digest must be a string";
    if (refd_run.len != 64) return "run_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (refd_run) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "run_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const refv_run = getString(obj, "run_envelope_fingerprint_version") orelse return "run_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, refv_run, "1")) return "run_envelope_fingerprint_version must be 1";

    const sesd = getString(obj, "session_envelope_fingerprint_digest") orelse return "session_envelope_fingerprint_digest must be a string";
    if (sesd.len != 64) return "session_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (sesd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "session_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const sesv = getString(obj, "session_envelope_fingerprint_version") orelse return "session_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, sesv, "1")) return "session_envelope_fingerprint_version must be 1";

    const envd = getString(obj, "environment_envelope_fingerprint_digest") orelse return "environment_envelope_fingerprint_digest must be a string";
    if (envd.len != 64) return "environment_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (envd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "environment_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const envv = getString(obj, "environment_envelope_fingerprint_version") orelse return "environment_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, envv, "1")) return "environment_envelope_fingerprint_version must be 1";

    const amfd = getString(obj, "artifact_manifest_fingerprint_digest") orelse return "artifact_manifest_fingerprint_digest must be a string";
    if (amfd.len != 64) return "artifact_manifest_fingerprint_digest must be 64 lowercase hex characters";
    for (amfd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "artifact_manifest_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const amfv = getString(obj, "artifact_manifest_fingerprint_version") orelse return "artifact_manifest_fingerprint_version must be a string";
    if (!std.mem.eql(u8, amfv, "1")) return "artifact_manifest_fingerprint_version must be 1";

    const pefd = getString(obj, "provenance_envelope_fingerprint_digest") orelse return "provenance_envelope_fingerprint_digest must be a string";
    if (pefd.len != 64) return "provenance_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (pefd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "provenance_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const pefv = getString(obj, "provenance_envelope_fingerprint_version") orelse return "provenance_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, pefv, "1")) return "provenance_envelope_fingerprint_version must be 1";

    const iefd = getString(obj, "integrity_envelope_fingerprint_digest") orelse return "integrity_envelope_fingerprint_digest must be a string";
    if (iefd.len != 64) return "integrity_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (iefd) |c| {
        switch (c) {
            '0'...'9', 'a'...'f' => {},
            else => return "integrity_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const iefv = getString(obj, "integrity_envelope_fingerprint_version") orelse return "integrity_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, iefv, "1")) return "integrity_envelope_fingerprint_version must be 1";

    const cons_env_fd = getString(obj, "consistency_envelope_fingerprint_digest") orelse return "consistency_envelope_fingerprint_digest must be a string";
    if (cons_env_fd.len != 64) return "consistency_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (cons_env_fd) |ch| {
        switch (ch) {
            '0'...'9', 'a'...'f' => {},
            else => return "consistency_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const cons_env_fv = getString(obj, "consistency_envelope_fingerprint_version") orelse return "consistency_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, cons_env_fv, "1")) return "consistency_envelope_fingerprint_version must be 1";

    const trace_env_fd = getString(obj, "trace_envelope_fingerprint_digest") orelse return "trace_envelope_fingerprint_digest must be a string";
    if (trace_env_fd.len != 64) return "trace_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (trace_env_fd) |ch| {
        switch (ch) {
            '0'...'9', 'a'...'f' => {},
            else => return "trace_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const trace_env_fv = getString(obj, "trace_envelope_fingerprint_version") orelse return "trace_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, trace_env_fv, "1")) return "trace_envelope_fingerprint_version must be 1";

    const lin_env_fd = getString(obj, "lineage_envelope_fingerprint_digest") orelse return "lineage_envelope_fingerprint_digest must be a string";
    if (lin_env_fd.len != 64) return "lineage_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (lin_env_fd) |ch| {
        switch (ch) {
            '0'...'9', 'a'...'f' => {},
            else => return "lineage_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const lin_env_fv = getString(obj, "lineage_envelope_fingerprint_version") orelse return "lineage_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, lin_env_fv, "1")) return "lineage_envelope_fingerprint_version must be 1";

    const st_env_fd = getString(obj, "state_envelope_fingerprint_digest") orelse return "state_envelope_fingerprint_digest must be a string";
    if (st_env_fd.len != 64) return "state_envelope_fingerprint_digest must be 64 lowercase hex characters";
    for (st_env_fd) |ch| {
        switch (ch) {
            '0'...'9', 'a'...'f' => {},
            else => return "state_envelope_fingerprint_digest must be 64 lowercase hex characters",
        }
    }
    const st_env_fv = getString(obj, "state_envelope_fingerprint_version") orelse return "state_envelope_fingerprint_version must be a string";
    if (!std.mem.eql(u8, st_env_fv, "1")) return "state_envelope_fingerprint_version must be 1";

    const tr_o = obj.get("transport") orelse return "missing transport object";
    const tr = switch (tr_o) {
        .object => |t| t,
        else => return "transport must be a JSON object",
    };
    const tr_mode = getString(tr, "mode") orelse return "missing or invalid transport.mode (string required)";
    const mode_ok = std.mem.eql(u8, tr_mode, "none") or std.mem.eql(u8, tr_mode, "pty_stub") or std.mem.eql(u8, tr_mode, "pty_guarded");
    if (!mode_ok) {
        return "transport.mode must be none, pty_stub, or pty_guarded";
    }
    const timeout_ms = getInteger(tr, "timeout_ms") orelse return "transport.timeout_ms must be an integer";
    if (timeout_ms <= 0) return "transport.timeout_ms must be positive";

    const guarded_opt_in = getBool(tr, "guarded_opt_in") orelse return "transport.guarded_opt_in must be a boolean";
    const guarded_state = getString(tr, "guarded_state") orelse return "missing or invalid transport.guarded_state (string required)";

    if (std.mem.eql(u8, tr_mode, "none")) {
        if (guarded_opt_in) return "transport.guarded_opt_in must be false when mode is none";
        if (!std.mem.eql(u8, guarded_state, "na")) return "transport.guarded_state must be na when mode is none";
    } else if (std.mem.eql(u8, tr_mode, "pty_stub")) {
        if (guarded_opt_in) return "transport.guarded_opt_in must be false when mode is pty_stub";
        if (!std.mem.eql(u8, guarded_state, "na")) return "transport.guarded_state must be na when mode is pty_stub";
    } else {
        if (!guarded_opt_in) return "transport.guarded_opt_in must be true when mode is pty_guarded";
        const gs_ok = std.mem.eql(u8, guarded_state, "scaffold_only") or std.mem.eql(u8, guarded_state, "experiment_linux_pty");
        if (!gs_ok) return "transport.guarded_state must be scaffold_only or experiment_linux_pty when mode is pty_guarded";

        const po = tr.get("pty_experiment_open_ok") orelse return "missing transport.pty_experiment_open_ok";
        const pe = tr.get("pty_experiment_error") orelse return "missing transport.pty_experiment_error";
        const pn = tr.get("pty_capability_notes") orelse return "missing transport.pty_capability_notes";
        const p_att = tr.get("pty_experiment_attempt") orelse return "missing transport.pty_experiment_attempt";
        const p_el = tr.get("pty_experiment_elapsed_ns") orelse return "missing transport.pty_experiment_elapsed_ns";
        const p_hm = tr.get("pty_experiment_host_machine") orelse return "missing transport.pty_experiment_host_machine";
        const p_hr = tr.get("pty_experiment_host_release") orelse return "missing transport.pty_experiment_host_release";
        _ = tr.get("terminal_launch_attempt") orelse return "missing transport.terminal_launch_attempt";
        _ = tr.get("terminal_launch_elapsed_ns") orelse return "missing transport.terminal_launch_elapsed_ns";
        _ = tr.get("terminal_launch_error") orelse return "missing transport.terminal_launch_error";
        _ = tr.get("terminal_launch_exit_code") orelse return "missing transport.terminal_launch_exit_code";
        _ = tr.get("terminal_launch_ok") orelse return "missing transport.terminal_launch_ok";
        _ = tr.get("terminal_launch_outcome") orelse return "missing transport.terminal_launch_outcome";

        if (std.mem.eql(u8, guarded_state, "scaffold_only")) {
            switch (po) {
                .null => {},
                else => return "transport.pty_experiment_open_ok must be null when guarded_state is scaffold_only",
            }
            switch (pe) {
                .null => {},
                else => return "transport.pty_experiment_error must be null when guarded_state is scaffold_only",
            }
            switch (pn) {
                .null => {},
                else => return "transport.pty_capability_notes must be null when guarded_state is scaffold_only",
            }
            switch (p_att) {
                .null => {},
                else => return "transport.pty_experiment_attempt must be null when guarded_state is scaffold_only",
            }
            switch (p_el) {
                .null => {},
                else => return "transport.pty_experiment_elapsed_ns must be null when guarded_state is scaffold_only",
            }
            switch (p_hm) {
                .null => {},
                else => return "transport.pty_experiment_host_machine must be null when guarded_state is scaffold_only",
            }
            switch (p_hr) {
                .null => {},
                else => return "transport.pty_experiment_host_release must be null when guarded_state is scaffold_only",
            }
            switch (tr.get("terminal_launch_attempt") orelse return "missing transport.terminal_launch_attempt") {
                .null => {},
                else => return "transport.terminal_launch_attempt must be null when guarded_state is scaffold_only",
            }
            switch (tr.get("terminal_launch_elapsed_ns") orelse return "missing transport.terminal_launch_elapsed_ns") {
                .null => {},
                else => return "transport.terminal_launch_elapsed_ns must be null when guarded_state is scaffold_only",
            }
            switch (tr.get("terminal_launch_error") orelse return "missing transport.terminal_launch_error") {
                .null => {},
                else => return "transport.terminal_launch_error must be null when guarded_state is scaffold_only",
            }
            switch (tr.get("terminal_launch_exit_code") orelse return "missing transport.terminal_launch_exit_code") {
                .null => {},
                else => return "transport.terminal_launch_exit_code must be null when guarded_state is scaffold_only",
            }
            switch (tr.get("terminal_launch_ok") orelse return "missing transport.terminal_launch_ok") {
                .null => {},
                else => return "transport.terminal_launch_ok must be null when guarded_state is scaffold_only",
            }
            switch (tr.get("terminal_launch_outcome") orelse return "missing transport.terminal_launch_outcome") {
                .null => {},
                else => return "transport.terminal_launch_outcome must be null when guarded_state is scaffold_only",
            }
        } else {
            const open_ok = switch (po) {
                .bool => |b| b,
                else => return "transport.pty_experiment_open_ok must be a boolean when guarded_state is experiment_linux_pty",
            };
            const notes = getString(tr, "pty_capability_notes") orelse return "transport.pty_capability_notes must be a string for experiment_linux_pty";
            if (notes.len == 0) return "transport.pty_capability_notes must be non-empty for experiment_linux_pty";
            const att = getInteger(tr, "pty_experiment_attempt") orelse return "transport.pty_experiment_attempt must be an integer";
            if (att != 1) return "transport.pty_experiment_attempt must be 1";
            const elap = getInteger(tr, "pty_experiment_elapsed_ns") orelse return "transport.pty_experiment_elapsed_ns must be an integer";
            if (elap < 0) return "transport.pty_experiment_elapsed_ns must be non-negative";
            if (elap > std.math.maxInt(i64)) return "transport.pty_experiment_elapsed_ns out of range";
            if (open_ok) {
                switch (pe) {
                    .null => {},
                    else => return "transport.pty_experiment_error must be null when pty_experiment_open_ok is true",
                }
            } else {
                if (getString(tr, "pty_experiment_error") == null) return "transport.pty_experiment_error must be a string when pty_experiment_open_ok is false";
            }
            const host_m = getString(tr, "pty_experiment_host_machine") orelse return "transport.pty_experiment_host_machine must be a string when guarded_state is experiment_linux_pty";
            if (host_m.len == 0) return "transport.pty_experiment_host_machine must be non-empty for experiment_linux_pty";
            const host_r = getString(tr, "pty_experiment_host_release") orelse return "transport.pty_experiment_host_release must be a string when guarded_state is experiment_linux_pty";
            if (host_r.len == 0) return "transport.pty_experiment_host_release must be non-empty for experiment_linux_pty";

            const tl_att_o = tr.get("terminal_launch_attempt") orelse return "missing transport.terminal_launch_attempt";
            if (tl_att_o == .null) {
                switch (tr.get("terminal_launch_elapsed_ns") orelse return "missing transport.terminal_launch_elapsed_ns") {
                    .null => {},
                    else => return "transport.terminal_launch_elapsed_ns must be null when terminal_launch_attempt is null",
                }
                switch (tr.get("terminal_launch_error") orelse return "missing transport.terminal_launch_error") {
                    .null => {},
                    else => return "transport.terminal_launch_error must be null when terminal_launch_attempt is null",
                }
                switch (tr.get("terminal_launch_exit_code") orelse return "missing transport.terminal_launch_exit_code") {
                    .null => {},
                    else => return "transport.terminal_launch_exit_code must be null when terminal_launch_attempt is null",
                }
                switch (tr.get("terminal_launch_ok") orelse return "missing transport.terminal_launch_ok") {
                    .null => {},
                    else => return "transport.terminal_launch_ok must be null when terminal_launch_attempt is null",
                }
                switch (tr.get("terminal_launch_outcome") orelse return "missing transport.terminal_launch_outcome") {
                    .null => {},
                    else => return "transport.terminal_launch_outcome must be null when terminal_launch_attempt is null",
                }
            } else {
                const tl_att = switch (tl_att_o) {
                    .integer => |i| i,
                    else => return "transport.terminal_launch_attempt must be an integer or null",
                };
                if (tl_att != 1) return "transport.terminal_launch_attempt must be 1 when present";
                const tl_elap = getInteger(tr, "terminal_launch_elapsed_ns") orelse return "transport.terminal_launch_elapsed_ns must be an integer when terminal_launch_attempt is 1";
                if (tl_elap < 0) return "transport.terminal_launch_elapsed_ns must be non-negative";
                if (tl_elap > std.math.maxInt(i64)) return "transport.terminal_launch_elapsed_ns out of range";
                const tl_ok = switch (tr.get("terminal_launch_ok") orelse return "missing transport.terminal_launch_ok") {
                    .bool => |b| b,
                    else => return "transport.terminal_launch_ok must be a boolean when terminal_launch_attempt is 1",
                };
                const tl_ec_o = tr.get("terminal_launch_exit_code") orelse return "missing transport.terminal_launch_exit_code";
                const tl_err_o = tr.get("terminal_launch_error") orelse return "missing transport.terminal_launch_error";
                const oc = getString(tr, "terminal_launch_outcome") orelse return "transport.terminal_launch_outcome must be a string when terminal_launch_attempt is 1";
                const oc_ok = std.mem.eql(u8, oc, "ok") or std.mem.eql(u8, oc, "nonzero_exit") or std.mem.eql(u8, oc, "signaled") or std.mem.eql(u8, oc, "timeout") or std.mem.eql(u8, oc, "spawn_failed");
                if (!oc_ok) return "transport.terminal_launch_outcome must be ok, nonzero_exit, signaled, timeout, or spawn_failed";

                if (std.mem.eql(u8, oc, "ok")) {
                    if (!tl_ok) return "transport.terminal_launch_ok must be true when terminal_launch_outcome is ok";
                    switch (tl_ec_o) {
                        .integer => |i| {
                            if (i != 0) return "transport.terminal_launch_exit_code must be 0 when terminal_launch_outcome is ok";
                        },
                        else => return "transport.terminal_launch_exit_code must be an integer when terminal_launch_outcome is ok",
                    }
                    switch (tl_err_o) {
                        .null => {},
                        else => return "transport.terminal_launch_error must be null when terminal_launch_outcome is ok",
                    }
                } else if (std.mem.eql(u8, oc, "nonzero_exit")) {
                    if (tl_ok) return "transport.terminal_launch_ok must be false when terminal_launch_outcome is nonzero_exit";
                    switch (tl_ec_o) {
                        .integer => |i| {
                            if (i <= 0 or i > 255) return "transport.terminal_launch_exit_code must be 1..255 when terminal_launch_outcome is nonzero_exit";
                        },
                        else => return "transport.terminal_launch_exit_code must be an integer when terminal_launch_outcome is nonzero_exit",
                    }
                    switch (tl_err_o) {
                        .null => {},
                        else => return "transport.terminal_launch_error must be null when terminal_launch_outcome is nonzero_exit",
                    }
                } else if (std.mem.eql(u8, oc, "signaled")) {
                    if (tl_ok) return "transport.terminal_launch_ok must be false when terminal_launch_outcome is signaled";
                    switch (tl_ec_o) {
                        .null => {},
                        else => return "transport.terminal_launch_exit_code must be null when terminal_launch_outcome is signaled",
                    }
                    switch (tl_err_o) {
                        .null => {},
                        else => return "transport.terminal_launch_error must be null when terminal_launch_outcome is signaled",
                    }
                } else if (std.mem.eql(u8, oc, "timeout")) {
                    if (tl_ok) return "transport.terminal_launch_ok must be false when terminal_launch_outcome is timeout";
                    switch (tl_ec_o) {
                        .null => {},
                        else => return "transport.terminal_launch_exit_code must be null when terminal_launch_outcome is timeout",
                    }
                    const tag = getString(tr, "terminal_launch_error") orelse return "transport.terminal_launch_error must be timeout when terminal_launch_outcome is timeout";
                    if (!std.mem.eql(u8, tag, "timeout")) return "transport.terminal_launch_error must be timeout when terminal_launch_outcome is timeout";
                } else if (std.mem.eql(u8, oc, "spawn_failed")) {
                    if (tl_ok) return "transport.terminal_launch_ok must be false when terminal_launch_outcome is spawn_failed";
                    switch (tl_ec_o) {
                        .null => {},
                        else => return "transport.terminal_launch_exit_code must be null when terminal_launch_outcome is spawn_failed",
                    }
                    const tag = getString(tr, "terminal_launch_error") orelse return "transport.terminal_launch_error must be spawn_failed when terminal_launch_outcome is spawn_failed";
                    if (!std.mem.eql(u8, tag, "spawn_failed")) return "transport.terminal_launch_error must be spawn_failed when terminal_launch_outcome is spawn_failed";
                }
            }
        }
    }

    const hs = tr.get("handshake") orelse return "transport.handshake required";
    if (std.mem.eql(u8, tr_mode, "none")) {
        switch (hs) {
            .null => {},
            else => return "transport.handshake must be null when mode is none",
        }
    } else {
        if (getString(tr, "handshake") == null) return "transport.handshake must be a string for stub transport modes";
    }

    const hlat = getInteger(tr, "handshake_latency_ns") orelse return "transport.handshake_latency_ns must be an integer";
    if (hlat < 0) return "transport.handshake_latency_ns must be non-negative";
    if (std.mem.eql(u8, tr_mode, "none") and hlat != 0) {
        return "transport.handshake_latency_ns must be 0 when mode is none";
    }
    if ((std.mem.eql(u8, tr_mode, "pty_stub") or std.mem.eql(u8, tr_mode, "pty_guarded")) and hlat <= 0) {
        return "transport.handshake_latency_ns must be positive for pty_stub and pty_guarded";
    }

    const res_o = obj.get("results") orelse return "missing results array";
    const arr = switch (res_o) {
        .array => |a| a,
        else => return "results must be a JSON array",
    };

    for (arr.items, 0..) |item, i| {
        const row = switch (item) {
            .object => |r| r,
            else => return "results entries must be objects",
        };
        if (getString(row, "spec_id") == null) return "results[].spec_id must be a string";
        if (getString(row, "status") == null) return "results[].status must be a string";
        if (getString(row, "notes") == null) return "results[].notes must be a string";
        if (row.get("observations")) |obs| {
            switch (obs) {
                .object => {},
                else => return "results[].observations must be an object",
            }
        } else return "results[].observations required";
        if (getString(row, "capture_mode") == null) return "results[].capture_mode must be a string";
        _ = i;
    }

    return null;
}

fn getString(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

fn getInteger(obj: std.json.ObjectMap, key: []const u8) ?i64 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .integer => |i| i,
        else => null,
    };
}

fn getBool(obj: std.json.ObjectMap, key: []const u8) ?bool {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .bool => |b| b,
        else => null,
    };
}

test "validateRunReport accepts minimal harness-shaped run.json" {
    const text =
        \\{"schema_version":"0.2","run_id":"run-001","started_at":"","ended_at":"","platform":"linux","term":"xterm","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[{"spec_id":"p","status":"manual","notes":"","capture_mode":"manual","observations":{}}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) == null);
}

test "validateRunReport rejects wrong terminal_exec_template_version when id set" {
    const text =
        \\{"schema_version":"0.2","run_id":"run-001","started_at":"","ended_at":"","platform":"linux","term":"xterm","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":"kitty_exec_v1","terminal_exec_template_version":"2","terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[{"spec_id":"p","status":"manual","notes":"","capture_mode":"manual","observations":{}}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects terminal_exec_template_version when id is null" {
    const text =
        \\{"schema_version":"0.2","run_id":"run-001","started_at":"","ended_at":"","platform":"linux","term":"xterm","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":"1","terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[{"spec_id":"p","status":"manual","notes":"","capture_mode":"manual","observations":{}}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects invalid terminal_launch_preflight_reason tag" {
    const text =
        \\{"schema_version":"0.2","run_id":"run-001","started_at":"","ended_at":"","platform":"linux","term":"xterm","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":true,"terminal_launch_preflight_reason":"bogus","host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[{"spec_id":"p","status":"manual","notes":"","capture_mode":"manual","observations":{}}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects preflight ok true with non-ok reason" {
    const text =
        \\{"schema_version":"0.2","run_id":"run-001","started_at":"","ended_at":"","platform":"linux","term":"xterm","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":true,"terminal_launch_preflight_reason":"missing_executable","host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[{"spec_id":"p","status":"manual","notes":"","capture_mode":"manual","observations":{}}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing schema_version" {
    const text =
        \\{"run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t"},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects result row missing observations" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t"},"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[{"spec_id":"p","status":"manual","notes":"","capture_mode":"manual"}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects non-object terminal" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":"oops","execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects invalid execution_mode" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t"},"execution_mode":"bogus","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects invalid terminal_cmd_source" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t"},"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"bogus","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects invalid transport.mode" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t"},"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"bogus","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects non-integer transport.timeout_ms" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t"},"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":3.5},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport accepts pty_guarded transport" {
    const text =
        \\{"schema_version":"0.2","run_id":"rid","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"scaffold_only","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":null,"pty_experiment_attempt":null,"pty_experiment_elapsed_ns":null,"pty_experiment_error":null,"pty_experiment_host_machine":null,"pty_experiment_host_release":null,"pty_experiment_open_ok":null,"terminal_launch_attempt":null,"terminal_launch_elapsed_ns":null,"terminal_launch_error":null,"terminal_launch_exit_code":null,"terminal_launch_ok":null,"terminal_launch_outcome":null,"timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) == null);
}

test "validateRunReport accepts pty_guarded experiment_linux_pty success" {
    const text =
        \\{"schema_version":"0.2","run_id":"rid","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":42,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"6.1.0-test","pty_experiment_open_ok":true,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":10,"terminal_launch_error":null,"terminal_launch_exit_code":0,"terminal_launch_ok":true,"terminal_launch_outcome":"ok","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) == null);
}

test "validateRunReport rejects pty_guarded without opt-in flag in json" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"scaffold_only","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":null,"pty_experiment_attempt":null,"pty_experiment_elapsed_ns":null,"pty_experiment_error":null,"pty_experiment_host_machine":null,"pty_experiment_host_release":null,"pty_experiment_open_ok":null,"terminal_launch_attempt":null,"terminal_launch_elapsed_ns":null,"terminal_launch_error":null,"terminal_launch_exit_code":null,"terminal_launch_ok":null,"terminal_launch_outcome":null,"timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport accepts pty_guarded experiment failure telemetry" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":0,"pty_experiment_error":"grantpt","pty_experiment_host_machine":"aarch64","pty_experiment_host_release":"6.6.0","pty_experiment_open_ok":false,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":3,"terminal_launch_error":null,"terminal_launch_exit_code":0,"terminal_launch_ok":true,"terminal_launch_outcome":"ok","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) == null);
}

test "validateRunReport rejects pty_guarded experiment with wrong attempt count" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":2,"pty_experiment_elapsed_ns":1,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"1.0","pty_experiment_open_ok":true,"terminal_launch_attempt":null,"terminal_launch_elapsed_ns":null,"terminal_launch_error":null,"terminal_launch_exit_code":null,"terminal_launch_ok":null,"terminal_launch_outcome":null,"timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects pty_stub with guarded_state scaffold_only" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"scaffold_only","handshake":"stub-handshake-v1","handshake_latency_ns":1,"mode":"pty_stub","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects pty_guarded experiment missing host_machine" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":0,"pty_experiment_error":null,"pty_experiment_host_release":"6.6.0","pty_experiment_open_ok":true,"terminal_launch_attempt":null,"terminal_launch_elapsed_ns":null,"terminal_launch_error":null,"terminal_launch_exit_code":null,"terminal_launch_ok":null,"terminal_launch_outcome":null,"timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects pty_guarded scaffold with non-null host_release" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"scaffold_only","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":null,"pty_experiment_attempt":null,"pty_experiment_elapsed_ns":null,"pty_experiment_error":null,"pty_experiment_host_machine":null,"pty_experiment_host_release":"6.6.0","pty_experiment_open_ok":null,"terminal_launch_attempt":null,"terminal_launch_elapsed_ns":null,"terminal_launch_error":null,"terminal_launch_exit_code":null,"terminal_launch_ok":null,"terminal_launch_outcome":null,"timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects empty host_identity_machine" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing host_identity_sysname" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects run_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong run_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"2","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects specset_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong specset_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"2","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing specset_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects resultset_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong resultset_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"2","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing resultset_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects transport_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong transport_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing transport_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects exec_summary_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong exec_summary_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing exec_summary_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects context_summary_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong context_summary_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing context_summary_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects metadata_envelope_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"222222222222222222222222222222222222222222222222222222222222222B","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong metadata_envelope_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing metadata_envelope_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects artifact_bundle_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"333333333333333333333333333333333333333333333333333333333333333B","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong artifact_bundle_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing artifact_bundle_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects report_envelope_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"444444444444444444444444444444444444444444444444444444444444444B","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong report_envelope_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing report_envelope_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects compare_envelope_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"555555555555555555555555555555555555555555555555555555555555555B","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong compare_envelope_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing compare_envelope_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects run_envelope_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"666666666666666666666666666666666666666666666666666666666666666B","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong run_envelope_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects missing run_envelope_fingerprint_digest" {
    const text =
        \\{"schema_version":"0.2","run_id":"r","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects state_envelope_fingerprint_digest with uppercase hex" {
    const text =
        \\{"schema_version":"0.2","run_id":"run-001","started_at":"","ended_at":"","platform":"linux","term":"xterm","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeE","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[{"spec_id":"p","status":"manual","notes":"","capture_mode":"manual","observations":{}}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects wrong state_envelope_fingerprint_version" {
    const text =
        \\{"schema_version":"0.2","run_id":"run-001","started_at":"","ended_at":"","platform":"linux","term":"xterm","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"2","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":30000},"results":[{"spec_id":"p","status":"manual","notes":"","capture_mode":"manual","observations":{}}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}
test "validateRunReport rejects terminal_launch_outcome ok when terminal_launch_ok false" {
    const text =
        \\{"schema_version":"0.2","run_id":"rid","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":42,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"6.1.0-test","pty_experiment_open_ok":true,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":10,"terminal_launch_error":null,"terminal_launch_exit_code":0,"terminal_launch_ok":false,"terminal_launch_outcome":"ok","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects unknown terminal_launch_outcome" {
    const text =
        \\{"schema_version":"0.2","run_id":"rid","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":42,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"6.1.0-test","pty_experiment_open_ok":true,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":10,"terminal_launch_error":null,"terminal_launch_exit_code":0,"terminal_launch_ok":true,"terminal_launch_outcome":"bogus","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects nonzero_exit with exit code 0" {
    const text =
        \\{"schema_version":"0.2","run_id":"rid","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":42,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"6.1.0-test","pty_experiment_open_ok":true,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":10,"terminal_launch_error":null,"terminal_launch_exit_code":0,"terminal_launch_ok":false,"terminal_launch_outcome":"nonzero_exit","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport rejects timeout without terminal_launch_error timeout" {
    const text =
        \\{"schema_version":"0.2","run_id":"rid","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":42,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"6.1.0-test","pty_experiment_open_ok":true,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":10,"terminal_launch_error":null,"terminal_launch_exit_code":null,"terminal_launch_ok":false,"terminal_launch_outcome":"timeout","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) != null);
}

test "validateRunReport accepts terminal_launch_outcome nonzero_exit" {
    const text =
        \\{"schema_version":"0.2","run_id":"rid","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":42,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"6.1.0-test","pty_experiment_open_ok":true,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":10,"terminal_launch_error":null,"terminal_launch_exit_code":2,"terminal_launch_ok":false,"terminal_launch_outcome":"nonzero_exit","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) == null);
}

test "validateRunReport accepts terminal_launch_outcome timeout" {
    const text =
        \\{"schema_version":"0.2","run_id":"rid","started_at":"","ended_at":"","platform":"linux","term":"x","terminal":{"name":"t","version":""},"suite":null,"comparison_id":null,"run_group":null,"execution_mode":"placeholder","terminal_profile_id":null,"terminal_cmd_source":"fallback","resolved_terminal_cmd":"","resolved_terminal_argv":[],"terminal_exec_template_id":null,"terminal_exec_template_version":null,"terminal_exec_resolved_path":null,"terminal_exec_resolved_path_normalization":null,"terminal_launch_preflight_ok":null,"terminal_launch_preflight_reason":null,"host_identity_machine":"x86_64","host_identity_release":"6.0.0","host_identity_sysname":"Linux","run_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"2","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":"linux /dev/ptmx","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":42,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"6.1.0-test","pty_experiment_open_ok":true,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":10,"terminal_launch_error":"timeout","terminal_launch_exit_code":null,"terminal_launch_ok":false,"terminal_launch_outcome":"timeout","timeout_ms":30000},"results":[]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(validateRunReport(parsed.value) == null);
}

