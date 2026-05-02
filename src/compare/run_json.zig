const std = @import("std");

pub const RunMeta = struct {
    platform: ?[]const u8 = null,
    term: ?[]const u8 = null,
    terminal_name: ?[]const u8 = null,
    suite: ?[]const u8 = null,
    comparison_id: ?[]const u8 = null,
    run_group: ?[]const u8 = null,
    execution_mode: ?[]const u8 = null,
    terminal_profile_id: ?[]const u8 = null,
    terminal_cmd_source: ?[]const u8 = null,
    resolved_terminal_cmd: ?[]const u8 = null,
    /// Canonical JSON array string for compare (PH1-M34).
    resolved_terminal_argv: ?[]const u8 = null,
    terminal_exec_template_id: ?[]const u8 = null,
    terminal_exec_template_version: ?[]const u8 = null,
    terminal_exec_resolved_path: ?[]const u8 = null,
    terminal_exec_resolved_path_normalization: ?[]const u8 = null,
    terminal_launch_preflight_ok: ?[]const u8 = null,
    terminal_launch_preflight_reason: ?[]const u8 = null,
    host_identity_machine: ?[]const u8 = null,
    host_identity_release: ?[]const u8 = null,
    host_identity_sysname: ?[]const u8 = null,
    run_fingerprint_digest: ?[]const u8 = null,
    run_fingerprint_version: ?[]const u8 = null,
    specset_fingerprint_digest: ?[]const u8 = null,
    specset_fingerprint_version: ?[]const u8 = null,
    resultset_fingerprint_digest: ?[]const u8 = null,
    resultset_fingerprint_version: ?[]const u8 = null,
    transport_fingerprint_digest: ?[]const u8 = null,
    transport_fingerprint_version: ?[]const u8 = null,
    exec_summary_fingerprint_digest: ?[]const u8 = null,
    exec_summary_fingerprint_version: ?[]const u8 = null,
    context_summary_fingerprint_digest: ?[]const u8 = null,
    context_summary_fingerprint_version: ?[]const u8 = null,
    metadata_envelope_fingerprint_digest: ?[]const u8 = null,
    metadata_envelope_fingerprint_version: ?[]const u8 = null,
    artifact_bundle_fingerprint_digest: ?[]const u8 = null,
    artifact_bundle_fingerprint_version: ?[]const u8 = null,
    report_envelope_fingerprint_digest: ?[]const u8 = null,
    report_envelope_fingerprint_version: ?[]const u8 = null,
    compare_envelope_fingerprint_digest: ?[]const u8 = null,
    compare_envelope_fingerprint_version: ?[]const u8 = null,
    run_envelope_fingerprint_digest: ?[]const u8 = null,
    run_envelope_fingerprint_version: ?[]const u8 = null,
    session_envelope_fingerprint_digest: ?[]const u8 = null,
    session_envelope_fingerprint_version: ?[]const u8 = null,
    environment_envelope_fingerprint_digest: ?[]const u8 = null,
    environment_envelope_fingerprint_version: ?[]const u8 = null,
    artifact_manifest_fingerprint_digest: ?[]const u8 = null,
    artifact_manifest_fingerprint_version: ?[]const u8 = null,
    provenance_envelope_fingerprint_digest: ?[]const u8 = null,
    provenance_envelope_fingerprint_version: ?[]const u8 = null,
    integrity_envelope_fingerprint_digest: ?[]const u8 = null,
    integrity_envelope_fingerprint_version: ?[]const u8 = null,
    consistency_envelope_fingerprint_digest: ?[]const u8 = null,
    consistency_envelope_fingerprint_version: ?[]const u8 = null,
    trace_envelope_fingerprint_digest: ?[]const u8 = null,
    trace_envelope_fingerprint_version: ?[]const u8 = null,
    lineage_envelope_fingerprint_digest: ?[]const u8 = null,
    lineage_envelope_fingerprint_version: ?[]const u8 = null,
    state_envelope_fingerprint_digest: ?[]const u8 = null,
    state_envelope_fingerprint_version: ?[]const u8 = null,
    guarded_opt_in: ?[]const u8 = null,
    guarded_state: ?[]const u8 = null,
    pty_capability_notes: ?[]const u8 = null,
    pty_experiment_attempt: ?[]const u8 = null,
    pty_experiment_elapsed_ns: ?[]const u8 = null,
    pty_experiment_error: ?[]const u8 = null,
    pty_experiment_host_machine: ?[]const u8 = null,
    pty_experiment_host_release: ?[]const u8 = null,
    pty_experiment_open_ok: ?[]const u8 = null,
    terminal_launch_attempt: ?[]const u8 = null,
    terminal_launch_elapsed_ns: ?[]const u8 = null,
    terminal_launch_error: ?[]const u8 = null,
    terminal_launch_exit_code: ?[]const u8 = null,
    terminal_launch_ok: ?[]const u8 = null,
    terminal_launch_outcome: ?[]const u8 = null,
    /// PH1-M37: normalized failure reason from diagnostics envelope.
    terminal_launch_diagnostics_reason: ?[]const u8 = null,
    terminal_launch_diagnostics_elapsed_ms: ?[]const u8 = null,
    terminal_launch_diagnostics_signal: ?[]const u8 = null,
    /// PH1-M38: launch diagnostics fingerprint digest and version.
    terminal_launch_diagnostics_fingerprint_digest: ?[]const u8 = null,
    terminal_launch_diagnostics_fingerprint_version: ?[]const u8 = null,
    transport_handshake: ?[]const u8 = null,
    transport_handshake_latency_ns: ?[]const u8 = null,
    transport_mode: ?[]const u8 = null,
    transport_timeout_ms: ?[]const u8 = null,
};

pub const MetaDiffRow = struct {
    field: []const u8,
    left: ?[]const u8,
    right: ?[]const u8,
    delta: []const u8,
};

/// Reads metadata fields. String slices may point into `root`; numeric transport fields are formatted into `allocator`.
pub fn parseRunMeta(allocator: std.mem.Allocator, root: std.json.Value) !RunMeta {
    const obj = switch (root) {
        .object => |o| o,
        else => return .{},
    };
    var m = RunMeta{};
    m.platform = readOptString(obj, "platform");
    m.term = readOptString(obj, "term");
    m.suite = readOptStringOrNull(obj, "suite");
    m.comparison_id = readOptStringOrNull(obj, "comparison_id");
    m.run_group = readOptStringOrNull(obj, "run_group");
    m.execution_mode = readOptString(obj, "execution_mode");
    m.terminal_profile_id = readOptStringOrNull(obj, "terminal_profile_id");
    m.terminal_cmd_source = readOptStringOrNull(obj, "terminal_cmd_source");
    m.resolved_terminal_cmd = readOptStringOrNull(obj, "resolved_terminal_cmd");
    if (obj.get("resolved_terminal_argv")) |rv| {
        m.resolved_terminal_argv = switch (rv) {
            .array => |a| try allocCanonicalArgvJson(allocator, a.items),
            else => return error.InvalidCompareMeta,
        };
    }
    m.terminal_exec_template_id = readOptStringOrNull(obj, "terminal_exec_template_id");
    m.terminal_exec_template_version = readOptStringOrNull(obj, "terminal_exec_template_version");
    m.terminal_exec_resolved_path = readOptStringOrNull(obj, "terminal_exec_resolved_path");
    m.terminal_exec_resolved_path_normalization = readOptStringOrNull(obj, "terminal_exec_resolved_path_normalization");
    m.terminal_launch_preflight_ok = try readOptBoolString(allocator, obj, "terminal_launch_preflight_ok");
    m.terminal_launch_preflight_reason = readOptStringOrNull(obj, "terminal_launch_preflight_reason");
    // PH1-M37: populate diagnostics envelope metadata.
    m.terminal_launch_diagnostics_reason = readOptStringOrNull(obj, "terminal_launch_diagnostics_reason");
    m.terminal_launch_diagnostics_elapsed_ms = try readOptNumberStringOrNull(allocator, obj, "terminal_launch_diagnostics_elapsed_ms");
    m.terminal_launch_diagnostics_signal = try readOptNumberStringOrNull(allocator, obj, "terminal_launch_diagnostics_signal");
    // PH1-M38: populate launch diagnostics fingerprint metadata.
    m.terminal_launch_diagnostics_fingerprint_digest = readOptStringOrNull(obj, "terminal_launch_diagnostics_fingerprint_digest");
    m.terminal_launch_diagnostics_fingerprint_version = readOptStringOrNull(obj, "terminal_launch_diagnostics_fingerprint_version");
    m.host_identity_machine = readOptString(obj, "host_identity_machine");
    m.host_identity_release = readOptString(obj, "host_identity_release");
    m.host_identity_sysname = readOptString(obj, "host_identity_sysname");
    m.run_fingerprint_digest = readOptString(obj, "run_fingerprint_digest");
    m.run_fingerprint_version = readOptString(obj, "run_fingerprint_version");
    m.specset_fingerprint_digest = readOptString(obj, "specset_fingerprint_digest");
    m.specset_fingerprint_version = readOptString(obj, "specset_fingerprint_version");
    m.resultset_fingerprint_digest = readOptString(obj, "resultset_fingerprint_digest");
    m.resultset_fingerprint_version = readOptString(obj, "resultset_fingerprint_version");
    m.transport_fingerprint_digest = readOptString(obj, "transport_fingerprint_digest");
    m.transport_fingerprint_version = readOptString(obj, "transport_fingerprint_version");
    m.exec_summary_fingerprint_digest = readOptString(obj, "exec_summary_fingerprint_digest");
    m.exec_summary_fingerprint_version = readOptString(obj, "exec_summary_fingerprint_version");
    m.context_summary_fingerprint_digest = readOptString(obj, "context_summary_fingerprint_digest");
    m.context_summary_fingerprint_version = readOptString(obj, "context_summary_fingerprint_version");
    m.metadata_envelope_fingerprint_digest = readOptString(obj, "metadata_envelope_fingerprint_digest");
    m.metadata_envelope_fingerprint_version = readOptString(obj, "metadata_envelope_fingerprint_version");
    m.artifact_bundle_fingerprint_digest = readOptString(obj, "artifact_bundle_fingerprint_digest");
    m.artifact_bundle_fingerprint_version = readOptString(obj, "artifact_bundle_fingerprint_version");
    m.report_envelope_fingerprint_digest = readOptString(obj, "report_envelope_fingerprint_digest");
    m.report_envelope_fingerprint_version = readOptString(obj, "report_envelope_fingerprint_version");
    m.compare_envelope_fingerprint_digest = readOptString(obj, "compare_envelope_fingerprint_digest");
    m.compare_envelope_fingerprint_version = readOptString(obj, "compare_envelope_fingerprint_version");
    m.run_envelope_fingerprint_digest = readOptString(obj, "run_envelope_fingerprint_digest");
    m.run_envelope_fingerprint_version = readOptString(obj, "run_envelope_fingerprint_version");
    m.session_envelope_fingerprint_digest = readOptString(obj, "session_envelope_fingerprint_digest");
    m.session_envelope_fingerprint_version = readOptString(obj, "session_envelope_fingerprint_version");
    m.environment_envelope_fingerprint_digest = readOptString(obj, "environment_envelope_fingerprint_digest");
    m.environment_envelope_fingerprint_version = readOptString(obj, "environment_envelope_fingerprint_version");
    m.artifact_manifest_fingerprint_digest = readOptString(obj, "artifact_manifest_fingerprint_digest");
    m.artifact_manifest_fingerprint_version = readOptString(obj, "artifact_manifest_fingerprint_version");
    m.provenance_envelope_fingerprint_digest = readOptString(obj, "provenance_envelope_fingerprint_digest");
    m.provenance_envelope_fingerprint_version = readOptString(obj, "provenance_envelope_fingerprint_version");
    m.integrity_envelope_fingerprint_digest = readOptString(obj, "integrity_envelope_fingerprint_digest");
    m.integrity_envelope_fingerprint_version = readOptString(obj, "integrity_envelope_fingerprint_version");
    m.consistency_envelope_fingerprint_digest = readOptString(obj, "consistency_envelope_fingerprint_digest");
    m.consistency_envelope_fingerprint_version = readOptString(obj, "consistency_envelope_fingerprint_version");
    m.trace_envelope_fingerprint_digest = readOptString(obj, "trace_envelope_fingerprint_digest");
    m.trace_envelope_fingerprint_version = readOptString(obj, "trace_envelope_fingerprint_version");
    m.lineage_envelope_fingerprint_digest = readOptString(obj, "lineage_envelope_fingerprint_digest");
    m.lineage_envelope_fingerprint_version = readOptString(obj, "lineage_envelope_fingerprint_version");
    m.state_envelope_fingerprint_digest = readOptString(obj, "state_envelope_fingerprint_digest");
    m.state_envelope_fingerprint_version = readOptString(obj, "state_envelope_fingerprint_version");
    if (obj.get("terminal")) |t| switch (t) {
        .object => |term_o| {
            m.terminal_name = readOptString(term_o, "name");
        },
        else => {},
    } else {}

    if (obj.get("transport")) |tv| switch (tv) {
        .object => |tr| {
            m.transport_mode = readOptString(tr, "mode");
            m.guarded_opt_in = try readOptBoolString(allocator, tr, "guarded_opt_in");
            m.guarded_state = readOptStringOrNull(tr, "guarded_state");
            m.pty_capability_notes = readOptStringOrNull(tr, "pty_capability_notes");
            m.pty_experiment_attempt = try readOptNumberStringOrNull(allocator, tr, "pty_experiment_attempt");
            m.pty_experiment_elapsed_ns = try readOptNumberStringOrNull(allocator, tr, "pty_experiment_elapsed_ns");
            m.pty_experiment_error = readOptStringOrNull(tr, "pty_experiment_error");
            m.pty_experiment_host_machine = readOptStringOrNull(tr, "pty_experiment_host_machine");
            m.pty_experiment_host_release = readOptStringOrNull(tr, "pty_experiment_host_release");
            m.pty_experiment_open_ok = try readOptBoolString(allocator, tr, "pty_experiment_open_ok");
            m.terminal_launch_attempt = try readOptNumberStringOrNull(allocator, tr, "terminal_launch_attempt");
            m.terminal_launch_elapsed_ns = try readOptNumberStringOrNull(allocator, tr, "terminal_launch_elapsed_ns");
            m.terminal_launch_error = readOptStringOrNull(tr, "terminal_launch_error");
            m.terminal_launch_exit_code = try readOptNumberStringOrNull(allocator, tr, "terminal_launch_exit_code");
            m.terminal_launch_ok = try readOptBoolString(allocator, tr, "terminal_launch_ok");
            m.terminal_launch_outcome = readOptStringOrNull(tr, "terminal_launch_outcome");
            m.transport_handshake = readHandshakeField(tr);
            m.transport_timeout_ms = try readOptNumberString(allocator, tr, "timeout_ms");
            m.transport_handshake_latency_ns = try readOptNumberString(allocator, tr, "handshake_latency_ns");
        },
        else => {},
    } else {}

    return m;
}

fn readHandshakeField(tr: std.json.ObjectMap) ?[]const u8 {
    const v = tr.get("handshake") orelse return null;
    return switch (v) {
        .string => |s| s,
        .null => null,
        else => null,
    };
}

fn readOptBoolString(allocator: std.mem.Allocator, obj: std.json.ObjectMap, key: []const u8) !?[]const u8 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .bool => |b| if (b) try allocator.dupe(u8, "true") else try allocator.dupe(u8, "false"),
        .null => null,
        else => return error.InvalidCompareMeta,
    };
}

fn readOptNumberString(allocator: std.mem.Allocator, obj: std.json.ObjectMap, key: []const u8) !?[]const u8 {
    const v = obj.get(key) orelse return null;
    const n = switch (v) {
        .integer => |i| i,
        else => return error.InvalidCompareMeta,
    };
    const s = try std.fmt.allocPrint(allocator, "{d}", .{n});
    return s;
}

fn readOptNumberStringOrNull(allocator: std.mem.Allocator, obj: std.json.ObjectMap, key: []const u8) !?[]const u8 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .integer => |i| try std.fmt.allocPrint(allocator, "{d}", .{i}),
        .null => null,
        else => return error.InvalidCompareMeta,
    };
}

fn readOptString(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

fn readOptStringOrNull(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .string => |s| s,
        .null => null,
        else => null,
    };
}

fn allocCanonicalArgvJson(allocator: std.mem.Allocator, items: []const std.json.Value) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    try buf.appendSlice(allocator, "[");
    for (items, 0..) |el, i| {
        if (i > 0) try buf.appendSlice(allocator, ",");
        const st = switch (el) {
            .string => |s| s,
            else => return error.InvalidCompareMeta,
        };
        try buf.append(allocator, '"');
        for (st) |c| {
            switch (c) {
                '"' => try buf.appendSlice(allocator, "\\\""),
                '\\' => try buf.appendSlice(allocator, "\\\\"),
                else => try buf.append(allocator, c),
            }
        }
        try buf.append(allocator, '"');
    }
    try buf.appendSlice(allocator, "]");
    return try buf.toOwnedSlice(allocator);
}

fn metaDelta(l: ?[]const u8, r: ?[]const u8) []const u8 {
    if (l == null and r == null) return "unchanged";
    if (l == null) return "only_right";
    if (r == null) return "only_left";
    if (std.mem.eql(u8, l.?, r.?)) return "unchanged";
    return "changed";
}

// ANA-3907: Canonicalization edge-case detection helpers (work with stored string values from metadata).
fn canonicalization_reason_status(reason: ?[]const u8) ?[]const u8 {
    if (reason == null) return "canonical_null";
    const r = reason.?;
    // Canonical tags: ok, missing_executable, not_executable, spawn_failed, timeout, nonzero_exit, signaled
    if (std.mem.eql(u8, r, "ok") or std.mem.eql(u8, r, "missing_executable") or
        std.mem.eql(u8, r, "not_executable") or std.mem.eql(u8, r, "spawn_failed") or
        std.mem.eql(u8, r, "timeout") or std.mem.eql(u8, r, "nonzero_exit") or
        std.mem.eql(u8, r, "signaled")) {
        return "canonical_tag";
    }
    return "non_canonical_tag";
}

fn canonicalization_elapsed_status(elapsed: ?[]const u8) ?[]const u8 {
    // In metadata, all elapsed values are stored as strings (parsed from JSON)
    // String representations of u32 values are always canonical
    if (elapsed == null) return "canonical_null";
    return "canonical_u32"; // any non-null string from valid JSON parse is canonical
}

fn canonicalization_signal_status(signal: ?[]const u8) ?[]const u8 {
    if (signal == null) return "canonical_null";
    // In metadata, signal values are stored as strings
    // Canonical range is [1, 128], but stored as decimal strings
    // For edge case detection, non-null means it was parsed (canonical) or it's invalid
    return "canonical_signal"; // any non-null string from valid JSON parse is canonical
}

/// Fixed field order for deterministic compare output.
pub fn diffRunMeta(left: RunMeta, right: RunMeta) [87]MetaDiffRow {
    // ANA-3907: Compute canonicalization status before constructing array to avoid compiler confusion
    const can_reason_left = canonicalization_reason_status(left.terminal_launch_diagnostics_reason);
    const can_reason_right = canonicalization_reason_status(right.terminal_launch_diagnostics_reason);
    const can_elapsed_left = canonicalization_elapsed_status(left.terminal_launch_diagnostics_elapsed_ms);
    const can_elapsed_right = canonicalization_elapsed_status(right.terminal_launch_diagnostics_elapsed_ms);
    const can_signal_left = canonicalization_signal_status(left.terminal_launch_diagnostics_signal);
    const can_signal_right = canonicalization_signal_status(right.terminal_launch_diagnostics_signal);

    return .{
        .{ .field = "comparison_id", .left = left.comparison_id, .right = right.comparison_id, .delta = metaDelta(left.comparison_id, right.comparison_id) },
        .{ .field = "execution_mode", .left = left.execution_mode, .right = right.execution_mode, .delta = metaDelta(left.execution_mode, right.execution_mode) },
        .{ .field = "terminal_profile_id", .left = left.terminal_profile_id, .right = right.terminal_profile_id, .delta = metaDelta(left.terminal_profile_id, right.terminal_profile_id) },
        .{ .field = "terminal_cmd_source", .left = left.terminal_cmd_source, .right = right.terminal_cmd_source, .delta = metaDelta(left.terminal_cmd_source, right.terminal_cmd_source) },
        .{ .field = "resolved_terminal_cmd", .left = left.resolved_terminal_cmd, .right = right.resolved_terminal_cmd, .delta = metaDelta(left.resolved_terminal_cmd, right.resolved_terminal_cmd) },
        .{ .field = "resolved_terminal_argv", .left = left.resolved_terminal_argv, .right = right.resolved_terminal_argv, .delta = metaDelta(left.resolved_terminal_argv, right.resolved_terminal_argv) },
        .{ .field = "terminal_exec_template_id", .left = left.terminal_exec_template_id, .right = right.terminal_exec_template_id, .delta = metaDelta(left.terminal_exec_template_id, right.terminal_exec_template_id) },
        .{ .field = "terminal_exec_template_version", .left = left.terminal_exec_template_version, .right = right.terminal_exec_template_version, .delta = metaDelta(left.terminal_exec_template_version, right.terminal_exec_template_version) },
        .{ .field = "terminal_exec_resolved_path", .left = left.terminal_exec_resolved_path, .right = right.terminal_exec_resolved_path, .delta = metaDelta(left.terminal_exec_resolved_path, right.terminal_exec_resolved_path) },
        .{ .field = "terminal_exec_resolved_path_normalization", .left = left.terminal_exec_resolved_path_normalization, .right = right.terminal_exec_resolved_path_normalization, .delta = metaDelta(left.terminal_exec_resolved_path_normalization, right.terminal_exec_resolved_path_normalization) },
        .{ .field = "terminal_launch_preflight_ok", .left = left.terminal_launch_preflight_ok, .right = right.terminal_launch_preflight_ok, .delta = metaDelta(left.terminal_launch_preflight_ok, right.terminal_launch_preflight_ok) },
        .{ .field = "terminal_launch_preflight_reason", .left = left.terminal_launch_preflight_reason, .right = right.terminal_launch_preflight_reason, .delta = metaDelta(left.terminal_launch_preflight_reason, right.terminal_launch_preflight_reason) },
        .{ .field = "host_identity_machine", .left = left.host_identity_machine, .right = right.host_identity_machine, .delta = metaDelta(left.host_identity_machine, right.host_identity_machine) },
        .{ .field = "host_identity_release", .left = left.host_identity_release, .right = right.host_identity_release, .delta = metaDelta(left.host_identity_release, right.host_identity_release) },
        .{ .field = "host_identity_sysname", .left = left.host_identity_sysname, .right = right.host_identity_sysname, .delta = metaDelta(left.host_identity_sysname, right.host_identity_sysname) },
        .{ .field = "guarded_opt_in", .left = left.guarded_opt_in, .right = right.guarded_opt_in, .delta = metaDelta(left.guarded_opt_in, right.guarded_opt_in) },
        .{ .field = "guarded_state", .left = left.guarded_state, .right = right.guarded_state, .delta = metaDelta(left.guarded_state, right.guarded_state) },
        .{ .field = "platform", .left = left.platform, .right = right.platform, .delta = metaDelta(left.platform, right.platform) },
        .{ .field = "pty_capability_notes", .left = left.pty_capability_notes, .right = right.pty_capability_notes, .delta = metaDelta(left.pty_capability_notes, right.pty_capability_notes) },
        .{ .field = "pty_experiment_attempt", .left = left.pty_experiment_attempt, .right = right.pty_experiment_attempt, .delta = metaDelta(left.pty_experiment_attempt, right.pty_experiment_attempt) },
        .{ .field = "pty_experiment_elapsed_ns", .left = left.pty_experiment_elapsed_ns, .right = right.pty_experiment_elapsed_ns, .delta = metaDelta(left.pty_experiment_elapsed_ns, right.pty_experiment_elapsed_ns) },
        .{ .field = "pty_experiment_error", .left = left.pty_experiment_error, .right = right.pty_experiment_error, .delta = metaDelta(left.pty_experiment_error, right.pty_experiment_error) },
        .{ .field = "pty_experiment_host_machine", .left = left.pty_experiment_host_machine, .right = right.pty_experiment_host_machine, .delta = metaDelta(left.pty_experiment_host_machine, right.pty_experiment_host_machine) },
        .{ .field = "pty_experiment_host_release", .left = left.pty_experiment_host_release, .right = right.pty_experiment_host_release, .delta = metaDelta(left.pty_experiment_host_release, right.pty_experiment_host_release) },
        .{ .field = "pty_experiment_open_ok", .left = left.pty_experiment_open_ok, .right = right.pty_experiment_open_ok, .delta = metaDelta(left.pty_experiment_open_ok, right.pty_experiment_open_ok) },
        .{ .field = "terminal_launch_attempt", .left = left.terminal_launch_attempt, .right = right.terminal_launch_attempt, .delta = metaDelta(left.terminal_launch_attempt, right.terminal_launch_attempt) },
        .{ .field = "terminal_launch_elapsed_ns", .left = left.terminal_launch_elapsed_ns, .right = right.terminal_launch_elapsed_ns, .delta = metaDelta(left.terminal_launch_elapsed_ns, right.terminal_launch_elapsed_ns) },
        .{ .field = "terminal_launch_error", .left = left.terminal_launch_error, .right = right.terminal_launch_error, .delta = metaDelta(left.terminal_launch_error, right.terminal_launch_error) },
        .{ .field = "terminal_launch_exit_code", .left = left.terminal_launch_exit_code, .right = right.terminal_launch_exit_code, .delta = metaDelta(left.terminal_launch_exit_code, right.terminal_launch_exit_code) },
        .{ .field = "terminal_launch_ok", .left = left.terminal_launch_ok, .right = right.terminal_launch_ok, .delta = metaDelta(left.terminal_launch_ok, right.terminal_launch_ok) },
        .{ .field = "terminal_launch_outcome", .left = left.terminal_launch_outcome, .right = right.terminal_launch_outcome, .delta = metaDelta(left.terminal_launch_outcome, right.terminal_launch_outcome) },
        .{ .field = "run_fingerprint_digest", .left = left.run_fingerprint_digest, .right = right.run_fingerprint_digest, .delta = metaDelta(left.run_fingerprint_digest, right.run_fingerprint_digest) },
        .{ .field = "run_fingerprint_version", .left = left.run_fingerprint_version, .right = right.run_fingerprint_version, .delta = metaDelta(left.run_fingerprint_version, right.run_fingerprint_version) },
        .{ .field = "specset_fingerprint_digest", .left = left.specset_fingerprint_digest, .right = right.specset_fingerprint_digest, .delta = metaDelta(left.specset_fingerprint_digest, right.specset_fingerprint_digest) },
        .{ .field = "specset_fingerprint_version", .left = left.specset_fingerprint_version, .right = right.specset_fingerprint_version, .delta = metaDelta(left.specset_fingerprint_version, right.specset_fingerprint_version) },
        .{ .field = "resultset_fingerprint_digest", .left = left.resultset_fingerprint_digest, .right = right.resultset_fingerprint_digest, .delta = metaDelta(left.resultset_fingerprint_digest, right.resultset_fingerprint_digest) },
        .{ .field = "resultset_fingerprint_version", .left = left.resultset_fingerprint_version, .right = right.resultset_fingerprint_version, .delta = metaDelta(left.resultset_fingerprint_version, right.resultset_fingerprint_version) },
        .{ .field = "transport_fingerprint_digest", .left = left.transport_fingerprint_digest, .right = right.transport_fingerprint_digest, .delta = metaDelta(left.transport_fingerprint_digest, right.transport_fingerprint_digest) },
        .{ .field = "transport_fingerprint_version", .left = left.transport_fingerprint_version, .right = right.transport_fingerprint_version, .delta = metaDelta(left.transport_fingerprint_version, right.transport_fingerprint_version) },
        .{ .field = "exec_summary_fingerprint_digest", .left = left.exec_summary_fingerprint_digest, .right = right.exec_summary_fingerprint_digest, .delta = metaDelta(left.exec_summary_fingerprint_digest, right.exec_summary_fingerprint_digest) },
        .{ .field = "exec_summary_fingerprint_version", .left = left.exec_summary_fingerprint_version, .right = right.exec_summary_fingerprint_version, .delta = metaDelta(left.exec_summary_fingerprint_version, right.exec_summary_fingerprint_version) },
        .{ .field = "context_summary_fingerprint_digest", .left = left.context_summary_fingerprint_digest, .right = right.context_summary_fingerprint_digest, .delta = metaDelta(left.context_summary_fingerprint_digest, right.context_summary_fingerprint_digest) },
        .{ .field = "context_summary_fingerprint_version", .left = left.context_summary_fingerprint_version, .right = right.context_summary_fingerprint_version, .delta = metaDelta(left.context_summary_fingerprint_version, right.context_summary_fingerprint_version) },
        .{ .field = "metadata_envelope_fingerprint_digest", .left = left.metadata_envelope_fingerprint_digest, .right = right.metadata_envelope_fingerprint_digest, .delta = metaDelta(left.metadata_envelope_fingerprint_digest, right.metadata_envelope_fingerprint_digest) },
        .{ .field = "metadata_envelope_fingerprint_version", .left = left.metadata_envelope_fingerprint_version, .right = right.metadata_envelope_fingerprint_version, .delta = metaDelta(left.metadata_envelope_fingerprint_version, right.metadata_envelope_fingerprint_version) },
        .{ .field = "artifact_bundle_fingerprint_digest", .left = left.artifact_bundle_fingerprint_digest, .right = right.artifact_bundle_fingerprint_digest, .delta = metaDelta(left.artifact_bundle_fingerprint_digest, right.artifact_bundle_fingerprint_digest) },
        .{ .field = "artifact_bundle_fingerprint_version", .left = left.artifact_bundle_fingerprint_version, .right = right.artifact_bundle_fingerprint_version, .delta = metaDelta(left.artifact_bundle_fingerprint_version, right.artifact_bundle_fingerprint_version) },
        .{ .field = "report_envelope_fingerprint_digest", .left = left.report_envelope_fingerprint_digest, .right = right.report_envelope_fingerprint_digest, .delta = metaDelta(left.report_envelope_fingerprint_digest, right.report_envelope_fingerprint_digest) },
        .{ .field = "report_envelope_fingerprint_version", .left = left.report_envelope_fingerprint_version, .right = right.report_envelope_fingerprint_version, .delta = metaDelta(left.report_envelope_fingerprint_version, right.report_envelope_fingerprint_version) },
        .{ .field = "compare_envelope_fingerprint_digest", .left = left.compare_envelope_fingerprint_digest, .right = right.compare_envelope_fingerprint_digest, .delta = metaDelta(left.compare_envelope_fingerprint_digest, right.compare_envelope_fingerprint_digest) },
        .{ .field = "compare_envelope_fingerprint_version", .left = left.compare_envelope_fingerprint_version, .right = right.compare_envelope_fingerprint_version, .delta = metaDelta(left.compare_envelope_fingerprint_version, right.compare_envelope_fingerprint_version) },
        .{ .field = "run_envelope_fingerprint_digest", .left = left.run_envelope_fingerprint_digest, .right = right.run_envelope_fingerprint_digest, .delta = metaDelta(left.run_envelope_fingerprint_digest, right.run_envelope_fingerprint_digest) },
        .{ .field = "run_envelope_fingerprint_version", .left = left.run_envelope_fingerprint_version, .right = right.run_envelope_fingerprint_version, .delta = metaDelta(left.run_envelope_fingerprint_version, right.run_envelope_fingerprint_version) },
        .{ .field = "session_envelope_fingerprint_digest", .left = left.session_envelope_fingerprint_digest, .right = right.session_envelope_fingerprint_digest, .delta = metaDelta(left.session_envelope_fingerprint_digest, right.session_envelope_fingerprint_digest) },
        .{ .field = "session_envelope_fingerprint_version", .left = left.session_envelope_fingerprint_version, .right = right.session_envelope_fingerprint_version, .delta = metaDelta(left.session_envelope_fingerprint_version, right.session_envelope_fingerprint_version) },
        .{ .field = "environment_envelope_fingerprint_digest", .left = left.environment_envelope_fingerprint_digest, .right = right.environment_envelope_fingerprint_digest, .delta = metaDelta(left.environment_envelope_fingerprint_digest, right.environment_envelope_fingerprint_digest) },
        .{ .field = "environment_envelope_fingerprint_version", .left = left.environment_envelope_fingerprint_version, .right = right.environment_envelope_fingerprint_version, .delta = metaDelta(left.environment_envelope_fingerprint_version, right.environment_envelope_fingerprint_version) },
        .{ .field = "artifact_manifest_fingerprint_digest", .left = left.artifact_manifest_fingerprint_digest, .right = right.artifact_manifest_fingerprint_digest, .delta = metaDelta(left.artifact_manifest_fingerprint_digest, right.artifact_manifest_fingerprint_digest) },
        .{ .field = "artifact_manifest_fingerprint_version", .left = left.artifact_manifest_fingerprint_version, .right = right.artifact_manifest_fingerprint_version, .delta = metaDelta(left.artifact_manifest_fingerprint_version, right.artifact_manifest_fingerprint_version) },
        .{ .field = "provenance_envelope_fingerprint_digest", .left = left.provenance_envelope_fingerprint_digest, .right = right.provenance_envelope_fingerprint_digest, .delta = metaDelta(left.provenance_envelope_fingerprint_digest, right.provenance_envelope_fingerprint_digest) },
        .{ .field = "provenance_envelope_fingerprint_version", .left = left.provenance_envelope_fingerprint_version, .right = right.provenance_envelope_fingerprint_version, .delta = metaDelta(left.provenance_envelope_fingerprint_version, right.provenance_envelope_fingerprint_version) },
        .{ .field = "integrity_envelope_fingerprint_digest", .left = left.integrity_envelope_fingerprint_digest, .right = right.integrity_envelope_fingerprint_digest, .delta = metaDelta(left.integrity_envelope_fingerprint_digest, right.integrity_envelope_fingerprint_digest) },
        .{ .field = "integrity_envelope_fingerprint_version", .left = left.integrity_envelope_fingerprint_version, .right = right.integrity_envelope_fingerprint_version, .delta = metaDelta(left.integrity_envelope_fingerprint_version, right.integrity_envelope_fingerprint_version) },
        .{ .field = "consistency_envelope_fingerprint_digest", .left = left.consistency_envelope_fingerprint_digest, .right = right.consistency_envelope_fingerprint_digest, .delta = metaDelta(left.consistency_envelope_fingerprint_digest, right.consistency_envelope_fingerprint_digest) },
        .{ .field = "consistency_envelope_fingerprint_version", .left = left.consistency_envelope_fingerprint_version, .right = right.consistency_envelope_fingerprint_version, .delta = metaDelta(left.consistency_envelope_fingerprint_version, right.consistency_envelope_fingerprint_version) },
        .{ .field = "trace_envelope_fingerprint_digest", .left = left.trace_envelope_fingerprint_digest, .right = right.trace_envelope_fingerprint_digest, .delta = metaDelta(left.trace_envelope_fingerprint_digest, right.trace_envelope_fingerprint_digest) },
        .{ .field = "trace_envelope_fingerprint_version", .left = left.trace_envelope_fingerprint_version, .right = right.trace_envelope_fingerprint_version, .delta = metaDelta(left.trace_envelope_fingerprint_version, right.trace_envelope_fingerprint_version) },
        .{ .field = "lineage_envelope_fingerprint_digest", .left = left.lineage_envelope_fingerprint_digest, .right = right.lineage_envelope_fingerprint_digest, .delta = metaDelta(left.lineage_envelope_fingerprint_digest, right.lineage_envelope_fingerprint_digest) },
        .{ .field = "lineage_envelope_fingerprint_version", .left = left.lineage_envelope_fingerprint_version, .right = right.lineage_envelope_fingerprint_version, .delta = metaDelta(left.lineage_envelope_fingerprint_version, right.lineage_envelope_fingerprint_version) },
        .{ .field = "state_envelope_fingerprint_digest", .left = left.state_envelope_fingerprint_digest, .right = right.state_envelope_fingerprint_digest, .delta = metaDelta(left.state_envelope_fingerprint_digest, right.state_envelope_fingerprint_digest) },
        .{ .field = "state_envelope_fingerprint_version", .left = left.state_envelope_fingerprint_version, .right = right.state_envelope_fingerprint_version, .delta = metaDelta(left.state_envelope_fingerprint_version, right.state_envelope_fingerprint_version) },
        .{ .field = "run_group", .left = left.run_group, .right = right.run_group, .delta = metaDelta(left.run_group, right.run_group) },
        .{ .field = "suite", .left = left.suite, .right = right.suite, .delta = metaDelta(left.suite, right.suite) },
        .{ .field = "term", .left = left.term, .right = right.term, .delta = metaDelta(left.term, right.term) },
        .{ .field = "terminal", .left = left.terminal_name, .right = right.terminal_name, .delta = metaDelta(left.terminal_name, right.terminal_name) },
        .{ .field = "transport_handshake", .left = left.transport_handshake, .right = right.transport_handshake, .delta = metaDelta(left.transport_handshake, right.transport_handshake) },
        .{ .field = "transport_handshake_latency_ns", .left = left.transport_handshake_latency_ns, .right = right.transport_handshake_latency_ns, .delta = metaDelta(left.transport_handshake_latency_ns, right.transport_handshake_latency_ns) },
        .{ .field = "transport_mode", .left = left.transport_mode, .right = right.transport_mode, .delta = metaDelta(left.transport_mode, right.transport_mode) },
        .{ .field = "transport_timeout_ms", .left = left.transport_timeout_ms, .right = right.transport_timeout_ms, .delta = metaDelta(left.transport_timeout_ms, right.transport_timeout_ms) },
        // PH1-M37: include diagnostics envelope in metadata rows (at end to preserve original indices).
        .{ .field = "terminal_launch_diagnostics_reason", .left = left.terminal_launch_diagnostics_reason, .right = right.terminal_launch_diagnostics_reason, .delta = metaDelta(left.terminal_launch_diagnostics_reason, right.terminal_launch_diagnostics_reason) },
        .{ .field = "terminal_launch_diagnostics_elapsed_ms", .left = left.terminal_launch_diagnostics_elapsed_ms, .right = right.terminal_launch_diagnostics_elapsed_ms, .delta = metaDelta(left.terminal_launch_diagnostics_elapsed_ms, right.terminal_launch_diagnostics_elapsed_ms) },
        .{ .field = "terminal_launch_diagnostics_signal", .left = left.terminal_launch_diagnostics_signal, .right = right.terminal_launch_diagnostics_signal, .delta = metaDelta(left.terminal_launch_diagnostics_signal, right.terminal_launch_diagnostics_signal) },
        // PH1-M38: include launch diagnostics fingerprint in metadata rows (at end to preserve original indices).
        .{ .field = "terminal_launch_diagnostics_fingerprint_digest", .left = left.terminal_launch_diagnostics_fingerprint_digest, .right = right.terminal_launch_diagnostics_fingerprint_digest, .delta = metaDelta(left.terminal_launch_diagnostics_fingerprint_digest, right.terminal_launch_diagnostics_fingerprint_digest) },
        .{ .field = "terminal_launch_diagnostics_fingerprint_version", .left = left.terminal_launch_diagnostics_fingerprint_version, .right = right.terminal_launch_diagnostics_fingerprint_version, .delta = metaDelta(left.terminal_launch_diagnostics_fingerprint_version, right.terminal_launch_diagnostics_fingerprint_version) },
        // PH1-M39 (ANA-3907): edge-case metadata rows for detecting canonicalization drift.
        .{ .field = "canonicalization_reason_status", .left = can_reason_left, .right = can_reason_right, .delta = metaDelta(can_reason_left, can_reason_right) },
        .{ .field = "canonicalization_elapsed_status", .left = can_elapsed_left, .right = can_elapsed_right, .delta = metaDelta(can_elapsed_left, can_elapsed_right) },
        .{ .field = "canonicalization_signal_status", .left = can_signal_left, .right = can_signal_right, .delta = metaDelta(can_signal_left, can_signal_right) },
    };
}

pub const Row = struct {
    status: []const u8,
    notes: []const u8,
};

/// Parses `results` into a map; skips malformed rows (legacy / lenient).
pub fn parseResultsMap(allocator: std.mem.Allocator, root: std.json.Value) !std.StringHashMap(Row) {
    var map = std.StringHashMap(Row).init(allocator);
    errdefer deinitMap(allocator, &map);

    const obj = switch (root) {
        .object => |o| o,
        else => return error.NotObject,
    };

    const results_val = obj.get("results") orelse return error.MissingResults;
    const arr = switch (results_val) {
        .array => |a| a,
        else => return error.BadResults,
    };

    for (arr.items) |item| {
        const row = switch (item) {
            .object => |r| r,
            else => continue,
        };
        const sid_val = row.get("spec_id") orelse continue;
        const st_val = row.get("status") orelse continue;
        const spec_id = switch (sid_val) {
            .string => |s| s,
            else => continue,
        };
        const status = switch (st_val) {
            .string => |s| s,
            else => continue,
        };
        const notes = blk: {
            const n = row.get("notes") orelse break :blk "";
            break :blk switch (n) {
                .string => |s| s,
                else => "",
            };
        };

        const owned_id = try allocator.dupe(u8, spec_id);
        errdefer allocator.free(owned_id);
        const owned_status = try allocator.dupe(u8, status);
        errdefer allocator.free(owned_status);
        const owned_notes = try allocator.dupe(u8, notes);
        errdefer allocator.free(owned_notes);

        try map.put(owned_id, .{ .status = owned_status, .notes = owned_notes });
    }

    return map;
}

/// Strict parse for `compare`: every result row must have string `spec_id` and `status`; duplicate `spec_id` values are rejected.
pub fn parseResultsMapCompare(allocator: std.mem.Allocator, root: std.json.Value) !std.StringHashMap(Row) {
    var map = std.StringHashMap(Row).init(allocator);
    errdefer deinitMap(allocator, &map);

    const obj = switch (root) {
        .object => |o| o,
        else => return error.NotObject,
    };

    const results_val = obj.get("results") orelse return error.MissingResults;
    const arr = switch (results_val) {
        .array => |a| a,
        else => return error.BadResults,
    };

    for (arr.items) |item| {
        const row = switch (item) {
            .object => |r| r,
            else => return error.InvalidResultRow,
        };
        const sid_val = row.get("spec_id") orelse return error.MissingSpecOrStatus;
        const st_val = row.get("status") orelse return error.MissingSpecOrStatus;
        const spec_id = switch (sid_val) {
            .string => |s| s,
            else => return error.MissingSpecOrStatus,
        };
        const status = switch (st_val) {
            .string => |s| s,
            else => return error.MissingSpecOrStatus,
        };

        if (map.get(spec_id) != null) return error.DuplicateSpecId;

        const notes = blk: {
            const n = row.get("notes") orelse break :blk "";
            break :blk switch (n) {
                .string => |s| s,
                else => "",
            };
        };

        const owned_id = try allocator.dupe(u8, spec_id);
        errdefer allocator.free(owned_id);
        const owned_status = try allocator.dupe(u8, status);
        errdefer allocator.free(owned_status);
        const owned_notes = try allocator.dupe(u8, notes);
        errdefer allocator.free(owned_notes);

        try map.put(owned_id, .{ .status = owned_status, .notes = owned_notes });
    }

    return map;
}

pub fn deinitMap(allocator: std.mem.Allocator, map: *std.StringHashMap(Row)) void {
    var it = map.iterator();
    while (it.next()) |e| {
        allocator.free(e.key_ptr.*);
        allocator.free(e.value_ptr.*.status);
        allocator.free(e.value_ptr.*.notes);
    }
    map.deinit();
}

pub const DiffKind = enum {
    added,
    removed,
    changed,
    unchanged,
};

pub const DiffRow = struct {
    spec_id: []const u8,
    left_status: ?[]const u8,
    right_status: ?[]const u8,
    kind: DiffKind,

    pub fn deinit(self: *DiffRow, allocator: std.mem.Allocator) void {
        allocator.free(self.spec_id);
        if (self.left_status) |s| allocator.free(s);
        if (self.right_status) |s| allocator.free(s);
        self.* = undefined;
    }
};

pub fn diffResults(allocator: std.mem.Allocator, left: *const std.StringHashMap(Row), right: *const std.StringHashMap(Row)) ![]DiffRow {
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    var union_ids: std.ArrayList([]const u8) = .empty;
    defer {
        for (union_ids.items) |s| allocator.free(s);
        union_ids.deinit(allocator);
    }

    var lit = left.iterator();
    while (lit.next()) |e| {
        const k = try allocator.dupe(u8, e.key_ptr.*);
        try union_ids.append(allocator, k);
        try seen.put(e.key_ptr.*, {});
    }

    var rit = right.iterator();
    while (rit.next()) |e| {
        if (seen.get(e.key_ptr.*) != null) continue;
        const k = try allocator.dupe(u8, e.key_ptr.*);
        try union_ids.append(allocator, k);
        try seen.put(e.key_ptr.*, {});
    }

    std.mem.sort([]const u8, union_ids.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    var out: std.ArrayList(DiffRow) = .empty;
    errdefer {
        for (out.items) |*r| r.deinit(allocator);
        out.deinit(allocator);
    }

    for (union_ids.items) |id| {
        const l = left.get(id);
        const r = right.get(id);
        const kind: DiffKind = blk: {
            if (l == null and r != null) break :blk .added;
            if (l != null and r == null) break :blk .removed;
            if (l != null and r != null) {
                if (!std.mem.eql(u8, l.?.status, r.?.status)) break :blk .changed;
                break :blk .unchanged;
            }
            unreachable;
        };

        const spec_id = try allocator.dupe(u8, id);
        errdefer allocator.free(spec_id);

        const ls: ?[]const u8 = if (l) |x| try allocator.dupe(u8, x.status) else null;
        errdefer if (ls) |s| allocator.free(s);
        const rs: ?[]const u8 = if (r) |x| try allocator.dupe(u8, x.status) else null;
        errdefer if (rs) |s| allocator.free(s);

        try out.append(allocator, .{
            .spec_id = spec_id,
            .left_status = ls,
            .right_status = rs,
            .kind = kind,
        });
    }

    return try out.toOwnedSlice(allocator);
}

pub fn deinitDiffRows(allocator: std.mem.Allocator, rows: []DiffRow) void {
    for (rows) |*r| r.deinit(allocator);
    allocator.free(rows);
}

fn tdup(a: std.mem.Allocator, s: []const u8) ![]const u8 {
    return try a.dupe(u8, s);
}

test "diffRunMeta detects execution_mode mismatch" {
    const left = RunMeta{ .execution_mode = "placeholder" };
    const right = RunMeta{ .execution_mode = "protocol_stub" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("execution_mode", rows[1].field);
    try std.testing.expectEqualStrings("changed", rows[1].delta);
}

test "diffRunMeta detects terminal_profile_id mismatch" {
    const left = RunMeta{ .terminal_profile_id = "kitty" };
    const right = RunMeta{ .terminal_profile_id = "ghostty" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_profile_id", rows[2].field);
    try std.testing.expectEqualStrings("changed", rows[2].delta);
}

test "diffRunMeta detects terminal_cmd_source mismatch" {
    const left = RunMeta{ .terminal_cmd_source = "fallback" };
    const right = RunMeta{ .terminal_cmd_source = "profile" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_cmd_source", rows[3].field);
    try std.testing.expectEqualStrings("changed", rows[3].delta);
}

test "diffRunMeta detects resolved_terminal_argv mismatch" {
    const left = RunMeta{ .resolved_terminal_argv = "[\"a\"]" };
    const right = RunMeta{ .resolved_terminal_argv = "[\"b\"]" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("resolved_terminal_argv", rows[5].field);
    try std.testing.expectEqualStrings("changed", rows[5].delta);
}

test "diffRunMeta detects terminal_exec_template_id mismatch" {
    const left = RunMeta{ .terminal_exec_template_id = "kitty_exec_v1" };
    const right = RunMeta{ .terminal_exec_template_id = "ghostty_exec_v1" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_exec_template_id", rows[6].field);
    try std.testing.expectEqualStrings("changed", rows[6].delta);
}

test "diffRunMeta detects terminal_exec_template_version mismatch" {
    const left = RunMeta{ .terminal_exec_template_version = "1" };
    const right = RunMeta{ .terminal_exec_template_version = "2" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_exec_template_version", rows[7].field);
    try std.testing.expectEqualStrings("changed", rows[7].delta);
}

test "diffRunMeta detects terminal_exec_resolved_path mismatch" {
    const left = RunMeta{ .terminal_exec_resolved_path = "/bin/foo" };
    const right = RunMeta{ .terminal_exec_resolved_path = "/bin/bar" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_exec_resolved_path", rows[8].field);
    try std.testing.expectEqualStrings("changed", rows[8].delta);
}

test "diffRunMeta detects terminal_exec_resolved_path_normalization mismatch" {
    const left = RunMeta{ .terminal_exec_resolved_path_normalization = "canonical" };
    const right = RunMeta{ .terminal_exec_resolved_path_normalization = "literal" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_exec_resolved_path_normalization", rows[9].field);
    try std.testing.expectEqualStrings("changed", rows[9].delta);
}

test "diffRunMeta detects terminal_launch_preflight_ok mismatch" {
    const left = RunMeta{ .terminal_launch_preflight_ok = "true" };
    const right = RunMeta{ .terminal_launch_preflight_ok = "false" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_launch_preflight_ok", rows[10].field);
    try std.testing.expectEqualStrings("changed", rows[10].delta);
}

test "diffRunMeta detects terminal_launch_preflight_reason mismatch" {
    const left = RunMeta{ .terminal_launch_preflight_reason = "ok" };
    const right = RunMeta{ .terminal_launch_preflight_reason = "missing_executable" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_launch_preflight_reason", rows[11].field);
    try std.testing.expectEqualStrings("changed", rows[11].delta);
}

test "diffRunMeta detects transport_mode mismatch" {
    const left = RunMeta{ .transport_mode = "none" };
    const right = RunMeta{ .transport_mode = "pty_stub" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("transport_mode", rows[77].field);
    try std.testing.expectEqualStrings("changed", rows[77].delta);
}

test "diffRunMeta detects pty_experiment_open_ok mismatch" {
    const left = RunMeta{ .pty_experiment_open_ok = "true" };
    const right = RunMeta{ .pty_experiment_open_ok = "false" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("pty_experiment_open_ok", rows[24].field);
    try std.testing.expectEqualStrings("changed", rows[24].delta);
}

test "diffRunMeta detects terminal_launch_ok mismatch" {
    const left = RunMeta{ .terminal_launch_ok = "true" };
    const right = RunMeta{ .terminal_launch_ok = "false" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_launch_ok", rows[29].field);
    try std.testing.expectEqualStrings("changed", rows[29].delta);
}

test "diffRunMeta detects terminal_launch_outcome mismatch" {
    const left = RunMeta{ .terminal_launch_outcome = "ok" };
    const right = RunMeta{ .terminal_launch_outcome = "timeout" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("terminal_launch_outcome", rows[30].field);
    try std.testing.expectEqualStrings("changed", rows[30].delta);
}

test "diffRunMeta detects guarded_state mismatch" {
    const left = RunMeta{ .guarded_state = "na" };
    const right = RunMeta{ .guarded_state = "scaffold_only" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("guarded_state", rows[16].field);
    try std.testing.expectEqualStrings("changed", rows[16].delta);
}

test "diffRunMeta detects pty_experiment_host_machine mismatch" {
    const left = RunMeta{ .pty_experiment_host_machine = "x86_64" };
    const right = RunMeta{ .pty_experiment_host_machine = "aarch64" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("pty_experiment_host_machine", rows[22].field);
    try std.testing.expectEqualStrings("changed", rows[22].delta);
}

test "diffRunMeta detects host_identity_release mismatch" {
    const left = RunMeta{ .host_identity_release = "6.1.0" };
    const right = RunMeta{ .host_identity_release = "6.6.0" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("host_identity_release", rows[13].field);
    try std.testing.expectEqualStrings("changed", rows[13].delta);
}

test "diffRunMeta detects run_fingerprint_digest mismatch" {
    const left = RunMeta{ .run_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .run_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("run_fingerprint_digest", rows[31].field);
    try std.testing.expectEqualStrings("changed", rows[31].delta);
}

test "diffRunMeta detects specset_fingerprint_digest mismatch" {
    const left = RunMeta{ .specset_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .specset_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("specset_fingerprint_digest", rows[33].field);
    try std.testing.expectEqualStrings("changed", rows[33].delta);
}

test "diffRunMeta detects resultset_fingerprint_digest mismatch" {
    const left = RunMeta{ .resultset_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .resultset_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("resultset_fingerprint_digest", rows[35].field);
    try std.testing.expectEqualStrings("changed", rows[35].delta);
}

test "diffRunMeta detects transport_fingerprint_digest mismatch" {
    const left = RunMeta{ .transport_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .transport_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("transport_fingerprint_digest", rows[37].field);
    try std.testing.expectEqualStrings("changed", rows[37].delta);
}

test "diffRunMeta detects exec_summary_fingerprint_digest mismatch" {
    const left = RunMeta{ .exec_summary_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .exec_summary_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("exec_summary_fingerprint_digest", rows[39].field);
    try std.testing.expectEqualStrings("changed", rows[39].delta);
}

test "diffRunMeta detects context_summary_fingerprint_digest mismatch" {
    const left = RunMeta{ .context_summary_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .context_summary_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("context_summary_fingerprint_digest", rows[41].field);
    try std.testing.expectEqualStrings("changed", rows[41].delta);
}

test "diffRunMeta detects metadata_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .metadata_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .metadata_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("metadata_envelope_fingerprint_digest", rows[43].field);
    try std.testing.expectEqualStrings("changed", rows[43].delta);
}

test "diffRunMeta detects artifact_bundle_fingerprint_digest mismatch" {
    const left = RunMeta{ .artifact_bundle_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .artifact_bundle_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("artifact_bundle_fingerprint_digest", rows[45].field);
    try std.testing.expectEqualStrings("changed", rows[45].delta);
}

test "diffRunMeta detects report_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .report_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .report_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("report_envelope_fingerprint_digest", rows[47].field);
    try std.testing.expectEqualStrings("changed", rows[47].delta);
}

test "diffRunMeta detects compare_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .compare_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .compare_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("compare_envelope_fingerprint_digest", rows[49].field);
    try std.testing.expectEqualStrings("changed", rows[49].delta);
}

test "diffRunMeta detects run_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .run_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .run_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("run_envelope_fingerprint_digest", rows[51].field);
    try std.testing.expectEqualStrings("changed", rows[51].delta);
}

test "diffRunMeta detects session_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .session_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .session_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("session_envelope_fingerprint_digest", rows[53].field);
    try std.testing.expectEqualStrings("changed", rows[53].delta);
}

test "diffRunMeta detects environment_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .environment_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .environment_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("environment_envelope_fingerprint_digest", rows[55].field);
    try std.testing.expectEqualStrings("changed", rows[55].delta);
}

test "diffRunMeta detects artifact_manifest_fingerprint_digest mismatch" {
    const left = RunMeta{ .artifact_manifest_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .artifact_manifest_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("artifact_manifest_fingerprint_digest", rows[57].field);
    try std.testing.expectEqualStrings("changed", rows[57].delta);
}

test "diffRunMeta detects provenance_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .provenance_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .provenance_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("provenance_envelope_fingerprint_digest", rows[59].field);
    try std.testing.expectEqualStrings("changed", rows[59].delta);
}

test "diffRunMeta detects integrity_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .integrity_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .integrity_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("integrity_envelope_fingerprint_digest", rows[61].field);
    try std.testing.expectEqualStrings("changed", rows[61].delta);
}

test "diffRunMeta detects consistency_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .consistency_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .consistency_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("consistency_envelope_fingerprint_digest", rows[63].field);
    try std.testing.expectEqualStrings("changed", rows[63].delta);
}

test "diffRunMeta detects trace_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .trace_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .trace_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("trace_envelope_fingerprint_digest", rows[65].field);
    try std.testing.expectEqualStrings("changed", rows[65].delta);
}

test "diffRunMeta detects lineage_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .lineage_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .lineage_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("lineage_envelope_fingerprint_digest", rows[67].field);
    try std.testing.expectEqualStrings("changed", rows[67].delta);
}

test "diffRunMeta detects state_envelope_fingerprint_digest mismatch" {
    const left = RunMeta{ .state_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    const right = RunMeta{ .state_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };
    const rows = diffRunMeta(left, right);
    try std.testing.expectEqualStrings("state_envelope_fingerprint_digest", rows[69].field);
    try std.testing.expectEqualStrings("changed", rows[69].delta);
}

test "parseRunMeta reads terminal profile fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const text =
        \\{"terminal_profile_id":"ghostty","terminal_cmd_source":"profile","resolved_terminal_cmd":"ghostty","resolved_terminal_argv":["ghostty"],"terminal_exec_template_id":"ghostty_exec_v1","terminal_exec_template_version":"1","terminal_exec_resolved_path":"/usr/bin/ghostty","terminal_exec_resolved_path_normalization":"canonical","terminal_launch_preflight_ok":true,"terminal_launch_preflight_reason":"ok"}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    const m = try parseRunMeta(a, parsed.value);
    try std.testing.expectEqualStrings("ghostty", m.terminal_profile_id.?);
    try std.testing.expectEqualStrings("profile", m.terminal_cmd_source.?);
    try std.testing.expectEqualStrings("ghostty", m.resolved_terminal_cmd.?);
    try std.testing.expectEqualStrings("[\"ghostty\"]", m.resolved_terminal_argv.?);
    try std.testing.expectEqualStrings("ghostty_exec_v1", m.terminal_exec_template_id.?);
    try std.testing.expectEqualStrings("1", m.terminal_exec_template_version.?);
    try std.testing.expectEqualStrings("/usr/bin/ghostty", m.terminal_exec_resolved_path.?);
    try std.testing.expectEqualStrings("canonical", m.terminal_exec_resolved_path_normalization.?);
    try std.testing.expectEqualStrings("true", m.terminal_launch_preflight_ok.?);
    try std.testing.expectEqualStrings("ok", m.terminal_launch_preflight_reason.?);
}

test "parseRunMeta reads root host identity fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const text =
        \\{"host_identity_machine":"aarch64","host_identity_release":"6.6.0","host_identity_sysname":"Linux","run_fingerprint_digest":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","run_fingerprint_version":"1","specset_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","specset_fingerprint_version":"1","resultset_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","resultset_fingerprint_version":"1","transport_fingerprint_digest":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","transport_fingerprint_version":"3","exec_summary_fingerprint_digest":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","exec_summary_fingerprint_version":"1","context_summary_fingerprint_digest":"1111111111111111111111111111111111111111111111111111111111111111","context_summary_fingerprint_version":"1","metadata_envelope_fingerprint_digest":"2222222222222222222222222222222222222222222222222222222222222222","metadata_envelope_fingerprint_version":"1","artifact_bundle_fingerprint_digest":"3333333333333333333333333333333333333333333333333333333333333333","artifact_bundle_fingerprint_version":"1","report_envelope_fingerprint_digest":"4444444444444444444444444444444444444444444444444444444444444444","report_envelope_fingerprint_version":"1","compare_envelope_fingerprint_digest":"5555555555555555555555555555555555555555555555555555555555555555","compare_envelope_fingerprint_version":"1","run_envelope_fingerprint_digest":"6666666666666666666666666666666666666666666666666666666666666666","run_envelope_fingerprint_version":"1","session_envelope_fingerprint_digest":"7777777777777777777777777777777777777777777777777777777777777777","session_envelope_fingerprint_version":"1","environment_envelope_fingerprint_digest":"8888888888888888888888888888888888888888888888888888888888888888","environment_envelope_fingerprint_version":"1","artifact_manifest_fingerprint_digest":"9999999999999999999999999999999999999999999999999999999999999999","artifact_manifest_fingerprint_version":"1","provenance_envelope_fingerprint_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provenance_envelope_fingerprint_version":"1","integrity_envelope_fingerprint_digest":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","integrity_envelope_fingerprint_version":"1","consistency_envelope_fingerprint_digest":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","consistency_envelope_fingerprint_version":"1","trace_envelope_fingerprint_digest":"feedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeed","trace_envelope_fingerprint_version":"1","lineage_envelope_fingerprint_digest":"c0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0de","lineage_envelope_fingerprint_version":"1","state_envelope_fingerprint_digest":"cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe","state_envelope_fingerprint_version":"1","transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":1}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    const m = try parseRunMeta(a, parsed.value);
    try std.testing.expectEqualStrings("aarch64", m.host_identity_machine.?);
    try std.testing.expectEqualStrings("6.6.0", m.host_identity_release.?);
    try std.testing.expectEqualStrings("Linux", m.host_identity_sysname.?);
    try std.testing.expectEqualStrings("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", m.run_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.run_fingerprint_version.?);
    try std.testing.expectEqualStrings("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", m.specset_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.specset_fingerprint_version.?);
    try std.testing.expectEqualStrings("dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd", m.resultset_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.resultset_fingerprint_version.?);
    try std.testing.expectEqualStrings("eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", m.transport_fingerprint_digest.?);
    try std.testing.expectEqualStrings("3", m.transport_fingerprint_version.?);
    try std.testing.expectEqualStrings("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", m.exec_summary_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.exec_summary_fingerprint_version.?);
    try std.testing.expectEqualStrings("1111111111111111111111111111111111111111111111111111111111111111", m.context_summary_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.context_summary_fingerprint_version.?);
    try std.testing.expectEqualStrings("2222222222222222222222222222222222222222222222222222222222222222", m.metadata_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.metadata_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("3333333333333333333333333333333333333333333333333333333333333333", m.artifact_bundle_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.artifact_bundle_fingerprint_version.?);
    try std.testing.expectEqualStrings("4444444444444444444444444444444444444444444444444444444444444444", m.report_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.report_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("5555555555555555555555555555555555555555555555555555555555555555", m.compare_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.compare_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("6666666666666666666666666666666666666666666666666666666666666666", m.run_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.run_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("7777777777777777777777777777777777777777777777777777777777777777", m.session_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.session_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("8888888888888888888888888888888888888888888888888888888888888888", m.environment_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.environment_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("9999999999999999999999999999999999999999999999999999999999999999", m.artifact_manifest_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.artifact_manifest_fingerprint_version.?);
    try std.testing.expectEqualStrings("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", m.provenance_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.provenance_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", m.integrity_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.integrity_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd", m.consistency_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.consistency_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("feedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeedfeed", m.trace_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.trace_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("c0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0de", m.lineage_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.lineage_envelope_fingerprint_version.?);
    try std.testing.expectEqualStrings("cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe", m.state_envelope_fingerprint_digest.?);
    try std.testing.expectEqualStrings("1", m.state_envelope_fingerprint_version.?);
}

test "parseRunMeta reads PTY experiment telemetry numbers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const text =
        \\{"transport":{"guarded_opt_in":true,"guarded_state":"experiment_linux_pty","handshake":"x","handshake_latency_ns":1,"mode":"pty_guarded","pty_capability_notes":"n","pty_experiment_attempt":1,"pty_experiment_elapsed_ns":99,"pty_experiment_error":null,"pty_experiment_host_machine":"x86_64","pty_experiment_host_release":"6.1.0","pty_experiment_open_ok":true,"terminal_launch_attempt":1,"terminal_launch_elapsed_ns":5,"terminal_launch_error":null,"terminal_launch_exit_code":0,"terminal_launch_ok":true,"terminal_launch_outcome":"ok","timeout_ms":1}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    const m = try parseRunMeta(a, parsed.value);
    try std.testing.expectEqualStrings("1", m.pty_experiment_attempt.?);
    try std.testing.expectEqualStrings("99", m.pty_experiment_elapsed_ns.?);
    try std.testing.expectEqualStrings("x86_64", m.pty_experiment_host_machine.?);
    try std.testing.expectEqualStrings("6.1.0", m.pty_experiment_host_release.?);
    try std.testing.expectEqualStrings("1", m.terminal_launch_attempt.?);
    try std.testing.expectEqualStrings("5", m.terminal_launch_elapsed_ns.?);
    try std.testing.expectEqualStrings("0", m.terminal_launch_exit_code.?);
    try std.testing.expectEqualStrings("true", m.terminal_launch_ok.?);
    try std.testing.expectEqualStrings("ok", m.terminal_launch_outcome.?);
}

test "parseRunMeta reads null PTY host fields for scaffold_only" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const text =
        \\{"transport":{"guarded_opt_in":true,"guarded_state":"scaffold_only","handshake":"guarded-handshake-v1","handshake_latency_ns":99,"mode":"pty_guarded","pty_capability_notes":null,"pty_experiment_attempt":null,"pty_experiment_elapsed_ns":null,"pty_experiment_error":null,"pty_experiment_host_machine":null,"pty_experiment_host_release":null,"pty_experiment_open_ok":null,"terminal_launch_attempt":null,"terminal_launch_elapsed_ns":null,"terminal_launch_error":null,"terminal_launch_exit_code":null,"terminal_launch_ok":null,"terminal_launch_outcome":null,"timeout_ms":30000}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    const m = try parseRunMeta(a, parsed.value);
    try std.testing.expect(m.pty_experiment_host_machine == null);
    try std.testing.expect(m.pty_experiment_host_release == null);
    try std.testing.expect(m.terminal_launch_outcome == null);
}

test "parseRunMeta formats transport numeric fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const text =
        \\{"transport":{"guarded_opt_in":false,"guarded_state":"na","handshake":null,"handshake_latency_ns":0,"mode":"none","timeout_ms":5000}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    const m = try parseRunMeta(a, parsed.value);
    try std.testing.expectEqualStrings("none", m.transport_mode.?);
    try std.testing.expectEqualStrings("false", m.guarded_opt_in.?);
    try std.testing.expectEqualStrings("na", m.guarded_state.?);
    try std.testing.expectEqualStrings("5000", m.transport_timeout_ms.?);
    try std.testing.expectEqualStrings("0", m.transport_handshake_latency_ns.?);
}

test "parseResultsMapCompare rejects duplicate spec_id" {
    const a = std.testing.allocator;
    const text =
        \\{"results":[{"spec_id":"x","status":"a"},{"spec_id":"x","status":"b"}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, a, text, .{});
    defer parsed.deinit();
    try std.testing.expectError(error.DuplicateSpecId, parseResultsMapCompare(a, parsed.value));
}

test "parseResultsMapCompare rejects row missing status" {
    const a = std.testing.allocator;
    const text =
        \\{"results":[{"spec_id":"x"}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, a, text, .{});
    defer parsed.deinit();
    try std.testing.expectError(error.MissingSpecOrStatus, parseResultsMapCompare(a, parsed.value));
}

test "diffResults classifies added removed changed unchanged" {
    const a = std.testing.allocator;
    var left = std.StringHashMap(Row).init(a);
    defer deinitMap(a, &left);
    var right = std.StringHashMap(Row).init(a);
    defer deinitMap(a, &right);

    try left.put(try tdup(a, "gone"), .{ .status = try tdup(a, "x"), .notes = try tdup(a, "") });
    try right.put(try tdup(a, "new"), .{ .status = try tdup(a, "y"), .notes = try tdup(a, "") });
    try left.put(try tdup(a, "same"), .{ .status = try tdup(a, "ok"), .notes = try tdup(a, "") });
    try right.put(try tdup(a, "same"), .{ .status = try tdup(a, "ok"), .notes = try tdup(a, "") });
    try left.put(try tdup(a, "diff"), .{ .status = try tdup(a, "a"), .notes = try tdup(a, "") });
    try right.put(try tdup(a, "diff"), .{ .status = try tdup(a, "b"), .notes = try tdup(a, "") });

    const rows = try diffResults(a, &left, &right);
    defer deinitDiffRows(a, rows);

    try std.testing.expectEqual(@as(usize, 4), rows.len);
    try std.testing.expectEqual(DiffKind.changed, rows[0].kind);
    try std.testing.expectEqualStrings("diff", rows[0].spec_id);
    try std.testing.expectEqual(DiffKind.removed, rows[1].kind);
    try std.testing.expectEqualStrings("gone", rows[1].spec_id);
    try std.testing.expectEqual(DiffKind.added, rows[2].kind);
    try std.testing.expectEqualStrings("new", rows[2].spec_id);
    try std.testing.expectEqual(DiffKind.unchanged, rows[3].kind);
    try std.testing.expectEqualStrings("same", rows[3].spec_id);
}
