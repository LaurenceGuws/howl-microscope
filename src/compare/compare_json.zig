const std = @import("std");
const compat_io = @import("../compat_io.zig");
const run_json = @import("run_json.zig");

/// Writes `compare.json` with lexicographically ordered object keys at each level (`schema_version` 0.2 includes `metadata_deltas`).
pub fn writeFile(
    allocator: std.mem.Allocator,
    path: []const u8,
    rows: []const run_json.DiffRow,
    left_path: []const u8,
    right_path: []const u8,
    meta_rows: []const run_json.MetaDiffRow,
) !void {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    try buf.appendSlice(allocator,
        \\{
        \\  "deltas": [
        \\
    );

    for (rows, 0..) |r, i| {
        if (i > 0) try buf.appendSlice(allocator, ",\n");
        const delta_str = switch (r.kind) {
            .added => "added",
            .removed => "removed",
            .changed => "changed",
            .unchanged => "unchanged",
        };
        try buf.appendSlice(allocator, "    {\n");
        try buf.appendSlice(allocator, "      \"delta\": ");
        try appendJsonString(&buf, allocator, delta_str);
        try buf.appendSlice(allocator, ",\n      \"left\": ");
        if (r.left_status) |s| {
            try appendJsonString(&buf, allocator, s);
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n      \"right\": ");
        if (r.right_status) |s| {
            try appendJsonString(&buf, allocator, s);
        } else {
            try buf.appendSlice(allocator, "null");
        }
        try buf.appendSlice(allocator, ",\n      \"spec_id\": ");
        try appendJsonString(&buf, allocator, r.spec_id);
        try buf.appendSlice(allocator, "\n    }");
    }

    try buf.appendSlice(allocator, "\n  ],\n  \"left\": ");
    try appendJsonString(&buf, allocator, left_path);
    try buf.appendSlice(allocator, ",\n  \"metadata_deltas\": [\n");

    for (meta_rows, 0..) |m, i| {
        if (i > 0) try buf.appendSlice(allocator, ",\n");
        try buf.appendSlice(allocator, "    {\n");
        try buf.appendSlice(allocator, "      \"delta\": ");
        try appendJsonString(&buf, allocator, m.delta);
        try buf.appendSlice(allocator, ",\n      \"field\": ");
        try appendJsonString(&buf, allocator, m.field);
        try buf.appendSlice(allocator, ",\n      \"left\": ");
        try appendJsonOpt(&buf, allocator, m.left);
        try buf.appendSlice(allocator, ",\n      \"right\": ");
        try appendJsonOpt(&buf, allocator, m.right);
        try buf.appendSlice(allocator, "\n    }");
    }

    try buf.appendSlice(allocator, "\n  ],\n  \"right\": ");
    try appendJsonString(&buf, allocator, right_path);
    try buf.appendSlice(allocator, ",\n  \"schema_version\": \"0.2\"\n}\n");

    try compat_io.writeFile(.{ .sub_path = path, .data = buf.items });
}

fn appendJsonOpt(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, o: ?[]const u8) !void {
    if (o) |s| {
        try appendJsonString(buf, allocator, s);
    } else {
        try buf.appendSlice(allocator, "null");
    }
}

fn appendJsonString(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    try buf.append(allocator, '"');
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice(allocator, "\\\""),
            '\\' => try buf.appendSlice(allocator, "\\\\"),
            '\n' => try buf.appendSlice(allocator, "\\n"),
            '\r' => try buf.appendSlice(allocator, "\\r"),
            '\t' => try buf.appendSlice(allocator, "\\t"),
            else => if (c < 0x20) {
                try buf.print(allocator, "\\u{x:0>4}", .{c});
            } else {
                try buf.append(allocator, c);
            },
        }
    }
    try buf.append(allocator, '"');
}

test "writeFile includes specset_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .specset_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .specset_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"specset_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes terminal_launch_outcome in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-launch-outcome.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .terminal_launch_outcome = "ok" },
        .{ .terminal_launch_outcome = "timeout" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"terminal_launch_outcome\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes terminal_cmd_source in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-terminal-cmd-source.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .terminal_cmd_source = "fallback" },
        .{ .terminal_cmd_source = "profile" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"terminal_cmd_source\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes resolved_terminal_argv in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-resolved-argv.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .resolved_terminal_argv = "[\"kitty\",\"--detach\"]" },
        .{ .resolved_terminal_argv = "[\"ghostty\"]" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"resolved_terminal_argv\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes terminal_exec_template_id in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-template-id.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .terminal_exec_template_id = "kitty_exec_v1" },
        .{ .terminal_exec_template_id = "ghostty_exec_v1" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"terminal_exec_template_id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes terminal_exec_template_version in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-template-version.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .terminal_exec_template_version = "1" },
        .{ .terminal_exec_template_version = "2" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"terminal_exec_template_version\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes terminal_exec_resolved_path in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-exec-resolved.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .terminal_exec_resolved_path = "/bin/foo" },
        .{ .terminal_exec_resolved_path = "/bin/bar" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"terminal_exec_resolved_path\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes terminal_exec_resolved_path_normalization in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-path-norm.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .terminal_exec_resolved_path_normalization = "canonical" },
        .{ .terminal_exec_resolved_path_normalization = "literal" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"terminal_exec_resolved_path_normalization\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes terminal_launch_preflight_ok in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-preflight-ok.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .terminal_launch_preflight_ok = "true" },
        .{ .terminal_launch_preflight_ok = "false" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"terminal_launch_preflight_ok\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes terminal_launch_preflight_reason in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-preflight-reason.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .terminal_launch_preflight_reason = "ok" },
        .{ .terminal_launch_preflight_reason = "missing_executable" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"terminal_launch_preflight_reason\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes resultset_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-resultset.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .resultset_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .resultset_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"resultset_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes transport_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-transport-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .transport_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .transport_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"transport_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes exec_summary_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-exec-summary-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .exec_summary_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .exec_summary_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"exec_summary_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes context_summary_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-context-summary-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .context_summary_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .context_summary_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"context_summary_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes metadata_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-metadata-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .metadata_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .metadata_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"metadata_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes artifact_bundle_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-artifact-bundle-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .artifact_bundle_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .artifact_bundle_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"artifact_bundle_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes report_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-report-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .report_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .report_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"report_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes compare_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-compare-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .compare_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .compare_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"compare_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes run_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-run-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .run_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .run_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"run_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes session_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-session-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .session_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .session_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"session_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes environment_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-environment-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .environment_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .environment_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"environment_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes provenance_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-provenance-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .provenance_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .provenance_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"provenance_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes integrity_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-integrity-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .integrity_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .integrity_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"integrity_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes consistency_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-consistency-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .consistency_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .consistency_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"consistency_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes trace_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-trace-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .trace_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .trace_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"trace_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes lineage_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-lineage-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .lineage_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .lineage_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"lineage_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes state_envelope_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-state-envelope-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .state_envelope_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .state_envelope_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"state_envelope_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}

test "writeFile includes artifact_manifest_fingerprint_digest in metadata_deltas" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/compare-artifact-manifest-fp.json", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const rows: []const run_json.DiffRow = &.{};
    const meta = run_json.diffRunMeta(
        .{ .artifact_manifest_fingerprint_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .artifact_manifest_fingerprint_digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    );

    try writeFile(std.testing.allocator, path, rows, "a/run.json", "b/run.json", &meta);

    const text = try compat_io.readFileAlloc(std.testing.allocator, path, 1 << 20);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "\"field\": \"artifact_manifest_fingerprint_digest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"delta\": \"changed\"") != null);
}
