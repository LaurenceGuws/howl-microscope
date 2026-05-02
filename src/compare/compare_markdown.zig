const std = @import("std");
const run_json = @import("run_json.zig");

fn cellOrDash(o: ?[]const u8) []const u8 {
    return o orelse "—";
}

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

    try buf.appendSlice(allocator, "# Compare\n\n");
    try buf.appendSlice(allocator, "## Metadata\n\n");
    try buf.appendSlice(allocator, "| field | left | right | delta |\n|---|---|---|---|\n");
    for (meta_rows) |m| {
        try buf.print(allocator, "| `{s}` | {s} | {s} | {s} |\n", .{
            m.field,
            cellOrDash(m.left),
            cellOrDash(m.right),
            m.delta,
        });
    }
    try buf.appendSlice(allocator, "\n## Paths\n\n");
    try buf.print(allocator, "- left: `{s}`\n- right: `{s}`\n\n", .{ left_path, right_path });
    try buf.appendSlice(allocator, "## Results\n\n");
    try buf.appendSlice(allocator, "| spec_id | delta | left | right |\n|---|---|---|---|\n");

    for (rows) |r| {
        const delta = switch (r.kind) {
            .added => "added",
            .removed => "removed",
            .changed => "changed",
            .unchanged => "unchanged",
        };
        const ls = r.left_status orelse "";
        const rs = r.right_status orelse "";
        try buf.print(allocator, "| `{s}` | {s} | {s} | {s} |\n", .{ r.spec_id, delta, ls, rs });
    }

    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = buf.items });
}
