const std = @import("std");
const RunContext = @import("../cli/run_context.zig").RunContext;

/// Writes `env.json` per `docs/ENV.md`.
pub fn writeEnvJson(allocator: std.mem.Allocator, run_dir: []const u8, ctx: RunContext) !void {
    const path = try std.fmt.allocPrint(allocator, "{s}/env.json", .{run_dir});
    defer allocator.free(path);

    const term = std.posix.getenv("TERM") orelse "";

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    try buf.print(allocator,
        "{{\n  \"schema_version\": \"0.1\",\n  \"platform\": \"{s}\",\n  \"term\": \"{s}\",\n  \"terminal\": {{\n    \"name\": \"{s}\",\n    \"version\": \"\",\n    \"command\": \"{s}\"\n  }}",
        .{ ctx.platform, term, ctx.terminal_name, ctx.terminal_cmd },
    );

    if (ctx.comparison_id) |c| {
        try buf.print(allocator, ",\n  \"comparison_id\": \"{s}\"", .{c});
    } else {
        try buf.appendSlice(allocator, ",\n  \"comparison_id\": null");
    }

    if (ctx.run_group) |g| {
        try buf.print(allocator, ",\n  \"run_group\": \"{s}\"", .{g});
    } else {
        try buf.appendSlice(allocator, ",\n  \"run_group\": null");
    }

    if (ctx.suite_name) |s| {
        try buf.print(allocator, ",\n  \"suite\": \"{s}\"", .{s});
    } else {
        try buf.appendSlice(allocator, ",\n  \"suite\": null");
    }

    try buf.appendSlice(allocator, "\n}\n");

    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = buf.items });
}
