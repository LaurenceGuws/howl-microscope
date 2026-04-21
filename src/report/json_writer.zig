const std = @import("std");
const run_execute = @import("../runner/run_execute.zig");
const RunContext = @import("../cli/run_context.zig").RunContext;
const terminal_profile = @import("../runner/terminal_profile.zig");
const run_json_validate = @import("run_json_validate.zig");
const transport_stub = @import("../runner/transport_stub.zig");
const run_fingerprint = @import("run_fingerprint.zig");
const specset_fingerprint = @import("specset_fingerprint.zig");
const resultset_fingerprint = @import("resultset_fingerprint.zig");
const transport_fingerprint = @import("transport_fingerprint.zig");
const exec_summary_fingerprint = @import("exec_summary_fingerprint.zig");
const context_summary_fingerprint = @import("context_summary_fingerprint.zig");
const metadata_envelope_fingerprint = @import("metadata_envelope_fingerprint.zig");
const artifact_bundle_fingerprint = @import("artifact_bundle_fingerprint.zig");
const report_envelope_fingerprint = @import("report_envelope_fingerprint.zig");
const compare_envelope_fingerprint = @import("compare_envelope_fingerprint.zig");
const run_envelope_fingerprint = @import("run_envelope_fingerprint.zig");
const session_envelope_fingerprint = @import("session_envelope_fingerprint.zig");
const environment_envelope_fingerprint = @import("environment_envelope_fingerprint.zig");
const artifact_manifest_fingerprint = @import("artifact_manifest_fingerprint.zig");
const provenance_envelope_fingerprint = @import("provenance_envelope_fingerprint.zig");
const integrity_envelope_fingerprint = @import("integrity_envelope_fingerprint.zig");
const consistency_envelope_fingerprint = @import("consistency_envelope_fingerprint.zig");
const trace_envelope_fingerprint = @import("trace_envelope_fingerprint.zig");
const lineage_envelope_fingerprint = @import("lineage_envelope_fingerprint.zig");
const state_envelope_fingerprint = @import("state_envelope_fingerprint.zig");

fn appendJsonEncodedString(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), bytes: []const u8) !void {
    var enc: std.io.Writer.Allocating = .init(allocator);
    defer enc.deinit();
    try std.json.Stringify.encodeJsonString(bytes, .{}, &enc.writer);
    try buf.appendSlice(allocator, enc.written());
}

/// Writes a minimal `run.json` placeholder (`docs/REPORT_FORMAT.md`).
pub fn writePlaceholder(allocator: std.mem.Allocator, run_dir: []const u8, run_id: []const u8) !void {
    var ctx = RunContext.initDefault();
    terminal_profile.resolveEffective(&ctx);
    ctx.captureHostIdentity();
    try run_fingerprint.populate(&ctx, allocator, run_id, &.{});
    try specset_fingerprint.populate(&ctx, allocator, &.{});
    try resultset_fingerprint.populate(&ctx, allocator, &.{});
    try transport_fingerprint.populate(&ctx, allocator, run_id);
    try exec_summary_fingerprint.populate(&ctx, allocator);
    const term_ph = std.posix.getenv("TERM") orelse "";
    try context_summary_fingerprint.populate(&ctx, allocator, term_ph);
    try metadata_envelope_fingerprint.populate(&ctx, allocator);
    try artifact_bundle_fingerprint.populate(&ctx, allocator);
    try report_envelope_fingerprint.populate(&ctx, allocator);
    try compare_envelope_fingerprint.populate(&ctx, allocator);
    try run_envelope_fingerprint.populate(&ctx, allocator);
    try session_envelope_fingerprint.populate(&ctx, allocator);
    try environment_envelope_fingerprint.populate(&ctx, allocator);
    try artifact_manifest_fingerprint.populate(&ctx, allocator);
    try provenance_envelope_fingerprint.populate(&ctx, allocator);
    try integrity_envelope_fingerprint.populate(&ctx, allocator);
    try consistency_envelope_fingerprint.populate(&ctx, allocator);
    try trace_envelope_fingerprint.populate(&ctx, allocator);
    try lineage_envelope_fingerprint.populate(&ctx, allocator);
    try state_envelope_fingerprint.populate(&ctx, allocator);
    try writeRun(allocator, run_dir, run_id, &.{}, ctx);
}

/// Writes `run.json` including one entry per `RunRecord` and PH1-M2 identity fields.
pub fn writeRun(
    allocator: std.mem.Allocator,
    run_dir: []const u8,
    run_id: []const u8,
    records: []const run_execute.RunRecord,
    ctx: RunContext,
) !void {
    const path = try std.fmt.allocPrint(allocator, "{s}/run.json", .{run_dir});
    defer allocator.free(path);

    const term = std.posix.getenv("TERM") orelse "";

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    try buf.print(allocator,
        "{{\n  \"schema_version\": \"0.2\",\n  \"run_id\": \"{s}\",\n  \"platform\": \"{s}\",\n  \"term\": \"{s}\",\n  \"terminal\": {{\n    \"name\": \"{s}\",\n    \"version\": \"\"\n  }}",
        .{ run_id, ctx.platform, term, ctx.terminal_name },
    );

    if (ctx.suite_name) |s| {
        try buf.print(allocator, ",\n  \"suite\": \"{s}\"", .{s});
    } else {
        try buf.appendSlice(allocator, ",\n  \"suite\": null");
    }

    if (ctx.comparison_id) |s| {
        try buf.print(allocator, ",\n  \"comparison_id\": \"{s}\"", .{s});
    } else {
        try buf.appendSlice(allocator, ",\n  \"comparison_id\": null");
    }

    if (ctx.run_group) |s| {
        try buf.print(allocator, ",\n  \"run_group\": \"{s}\"", .{s});
    } else {
        try buf.appendSlice(allocator, ",\n  \"run_group\": null");
    }

    try buf.print(allocator, ",\n  \"execution_mode\": \"{s}\"", .{ctx.execution_mode.tag()});

    if (ctx.terminal_profile_id_len == 0) {
        try buf.appendSlice(allocator, ",\n  \"terminal_profile_id\": null");
    } else {
        try buf.appendSlice(allocator, ",\n  \"terminal_profile_id\": ");
        try appendJsonEncodedString(allocator, &buf, ctx.terminal_profile_id_buf[0..ctx.terminal_profile_id_len]);
    }
    const src = if (ctx.terminal_cmd_source.len > 0) ctx.terminal_cmd_source else terminal_profile.source_fallback;
    try buf.appendSlice(allocator, ",\n  \"terminal_cmd_source\": ");
    try appendJsonEncodedString(allocator, &buf, src);
    try buf.appendSlice(allocator, ",\n  \"resolved_terminal_cmd\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.terminal_cmd);

    try buf.appendSlice(allocator, ",\n  \"resolved_terminal_argv\": [");
    {
        var i: usize = 0;
        while (i < @as(usize, ctx.terminal_exec_argc)) : (i += 1) {
            if (i > 0) try buf.appendSlice(allocator, ", ");
            try appendJsonEncodedString(allocator, &buf, ctx.terminal_exec_argv_flat[i][0..ctx.terminal_exec_argv_lens[i]]);
        }
    }
    try buf.appendSlice(allocator, "]");

    if (ctx.terminal_exec_template_id_len == 0) {
        try buf.appendSlice(allocator, ",\n  \"terminal_exec_template_id\": null");
    } else {
        try buf.appendSlice(allocator, ",\n  \"terminal_exec_template_id\": ");
        try appendJsonEncodedString(allocator, &buf, ctx.terminal_exec_template_id_buf[0..ctx.terminal_exec_template_id_len]);
    }
    if (ctx.terminal_exec_template_id_len == 0) {
        try buf.appendSlice(allocator, ",\n  \"terminal_exec_template_version\": null");
    } else {
        try buf.appendSlice(allocator, ",\n  \"terminal_exec_template_version\": ");
        try appendJsonEncodedString(allocator, &buf, ctx.terminal_exec_template_version_buf[0..ctx.terminal_exec_template_version_len]);
    }

    try buf.appendSlice(allocator, ",\n  \"terminal_exec_resolved_path\": ");
    if (ctx.terminal_exec_resolved_path_len == 0) {
        try buf.appendSlice(allocator, "null");
    } else {
        try appendJsonEncodedString(allocator, &buf, ctx.terminal_exec_resolved_path_buf[0..ctx.terminal_exec_resolved_path_len]);
    }
    try buf.appendSlice(allocator, ",\n  \"terminal_exec_resolved_path_normalization\": ");
    if (ctx.terminal_exec_resolved_path_normalization) |tag| {
        try appendJsonEncodedString(allocator, &buf, tag);
    } else {
        try buf.appendSlice(allocator, "null");
    }
    try buf.appendSlice(allocator, ",\n  \"terminal_launch_preflight_ok\": ");
    if (ctx.terminal_launch_preflight_ok) |b| {
        try buf.print(allocator, "{}", .{b});
    } else {
        try buf.appendSlice(allocator, "null");
    }
    try buf.appendSlice(allocator, ",\n  \"terminal_launch_preflight_reason\": ");
    if (ctx.terminal_launch_preflight_reason) |r| {
        try appendJsonEncodedString(allocator, &buf, r);
    } else {
        try buf.appendSlice(allocator, "null");
    }

    // PH1-M37: emit diagnostics envelope fields.
    try buf.appendSlice(allocator, ",\n  \"terminal_launch_diagnostics_reason\": ");
    if (ctx.terminal_launch_diagnostics_reason_len > 0) {
        const reason = ctx.terminal_launch_diagnostics_reason_buf[0..ctx.terminal_launch_diagnostics_reason_len];
        try appendJsonEncodedString(allocator, &buf, reason);
    } else {
        try buf.appendSlice(allocator, "null");
    }
    try buf.appendSlice(allocator, ",\n  \"terminal_launch_diagnostics_elapsed_ms\": ");
    if (ctx.terminal_launch_diagnostics_elapsed_ms) |ms| {
        try buf.writer(allocator).print("{d}", .{ms});
    } else {
        try buf.appendSlice(allocator, "null");
    }
    try buf.appendSlice(allocator, ",\n  \"terminal_launch_diagnostics_signal\": ");
    if (ctx.terminal_launch_diagnostics_signal) |sig| {
        try buf.writer(allocator).print("{d}", .{sig});
    } else {
        try buf.appendSlice(allocator, "null");
    }

    try buf.appendSlice(allocator, ",\n  \"terminal_launch_diagnostics_fingerprint_digest\": ");
    if (ctx.launch_diagnostics_fingerprint_digest_len > 0) {
        try appendJsonEncodedString(allocator, &buf, ctx.launch_diagnostics_fingerprint_digest_hex[0..ctx.launch_diagnostics_fingerprint_digest_len]);
    } else {
        try buf.appendSlice(allocator, "null");
    }
    try buf.appendSlice(allocator, ",\n  \"terminal_launch_diagnostics_fingerprint_version\": ");
    if (ctx.launch_diagnostics_fingerprint_digest_len > 0) {
        try buf.appendSlice(allocator, "\"1\"");
    } else {
        try buf.appendSlice(allocator, "null");
    }

    try buf.appendSlice(allocator, ",\n  \"host_identity_machine\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.host_identity_machine[0..ctx.host_identity_machine_len]);
    try buf.appendSlice(allocator, ",\n  \"host_identity_release\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.host_identity_release[0..ctx.host_identity_release_len]);
    try buf.appendSlice(allocator, ",\n  \"host_identity_sysname\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.host_identity_sysname[0..ctx.host_identity_sysname_len]);

    try buf.appendSlice(allocator, ",\n  \"run_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.run_fingerprint_digest_hex[0..ctx.run_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"run_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"specset_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.specset_fingerprint_digest_hex[0..ctx.specset_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"specset_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"resultset_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.resultset_fingerprint_digest_hex[0..ctx.resultset_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"resultset_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"transport_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.transport_fingerprint_digest_hex[0..ctx.transport_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"transport_fingerprint_version\": \"3\"");
    try buf.appendSlice(allocator, ",\n  \"exec_summary_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.exec_summary_fingerprint_digest_hex[0..ctx.exec_summary_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"exec_summary_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"context_summary_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.context_summary_fingerprint_digest_hex[0..ctx.context_summary_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"context_summary_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"metadata_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.metadata_envelope_fingerprint_digest_hex[0..ctx.metadata_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"metadata_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"artifact_bundle_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.artifact_bundle_fingerprint_digest_hex[0..ctx.artifact_bundle_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"artifact_bundle_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"report_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.report_envelope_fingerprint_digest_hex[0..ctx.report_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"report_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"compare_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.compare_envelope_fingerprint_digest_hex[0..ctx.compare_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"compare_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"run_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.run_envelope_fingerprint_digest_hex[0..ctx.run_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"run_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"session_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.session_envelope_fingerprint_digest_hex[0..ctx.session_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"session_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"environment_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.environment_envelope_fingerprint_digest_hex[0..ctx.environment_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"environment_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"artifact_manifest_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.artifact_manifest_fingerprint_digest_hex[0..ctx.artifact_manifest_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"artifact_manifest_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"provenance_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.provenance_envelope_fingerprint_digest_hex[0..ctx.provenance_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"provenance_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"integrity_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.integrity_envelope_fingerprint_digest_hex[0..ctx.integrity_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"integrity_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"consistency_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.consistency_envelope_fingerprint_digest_hex[0..ctx.consistency_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"consistency_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"trace_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.trace_envelope_fingerprint_digest_hex[0..ctx.trace_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"trace_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"lineage_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.lineage_envelope_fingerprint_digest_hex[0..ctx.lineage_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"lineage_envelope_fingerprint_version\": \"1\"");
    try buf.appendSlice(allocator, ",\n  \"state_envelope_fingerprint_digest\": ");
    try appendJsonEncodedString(allocator, &buf, ctx.state_envelope_fingerprint_digest_hex[0..ctx.state_envelope_fingerprint_digest_len]);
    try buf.appendSlice(allocator, ",\n  \"state_envelope_fingerprint_version\": \"1\"");

    const guarded_opt_in = ctx.transport_mode == .pty_guarded;
    const guarded_state: []const u8 = blk: {
        if (ctx.transport_mode != .pty_guarded) break :blk "na";
        if (ctx.dry_run) break :blk "scaffold_only";
        break :blk "experiment_linux_pty";
    };

    try buf.appendSlice(allocator, ",\n  \"transport\": {\n");
    try buf.print(allocator, "    \"guarded_opt_in\": {},\n", .{guarded_opt_in});
    try buf.print(allocator, "    \"guarded_state\": \"{s}\",\n", .{guarded_state});
    try buf.appendSlice(allocator, "    \"handshake\": ");
    if (transport_stub.handshakeString(ctx.transport_mode)) |hs| {
        try buf.print(allocator, "\"{s}\"", .{hs});
    } else {
        try buf.appendSlice(allocator, "null");
    }
    const lat_ns = transport_stub.handshakeLatencyNs(ctx.transport_mode, run_id);
    try buf.print(allocator, ",\n    \"handshake_latency_ns\": {d},\n    \"mode\": \"{s}\"", .{ lat_ns, ctx.transport_mode.tag() });

    if (ctx.transport_mode == .pty_guarded) {
        try buf.appendSlice(allocator, ",\n    \"pty_capability_notes\": ");
        if (ctx.pty_capability_notes) |n| {
            try buf.print(allocator, "\"{s}\"", .{n});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"pty_experiment_attempt\": ");
        if (ctx.pty_experiment_attempt) |a| {
            try buf.print(allocator, "{d}", .{a});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"pty_experiment_elapsed_ns\": ");
        if (ctx.pty_experiment_elapsed_ns) |e| {
            try buf.print(allocator, "{d}", .{e});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"pty_experiment_error\": ");
        if (ctx.pty_experiment_error) |e| {
            try buf.print(allocator, "\"{s}\"", .{e});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        const pty_host_null = std.mem.eql(u8, guarded_state, "scaffold_only");
        try buf.appendSlice(allocator, ",\n    \"pty_experiment_host_machine\": ");
        if (pty_host_null) {
            try buf.appendSlice(allocator, "null");
        } else {
            var enc: std.io.Writer.Allocating = .init(allocator);
            defer enc.deinit();
            try std.json.Stringify.encodeJsonString(
                ctx.pty_experiment_host_machine[0..ctx.pty_experiment_host_machine_len],
                .{},
                &enc.writer,
            );
            try buf.appendSlice(allocator, enc.written());
        }
        try buf.appendSlice(allocator, ",\n    \"pty_experiment_host_release\": ");
        if (pty_host_null) {
            try buf.appendSlice(allocator, "null");
        } else {
            var enc2: std.io.Writer.Allocating = .init(allocator);
            defer enc2.deinit();
            try std.json.Stringify.encodeJsonString(
                ctx.pty_experiment_host_release[0..ctx.pty_experiment_host_release_len],
                .{},
                &enc2.writer,
            );
            try buf.appendSlice(allocator, enc2.written());
        }
        try buf.appendSlice(allocator, ",\n    \"pty_experiment_open_ok\": ");
        if (ctx.pty_experiment_open_ok) |b| {
            try buf.print(allocator, "{}", .{b});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"terminal_launch_attempt\": ");
        if (ctx.terminal_launch_attempt) |a| {
            try buf.print(allocator, "{d}", .{a});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"terminal_launch_elapsed_ns\": ");
        if (ctx.terminal_launch_elapsed_ns) |e| {
            try buf.print(allocator, "{d}", .{e});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"terminal_launch_error\": ");
        if (ctx.terminal_launch_error) |e| {
            try buf.print(allocator, "\"{s}\"", .{e});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"terminal_launch_exit_code\": ");
        if (ctx.terminal_launch_exit_code) |c| {
            try buf.print(allocator, "{d}", .{c});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"terminal_launch_ok\": ");
        if (ctx.terminal_launch_ok) |b| {
            try buf.print(allocator, "{}", .{b});
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n    \"terminal_launch_outcome\": ");
        if (ctx.terminal_launch_outcome) |o| {
            try buf.print(allocator, "\"{s}\"", .{o});
        } else {
            try buf.appendSlice(allocator, "null");
        }
    }

    try buf.print(allocator, ",\n    \"timeout_ms\": {d}\n  }}", .{ctx.timeout_ms});

    try buf.appendSlice(allocator, ",\n  \"started_at\": \"\",\n  \"ended_at\": \"\",\n  \"results\": [\n");

    for (records, 0..) |r, i| {
        if (i > 0) try buf.appendSlice(allocator, ",\n");
        try buf.print(allocator,
            "    {{\"spec_id\":\"{s}\",\"status\":\"{s}\",\"notes\":\"{s}\",\"capture_mode\":\"{s}\",\"observations\":{s}}}",
            .{ r.spec_id, r.status, r.notes, r.capture_mode, r.observations_json },
        );
    }
    try buf.appendSlice(allocator, "\n  ]\n}\n");

    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = buf.items });
}

test "writeRun JSON-encodes guarded PTY host snapshot strings" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_dir = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(run_dir);

    var ctx = RunContext.initDefault();
    ctx.platform = "linux";
    ctx.terminal_name = "t";
    ctx.transport_mode = .pty_guarded;
    ctx.dry_run = false;
    ctx.pty_capability_notes = "linux /dev/ptmx";
    ctx.pty_experiment_attempt = 1;
    ctx.pty_experiment_elapsed_ns = 0;
    ctx.pty_experiment_open_ok = true;
    ctx.pty_experiment_error = null;
    ctx.captureHostIdentity();
    try run_fingerprint.populate(&ctx, std.testing.allocator, "rid-json-writer", &.{});
    try specset_fingerprint.populate(&ctx, std.testing.allocator, &.{});
    try resultset_fingerprint.populate(&ctx, std.testing.allocator, &.{});
    try transport_fingerprint.populate(&ctx, std.testing.allocator, "rid-json-writer");
    try exec_summary_fingerprint.populate(&ctx, std.testing.allocator);
    const term_w = std.posix.getenv("TERM") orelse "";
    try context_summary_fingerprint.populate(&ctx, std.testing.allocator, term_w);
    try metadata_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try artifact_bundle_fingerprint.populate(&ctx, std.testing.allocator);
    try report_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try compare_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try run_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try session_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try environment_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try artifact_manifest_fingerprint.populate(&ctx, std.testing.allocator);
    try provenance_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try integrity_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try consistency_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try trace_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try lineage_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try state_envelope_fingerprint.populate(&ctx, std.testing.allocator);

    const mach = "x86_64";
    const rel = "6.1.0-test";
    @memcpy(ctx.pty_experiment_host_machine[0..mach.len], mach);
    ctx.pty_experiment_host_machine_len = @intCast(mach.len);
    @memcpy(ctx.pty_experiment_host_release[0..rel.len], rel);
    ctx.pty_experiment_host_release_len = @intCast(rel.len);

    try writeRun(std.testing.allocator, run_dir, "rid-json-writer", &.{}, ctx);

    const json_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/run.json", .{run_dir});
    defer std.testing.allocator.free(json_path);
    const json_text = try std.fs.cwd().readFileAlloc(std.testing.allocator, json_path, 1 << 20);
    defer std.testing.allocator.free(json_text);

    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"pty_experiment_host_machine\": \"x86_64\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"pty_experiment_host_release\": \"6.1.0-test\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"run_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"run_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"specset_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"specset_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"resultset_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"resultset_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"transport_fingerprint_version\": \"3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"transport_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"exec_summary_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"exec_summary_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"context_summary_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"context_summary_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"metadata_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"metadata_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"artifact_bundle_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"artifact_bundle_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"report_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"report_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"compare_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"compare_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"run_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"run_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"session_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"session_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"environment_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"environment_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"artifact_manifest_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"artifact_manifest_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"provenance_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"provenance_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"integrity_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"integrity_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"consistency_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"consistency_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"trace_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"trace_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"lineage_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"lineage_envelope_fingerprint_digest\": \"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"state_envelope_fingerprint_version\": \"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"state_envelope_fingerprint_digest\": \"") != null);

    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_text, .{});
    defer parsed.deinit();
    try std.testing.expect(run_json_validate.validateRunReport(parsed.value) == null);
}

test "writeRun embeds golden metadata_envelope digest for fixed upstream fingerprints" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_dir = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(run_dir);

    var ctx = RunContext.initDefault();
    ctx.platform = "linux";
    ctx.terminal_name = "t";
    ctx.captureHostIdentity();

    const copy64 = struct {
        fn set(dst: *[64]u8, len: *u8, src: *const [64]u8) void {
            @memcpy(dst, src);
            len.* = 64;
        }
    }.set;
    copy64(&ctx.run_fingerprint_digest_hex, &ctx.run_fingerprint_digest_len, &"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    copy64(&ctx.specset_fingerprint_digest_hex, &ctx.specset_fingerprint_digest_len, &"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc".*);
    copy64(&ctx.resultset_fingerprint_digest_hex, &ctx.resultset_fingerprint_digest_len, &"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd".*);
    copy64(&ctx.transport_fingerprint_digest_hex, &ctx.transport_fingerprint_digest_len, &"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee".*);
    copy64(&ctx.exec_summary_fingerprint_digest_hex, &ctx.exec_summary_fingerprint_digest_len, &"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".*);
    copy64(&ctx.context_summary_fingerprint_digest_hex, &ctx.context_summary_fingerprint_digest_len, &"1111111111111111111111111111111111111111111111111111111111111111".*);

    try metadata_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try artifact_bundle_fingerprint.populate(&ctx, std.testing.allocator);
    try report_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try compare_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try run_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try session_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try environment_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try artifact_manifest_fingerprint.populate(&ctx, std.testing.allocator);
    try provenance_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try integrity_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try consistency_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try trace_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try lineage_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try state_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try writeRun(std.testing.allocator, run_dir, "rid-env-golden", &.{}, ctx);

    const json_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/run.json", .{run_dir});
    defer std.testing.allocator.free(json_path);
    const json_text = try std.fs.cwd().readFileAlloc(std.testing.allocator, json_path, 1 << 20);
    defer std.testing.allocator.free(json_text);

    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"metadata_envelope_fingerprint_digest\": \"620d35500e035b198f5a81be6f0a99ba22eb2f86e483fa6abef0ab855f5c5754\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"artifact_bundle_fingerprint_digest\": \"45fb53d285231c8afb41b1153e866b829c28dcd80658b52f0c899948d6949d07\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"report_envelope_fingerprint_digest\": \"8f203c04ec69008d307e5c5e55e0cab9b76c90993626b6f1d4ad4197bcb94b16\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"compare_envelope_fingerprint_digest\": \"67ecac21cb2aa19eacf9be4d930c52e447b35bdc3e6d408fde01fd277c656dcd\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"run_envelope_fingerprint_digest\": \"6eb18d774c8c3625e082076218508331bef799ed368ead1dcde5de6ac5e91a90\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"session_envelope_fingerprint_digest\": \"d9ac103387a17fd9217799a54fd1f2ba121ade49f8a171a0ce00bb7e6e79e0b3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"environment_envelope_fingerprint_digest\": \"dd59e6d080adfc5aac4cbc34c6aff533718ac40fd453ccb8f1ef4f85288e3acc\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"artifact_manifest_fingerprint_digest\": \"090073497e9199080a37d57412b9fac50abc2622b366f3bcfff3ffd66858b3b2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"provenance_envelope_fingerprint_digest\": \"f56eb65942e63e5d5889c29130529cdbf681764c4d2beab18b0d3d8ebcb06e79\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"integrity_envelope_fingerprint_digest\": \"85006478d27f84d40319d5107072b420417a8bf12a81c966bf04e0d15dd01fa0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"consistency_envelope_fingerprint_digest\": \"40b1a4678654405c7d0d72dcc6cc992d8038d983fb28455b34ccba3a2132207a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"trace_envelope_fingerprint_digest\": \"c6c42cdc0e94231e4ae5d1105e5add411bfe274c1a360153993dafb0ad7f31e1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"lineage_envelope_fingerprint_digest\": \"ab0d29132d75a50c33523822984a11df745fa6cd934d2ee9d638b240a84c8659\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"state_envelope_fingerprint_digest\": \"fc9e33e37e4d5cc403f7738cb104509dee956b6cfee8c3170f119ecfa078a6ee\"") != null);

    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_text, .{});
    defer parsed.deinit();
    try std.testing.expect(run_json_validate.validateRunReport(parsed.value) == null);
}

test "writeRun escapes quotes in guarded PTY host snapshot strings" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_dir = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(run_dir);

    var ctx = RunContext.initDefault();
    ctx.platform = "linux";
    ctx.terminal_name = "t";
    ctx.transport_mode = .pty_guarded;
    ctx.dry_run = false;
    ctx.pty_capability_notes = "linux /dev/ptmx";
    ctx.pty_experiment_attempt = 1;
    ctx.pty_experiment_elapsed_ns = 0;
    ctx.pty_experiment_open_ok = true;
    ctx.pty_experiment_error = null;
    ctx.captureHostIdentity();
    try run_fingerprint.populate(&ctx, std.testing.allocator, "rid-json-esc", &.{});
    try specset_fingerprint.populate(&ctx, std.testing.allocator, &.{});
    try resultset_fingerprint.populate(&ctx, std.testing.allocator, &.{});
    try transport_fingerprint.populate(&ctx, std.testing.allocator, "rid-json-esc");
    try exec_summary_fingerprint.populate(&ctx, std.testing.allocator);
    const term_e = std.posix.getenv("TERM") orelse "";
    try context_summary_fingerprint.populate(&ctx, std.testing.allocator, term_e);
    try metadata_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try artifact_bundle_fingerprint.populate(&ctx, std.testing.allocator);
    try report_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try compare_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try run_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try session_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try environment_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try artifact_manifest_fingerprint.populate(&ctx, std.testing.allocator);
    try provenance_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try integrity_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try consistency_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try trace_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try lineage_envelope_fingerprint.populate(&ctx, std.testing.allocator);
    try state_envelope_fingerprint.populate(&ctx, std.testing.allocator);

    const mach: []const u8 = &.{ 'a', 'b', '"', 'c' };
    @memcpy(ctx.pty_experiment_host_machine[0..mach.len], mach);
    ctx.pty_experiment_host_machine_len = @intCast(mach.len);
    const rel = "ok";
    @memcpy(ctx.pty_experiment_host_release[0..rel.len], rel);
    ctx.pty_experiment_host_release_len = @intCast(rel.len);

    try writeRun(std.testing.allocator, run_dir, "rid-json-esc", &.{}, ctx);

    const json_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/run.json", .{run_dir});
    defer std.testing.allocator.free(json_path);
    const json_text = try std.fs.cwd().readFileAlloc(std.testing.allocator, json_path, 1 << 20);
    defer std.testing.allocator.free(json_text);

    try std.testing.expect(std.mem.indexOf(u8, json_text, "\"pty_experiment_host_machine\": \"ab\\\"c\"") != null);

    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_text, .{});
    defer parsed.deinit();
    try std.testing.expect(run_json_validate.validateRunReport(parsed.value) == null);
}
