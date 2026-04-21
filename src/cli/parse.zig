const std = @import("std");

/// Collects argv after the executable name (owned by `allocator`).
pub fn argvRest(allocator: std.mem.Allocator) ![][]const u8 {
    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();
    _ = it.next() orelse return &[_][]const u8{};

    var list: std.ArrayList([]const u8) = .empty;
    defer list.deinit(allocator);

    while (it.next()) |arg| {
        try list.append(allocator, try allocator.dupe(u8, arg));
    }
    return try list.toOwnedSlice(allocator);
}

pub fn freeArgv(allocator: std.mem.Allocator, argv: []const []const u8) void {
    for (argv) |s| allocator.free(s);
    allocator.free(argv);
}
