const std = @import("std");
const modes = @import("../capture/modes.zig");
const ExecutionMode = @import("../runner/execution_mode.zig").ExecutionMode;
const TransportMode = @import("../runner/transport_mode.zig").TransportMode;

/// Truncated copy of `uname.machine` during guarded PTY experiment (PH1-M9).
pub const pty_host_machine_cap: usize = 64;
/// Truncated copy of `uname.release` during guarded PTY experiment (PH1-M9).
pub const pty_host_release_cap: usize = 256;

/// Root `run.json` host identity: `uname.machine` (PH1-M10).
pub const host_identity_machine_cap: usize = 64;
/// Root `run.json` host identity: `uname.release` (PH1-M10).
pub const host_identity_release_cap: usize = 256;
/// Root `run.json` host identity: `uname.sysname` (PH1-M10).
pub const host_identity_sysname_cap: usize = 64;

/// Max bytes stored for PH1-M33 resolved terminal command (bounded copy).
pub const terminal_cmd_storage_cap: usize = 1024;
/// Max bytes for canonical `terminal_profile_id` in artifacts.
pub const terminal_profile_id_cap: usize = 64;
/// PH1-M34: max argv slots for bounded terminal launch.
pub const terminal_exec_argc_max: usize = 16;
/// PH1-M34: max bytes per argv slot (including NUL not stored).
pub const terminal_exec_arg_max: usize = 256;
/// PH1-M34: max bytes for `terminal_exec_template_id` in artifacts.
pub const terminal_exec_template_id_cap: usize = 64;
/// PH1-M35: max bytes for `terminal_exec_resolved_path` in artifacts.
pub const terminal_exec_resolved_path_cap: usize = 512;
/// PH1-M37: max bytes for `terminal_launch_diagnostics_reason` in artifacts.
pub const terminal_launch_diagnostics_reason_cap: usize = 32;

pub const RunContext = struct {
    capture_mode: []const u8,
    terminal_name: []const u8,
    /// Raw `--terminal-cmd` argv slice when provided; empty otherwise (PH1-M33).
    terminal_cmd_cli: []const u8,
    /// Effective command after profile resolution (PH1-M33); used for launch + fingerprints.
    terminal_cmd: []const u8,
    terminal_cmd_effective_buf: [terminal_cmd_storage_cap]u8,
    terminal_cmd_effective_len: u16,
    terminal_profile_id_buf: [terminal_profile_id_cap]u8,
    terminal_profile_id_len: u8,
    /// `terminal_profile.source_*` (PH1-M33).
    terminal_cmd_source: []const u8,
    /// PH1-M34: resolved launch argv (direct exec); `terminal_exec_argc` zero until resolution runs.
    terminal_exec_argv_flat: [terminal_exec_argc_max][terminal_exec_arg_max]u8,
    terminal_exec_argv_lens: [terminal_exec_argc_max]u16,
    terminal_exec_argc: u8,
    terminal_exec_template_id_buf: [terminal_exec_template_id_cap]u8,
    terminal_exec_template_id_len: u8,
    terminal_exec_template_version_buf: [8]u8,
    terminal_exec_template_version_len: u8,
    platform: []const u8,
    suite_name: ?[]const u8,
    comparison_id: ?[]const u8,
    /// Optional batch label for grouping multiple comparisons (e.g. CI matrix key).
    run_group: ?[]const u8,
    /// When true, plan and execute in memory only (no artifact directory).
    dry_run: bool,
    /// Stricter validation when supported (PH1-M4+).
    strict: bool,
    execution_mode: ExecutionMode,
    transport_mode: TransportMode,
    /// Recorded in `run.json` → `transport.timeout_ms`.
    timeout_ms: u32,
    /// Explicit opt-in for `pty_guarded` (or set `ANA_TERM_ALLOW_GUARDED_TRANSPORT=1`).
    allow_guarded_transport: bool,
    /// Filled for non-dry-run `pty_guarded` on Linux after the minimal PTY experiment.
    pty_experiment_open_ok: ?bool,
    pty_experiment_error: ?[]const u8,
    pty_capability_notes: ?[]const u8,
    /// PH1-M8: single attempt counter for guarded PTY experiment (`1` when run; `null` in artifacts for scaffold_only).
    pty_experiment_attempt: ?u32,
    /// PH1-M8: wall-time nanoseconds for experiment block, clamped to `maxInt(i64)` for JSON.
    pty_experiment_elapsed_ns: ?u64,
    /// PH1-M9: filled at start of non-dry-run guarded PTY experiment on Linux; else length 0.
    pty_experiment_host_machine: [pty_host_machine_cap]u8,
    pty_experiment_host_machine_len: u8,
    pty_experiment_host_release: [pty_host_release_cap]u8,
    pty_experiment_host_release_len: u16,
    /// PH1-M10: runtime `uname` for artifact runs; lengths 0 until `captureHostIdentity`.
    host_identity_machine: [host_identity_machine_cap]u8,
    host_identity_machine_len: u8,
    host_identity_release: [host_identity_release_cap]u8,
    host_identity_release_len: u16,
    host_identity_sysname: [host_identity_sysname_cap]u8,
    host_identity_sysname_len: u8,
    /// PH1-M11: 64-char lowercase SHA-256 hex; length 0 until `run_fingerprint.populate`.
    run_fingerprint_digest_hex: [64]u8,
    run_fingerprint_digest_len: u8,
    /// PH1-M12: 64-char lowercase SHA-256 hex; length 0 until `specset_fingerprint.populate`.
    specset_fingerprint_digest_hex: [64]u8,
    specset_fingerprint_digest_len: u8,
    /// PH1-M13: 64-char lowercase SHA-256 hex; length 0 until `resultset_fingerprint.populate`.
    resultset_fingerprint_digest_hex: [64]u8,
    resultset_fingerprint_digest_len: u8,
    /// PH1-M14: 64-char lowercase SHA-256 hex; length 0 until `transport_fingerprint.populate`.
    transport_fingerprint_digest_hex: [64]u8,
    transport_fingerprint_digest_len: u8,
    /// PH1-M15: 64-char lowercase SHA-256 hex; length 0 until `exec_summary_fingerprint.populate`.
    exec_summary_fingerprint_digest_hex: [64]u8,
    exec_summary_fingerprint_digest_len: u8,
    /// PH1-M16: 64-char lowercase SHA-256 hex; length 0 until `context_summary_fingerprint.populate`.
    context_summary_fingerprint_digest_hex: [64]u8,
    context_summary_fingerprint_digest_len: u8,
    /// PH1-M17: 64-char lowercase SHA-256 hex; length 0 until `metadata_envelope_fingerprint.populate`.
    metadata_envelope_fingerprint_digest_hex: [64]u8,
    metadata_envelope_fingerprint_digest_len: u8,
    /// PH1-M18: 64-char lowercase SHA-256 hex; length 0 until `artifact_bundle_fingerprint.populate`.
    artifact_bundle_fingerprint_digest_hex: [64]u8,
    artifact_bundle_fingerprint_digest_len: u8,
    /// PH1-M19: 64-char lowercase SHA-256 hex; length 0 until `report_envelope_fingerprint.populate`.
    report_envelope_fingerprint_digest_hex: [64]u8,
    report_envelope_fingerprint_digest_len: u8,
    /// PH1-M20: 64-char lowercase SHA-256 hex; length 0 until `compare_envelope_fingerprint.populate`.
    compare_envelope_fingerprint_digest_hex: [64]u8,
    compare_envelope_fingerprint_digest_len: u8,
    /// PH1-M21: 64-char lowercase SHA-256 hex; length 0 until `run_envelope_fingerprint.populate`.
    run_envelope_fingerprint_digest_hex: [64]u8,
    run_envelope_fingerprint_digest_len: u8,
    /// PH1-M22: 64-char lowercase SHA-256 hex; length 0 until `session_envelope_fingerprint.populate`.
    session_envelope_fingerprint_digest_hex: [64]u8,
    session_envelope_fingerprint_digest_len: u8,
    /// PH1-M23: 64-char lowercase SHA-256 hex; length 0 until `environment_envelope_fingerprint.populate`.
    environment_envelope_fingerprint_digest_hex: [64]u8,
    environment_envelope_fingerprint_digest_len: u8,
    /// PH1-M24: 64-char lowercase SHA-256 hex; length 0 until `artifact_manifest_fingerprint.populate`.
    artifact_manifest_fingerprint_digest_hex: [64]u8,
    artifact_manifest_fingerprint_digest_len: u8,
    /// PH1-M25: 64-char lowercase SHA-256 hex; length 0 until `provenance_envelope_fingerprint.populate`.
    provenance_envelope_fingerprint_digest_hex: [64]u8,
    provenance_envelope_fingerprint_digest_len: u8,
    /// PH1-M26: 64-char lowercase SHA-256 hex; length 0 until `integrity_envelope_fingerprint.populate`.
    integrity_envelope_fingerprint_digest_hex: [64]u8,
    integrity_envelope_fingerprint_digest_len: u8,
    /// PH1-M27: 64-char lowercase SHA-256 hex; length 0 until `consistency_envelope_fingerprint.populate`.
    consistency_envelope_fingerprint_digest_hex: [64]u8,
    consistency_envelope_fingerprint_digest_len: u8,
    /// PH1-M28: 64-char lowercase SHA-256 hex; length 0 until `trace_envelope_fingerprint.populate`.
    trace_envelope_fingerprint_digest_hex: [64]u8,
    trace_envelope_fingerprint_digest_len: u8,
    /// PH1-M29: 64-char lowercase SHA-256 hex; length 0 until `lineage_envelope_fingerprint.populate`.
    lineage_envelope_fingerprint_digest_hex: [64]u8,
    lineage_envelope_fingerprint_digest_len: u8,
    /// PH1-M30: 64-char lowercase SHA-256 hex; length 0 until `state_envelope_fingerprint.populate`.
    state_envelope_fingerprint_digest_hex: [64]u8,
    state_envelope_fingerprint_digest_len: u8,
    /// PH1-M31: `1` when real terminal launch ran; `null` when not applicable / not attempted.
    terminal_launch_attempt: ?u32,
    /// PH1-M31: wall-time nanoseconds for launch block; `null` when no attempt.
    terminal_launch_elapsed_ns: ?u64,
    /// PH1-M31: child exit status when reaped; `null` on spawn failure or timeout before status.
    terminal_launch_exit_code: ?u32,
    /// PH1-M31: `true` iff exit status 0 when known; `null` when no attempt.
    terminal_launch_ok: ?bool,
    /// PH1-M31: short static tag (`timeout`, `spawn_failed`, …); `null` when none.
    terminal_launch_error: ?[]const u8,
    /// PH1-M32: `ok` \| `nonzero_exit` \| `signaled` \| `timeout` \| `spawn_failed`; `null` when no attempt.
    terminal_launch_outcome: ?[]const u8,
    /// PH1-M35: preflight probe outcome when applicable; `null` when not run.
    terminal_launch_preflight_ok: ?bool,
    /// PH1-M35: static reason tag (`launch_preflight.reason_*`); `null` when not applicable.
    terminal_launch_preflight_reason: ?[]const u8,
    /// PH1-M36: `canonical` \| `literal` \| `null` when no path (see `docs/LAUNCH_PREFLIGHT_STRICTNESS_PLAN.md`).
    terminal_exec_resolved_path_normalization: ?[]const u8,
    /// PH1-M35: resolved path buffer for `argv[0]` probe.
    terminal_exec_resolved_path_buf: [terminal_exec_resolved_path_cap]u8,
    terminal_exec_resolved_path_len: u16,
    /// PH1-M37: normalized failure reason (ok, missing_executable, not_executable, spawn_failed, timeout, nonzero_exit, signaled).
    terminal_launch_diagnostics_reason_buf: [terminal_launch_diagnostics_reason_cap]u8,
    terminal_launch_diagnostics_reason_len: u8,
    /// PH1-M37: wall-time milliseconds from launch start to outcome; `null` when not applicable.
    terminal_launch_diagnostics_elapsed_ms: ?u32,
    /// PH1-M37: signal number when signaled (e.g. 9 for SIGKILL); `null` otherwise.
    terminal_launch_diagnostics_signal: ?u32,
    /// PH1-M38: 64-char lowercase SHA-256 hex; length 0 until fingerprint populated.
    launch_diagnostics_fingerprint_digest_hex: [64]u8,
    launch_diagnostics_fingerprint_digest_len: u8,

    pub fn initDefault() RunContext {
        return .{
            .capture_mode = modes.defaultMode(),
            .terminal_name = "unknown",
            .terminal_cmd_cli = "",
            .terminal_cmd = "",
            .terminal_cmd_effective_buf = std.mem.zeroes([terminal_cmd_storage_cap]u8),
            .terminal_cmd_effective_len = 0,
            .terminal_profile_id_buf = std.mem.zeroes([terminal_profile_id_cap]u8),
            .terminal_profile_id_len = 0,
            .terminal_cmd_source = "",
            .terminal_exec_argv_flat = std.mem.zeroes([terminal_exec_argc_max][terminal_exec_arg_max]u8),
            .terminal_exec_argv_lens = std.mem.zeroes([terminal_exec_argc_max]u16),
            .terminal_exec_argc = 0,
            .terminal_exec_template_id_buf = std.mem.zeroes([terminal_exec_template_id_cap]u8),
            .terminal_exec_template_id_len = 0,
            .terminal_exec_template_version_buf = std.mem.zeroes([8]u8),
            .terminal_exec_template_version_len = 0,
            .platform = defaultPlatformTag(),
            .suite_name = null,
            .comparison_id = null,
            .run_group = null,
            .dry_run = false,
            .strict = false,
            .execution_mode = .placeholder,
            .transport_mode = .none,
            .timeout_ms = 30_000,
            .allow_guarded_transport = false,
            .pty_experiment_open_ok = null,
            .pty_experiment_error = null,
            .pty_capability_notes = null,
            .pty_experiment_attempt = null,
            .pty_experiment_elapsed_ns = null,
            .pty_experiment_host_machine = std.mem.zeroes([pty_host_machine_cap]u8),
            .pty_experiment_host_machine_len = 0,
            .pty_experiment_host_release = std.mem.zeroes([pty_host_release_cap]u8),
            .pty_experiment_host_release_len = 0,
            .host_identity_machine = std.mem.zeroes([host_identity_machine_cap]u8),
            .host_identity_machine_len = 0,
            .host_identity_release = std.mem.zeroes([host_identity_release_cap]u8),
            .host_identity_release_len = 0,
            .host_identity_sysname = std.mem.zeroes([host_identity_sysname_cap]u8),
            .host_identity_sysname_len = 0,
            .run_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .run_fingerprint_digest_len = 0,
            .specset_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .specset_fingerprint_digest_len = 0,
            .resultset_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .resultset_fingerprint_digest_len = 0,
            .transport_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .transport_fingerprint_digest_len = 0,
            .exec_summary_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .exec_summary_fingerprint_digest_len = 0,
            .context_summary_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .context_summary_fingerprint_digest_len = 0,
            .metadata_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .metadata_envelope_fingerprint_digest_len = 0,
            .artifact_bundle_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .artifact_bundle_fingerprint_digest_len = 0,
            .report_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .report_envelope_fingerprint_digest_len = 0,
            .compare_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .compare_envelope_fingerprint_digest_len = 0,
            .run_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .run_envelope_fingerprint_digest_len = 0,
            .session_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .session_envelope_fingerprint_digest_len = 0,
            .environment_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .environment_envelope_fingerprint_digest_len = 0,
            .artifact_manifest_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .artifact_manifest_fingerprint_digest_len = 0,
            .provenance_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .provenance_envelope_fingerprint_digest_len = 0,
            .integrity_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .integrity_envelope_fingerprint_digest_len = 0,
            .consistency_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .consistency_envelope_fingerprint_digest_len = 0,
            .trace_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .trace_envelope_fingerprint_digest_len = 0,
            .lineage_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .lineage_envelope_fingerprint_digest_len = 0,
            .state_envelope_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .state_envelope_fingerprint_digest_len = 0,
            .terminal_launch_attempt = null,
            .terminal_launch_elapsed_ns = null,
            .terminal_launch_exit_code = null,
            .terminal_launch_ok = null,
            .terminal_launch_error = null,
            .terminal_launch_outcome = null,
            .terminal_launch_preflight_ok = null,
            .terminal_launch_preflight_reason = null,
            .terminal_exec_resolved_path_normalization = null,
            .terminal_exec_resolved_path_buf = std.mem.zeroes([terminal_exec_resolved_path_cap]u8),
            .terminal_exec_resolved_path_len = 0,
            .terminal_launch_diagnostics_reason_buf = std.mem.zeroes([terminal_launch_diagnostics_reason_cap]u8),
            .terminal_launch_diagnostics_reason_len = 0,
            .terminal_launch_diagnostics_elapsed_ms = null,
            .terminal_launch_diagnostics_signal = null,
            .launch_diagnostics_fingerprint_digest_hex = std.mem.zeroes([64]u8),
            .launch_diagnostics_fingerprint_digest_len = 0,
        };
    }

    /// Snapshot `uname` for root `run.json` host identity; call once per artifact-producing run.
    pub fn captureHostIdentity(ctx: *RunContext) void {
        const u = std.posix.uname();
        const sys = std.mem.sliceTo(&u.sysname, 0);
        const n_sys = @min(sys.len, host_identity_sysname_cap);
        @memcpy(ctx.host_identity_sysname[0..n_sys], sys[0..n_sys]);
        ctx.host_identity_sysname_len = @intCast(n_sys);

        const m = std.mem.sliceTo(&u.machine, 0);
        const n_m = @min(m.len, host_identity_machine_cap);
        @memcpy(ctx.host_identity_machine[0..n_m], m[0..n_m]);
        ctx.host_identity_machine_len = @intCast(n_m);

        const r = std.mem.sliceTo(&u.release, 0);
        const n_r = @min(r.len, host_identity_release_cap);
        @memcpy(ctx.host_identity_release[0..n_r], r[0..n_r]);
        ctx.host_identity_release_len = @intCast(n_r);
    }

    /// Snapshot `uname` for reproducibility; call once per guarded experiment run.
    pub fn capturePtyHostSnapshot(ctx: *RunContext) void {
        const u = std.posix.uname();
        const m = std.mem.sliceTo(&u.machine, 0);
        const n_m = @min(m.len, pty_host_machine_cap);
        @memcpy(ctx.pty_experiment_host_machine[0..n_m], m[0..n_m]);
        ctx.pty_experiment_host_machine_len = @intCast(n_m);

        const r = std.mem.sliceTo(&u.release, 0);
        const n_r = @min(r.len, pty_host_release_cap);
        @memcpy(ctx.pty_experiment_host_release[0..n_r], r[0..n_r]);
        ctx.pty_experiment_host_release_len = @intCast(n_r);
    }
};

pub fn defaultPlatformTag() []const u8 {
    const builtin = @import("builtin");
    return switch (builtin.target.os.tag) {
        .linux => "linux",
        .windows => "windows",
        .macos, .ios, .tvos, .watchos => "darwin",
        else => "unknown",
    };
}

test "capturePtyHostSnapshot fills machine and release on Linux" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    var ctx = RunContext.initDefault();
    ctx.capturePtyHostSnapshot();
    try std.testing.expect(ctx.pty_experiment_host_machine_len > 0);
    try std.testing.expect(ctx.pty_experiment_host_release_len > 0);
}

test "captureHostIdentity fills machine release and sysname on Linux" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    var ctx = RunContext.initDefault();
    ctx.captureHostIdentity();
    try std.testing.expect(ctx.host_identity_machine_len > 0);
    try std.testing.expect(ctx.host_identity_release_len > 0);
    try std.testing.expect(ctx.host_identity_sysname_len > 0);
}
