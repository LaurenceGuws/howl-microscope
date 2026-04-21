const std = @import("std");

/// Collects `*.toml` paths under each root (or `probes/` if `roots` is empty).
/// Results are sorted lexicographically by path string. Caller owns returned slice and strings (`freePaths`).
pub fn discover(allocator: std.mem.Allocator, roots: []const []const u8) ![][]const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (list.items) |p| allocator.free(p);
        list.deinit(allocator);
    }

    const effective: []const []const u8 = if (roots.len == 0) &[_][]const u8{"probes"} else roots;

    for (effective) |root| {
        try collectRoot(allocator, root, &list);
    }

    const items = try list.toOwnedSlice(allocator);
    std.mem.sort([]const u8, items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);
    return items;
}

fn collectRoot(allocator: std.mem.Allocator, root: []const u8, out: *std.ArrayList([]const u8)) !void {
    var dir = std.fs.cwd().openDir(root, .{ .iterate = true }) catch |err| switch (err) {
        error.NotDir => {
            var f = try std.fs.cwd().openFile(root, .{});
            defer f.close();
            if (!std.mem.endsWith(u8, root, ".toml")) return err;
            try out.append(allocator, try allocator.dupe(u8, root));
            return;
        },
        else => |e| return e,
    };
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        const base = std.mem.sliceTo(entry.basename, 0);
        if (!std.mem.endsWith(u8, base, ".toml")) continue;
        const rel = std.mem.sliceTo(entry.path, 0);
        const full = try std.fs.path.join(allocator, &.{ root, rel });
        try out.append(allocator, full);
    }
}

pub fn freePaths(allocator: std.mem.Allocator, paths: [][]const u8) void {
    for (paths) |p| allocator.free(p);
    allocator.free(paths);
}
