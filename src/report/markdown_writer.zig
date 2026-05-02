const std = @import("std");
const compat_io = @import("../compat_io.zig");
const run_execute = @import("../runner/run_execute.zig");
const RunContext = @import("../cli/run_context.zig").RunContext;
const terminal_profile = @import("../runner/terminal_profile.zig");

/// Writes a minimal `summary.md` placeholder (`docs/REPORT_FORMAT.md`).
pub fn writePlaceholder(allocator: std.mem.Allocator, run_dir: []const u8, run_id: []const u8) !void {
    var ctx = RunContext.initDefault();
    terminal_profile.resolveEffective(&ctx);
    try writeRunSummary(allocator, run_dir, run_id, &.{}, ctx);
}

pub fn writeRunSummary(
    allocator: std.mem.Allocator,
    run_dir: []const u8,
    run_id: []const u8,
    records: []const run_execute.RunRecord,
    ctx: RunContext,
) !void {
    const path = try std.fmt.allocPrint(allocator, "{s}/summary.md", .{run_dir});
    defer allocator.free(path);

    const term = compat_io.getenv("TERM");

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    try buf.print(allocator, "# Run {s}\n\n## Environment\n\n", .{run_id});
    const cmd_src = if (ctx.terminal_cmd_source.len > 0) ctx.terminal_cmd_source else terminal_profile.source_fallback;
    try buf.print(allocator, "- platform: {s}\n- TERM: {s}\n- terminal (logical): {s}\n- execution_mode: {s}\n- terminal_cmd_source: {s}\n- transport: mode={s} timeout_ms={d}\n", .{ ctx.platform, term, ctx.terminal_name, ctx.execution_mode.tag(), cmd_src, ctx.transport_mode.tag(), ctx.timeout_ms });
    if (ctx.transport_mode == .pty_guarded) {
        if (ctx.dry_run) {
            try buf.appendSlice(allocator, "- guarded transport: scaffold_only (dry-run; deterministic stub handshake)\n");
        } else {
            try buf.print(allocator, "- guarded transport: experiment_linux_pty open_ok={any}\n", .{ctx.pty_experiment_open_ok});
        }
    }
    if (ctx.terminal_profile_id_len > 0) {
        try buf.print(allocator, "- terminal_profile_id: {s}\n", .{ctx.terminal_profile_id_buf[0..ctx.terminal_profile_id_len]});
    }
    if (ctx.terminal_cmd.len > 0) {
        try buf.print(allocator, "- resolved_terminal_cmd: `{s}`\n", .{ctx.terminal_cmd});
    }
    if (ctx.terminal_exec_argc > 0) {
        try buf.appendSlice(allocator, "- resolved_terminal_argv:");
        var i: usize = 0;
        while (i < @as(usize, ctx.terminal_exec_argc)) : (i += 1) {
            try buf.appendSlice(allocator, " `");
            try buf.appendSlice(allocator, ctx.terminal_exec_argv_flat[i][0..ctx.terminal_exec_argv_lens[i]]);
            try buf.appendSlice(allocator, "`");
        }
        try buf.appendSlice(allocator, "\n");
    }
    if (ctx.terminal_exec_template_id_len > 0) {
        try buf.print(allocator, "- terminal_exec_template_id: {s}\n", .{ctx.terminal_exec_template_id_buf[0..ctx.terminal_exec_template_id_len]});
        try buf.print(allocator, "- terminal_exec_template_version: {s}\n", .{ctx.terminal_exec_template_version_buf[0..ctx.terminal_exec_template_version_len]});
    }
    if (ctx.terminal_launch_preflight_ok) |b| {
        try buf.print(allocator, "- terminal_launch_preflight_ok: {any}\n", .{b});
    }
    if (ctx.terminal_launch_preflight_reason) |r| {
        try buf.print(allocator, "- terminal_launch_preflight_reason: {s}\n", .{r});
    }
    if (ctx.terminal_exec_resolved_path_len > 0) {
        try buf.print(allocator, "- terminal_exec_resolved_path: {s}\n", .{ctx.terminal_exec_resolved_path_buf[0..ctx.terminal_exec_resolved_path_len]});
    }
    if (ctx.terminal_exec_resolved_path_normalization) |tag| {
        try buf.print(allocator, "- terminal_exec_resolved_path_normalization: {s}\n", .{tag});
    }
    if (ctx.suite_name) |s| {
        try buf.print(allocator, "- suite: {s}\n", .{s});
    } else {
        try buf.appendSlice(allocator, "- suite: (direct run)\n");
    }
    if (ctx.comparison_id) |c| {
        try buf.print(allocator, "- comparison_id: {s}\n", .{c});
    }
    if (ctx.run_group) |g| {
        try buf.print(allocator, "- run_group: {s}\n", .{g});
    }
    try buf.appendSlice(allocator, "\n## Results\n\n");

    if (records.len == 0) {
        try buf.appendSlice(allocator, "(none)\n");
    } else {
        for (records) |r| {
            try buf.print(allocator, "- **{s}**: {s} — {s}\n", .{ r.spec_id, r.status, r.notes });
        }
    }

    try compat_io.writeFile(.{ .sub_path = path, .data = buf.items });
}
