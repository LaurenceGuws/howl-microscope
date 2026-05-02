const std = @import("std");

pub fn readFileAlloc(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) ![]u8 {
    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_bytes));
}

pub fn writeFile(options: struct { sub_path: []const u8, data: []const u8 }) !void {
    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = options.sub_path, .data = options.data });
}

pub fn makePath(path: []const u8) !void {
    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    try std.Io.Dir.cwd().createDirPath(io, path);
}

pub fn access(path: []const u8) !void {
    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    try std.Io.Dir.cwd().access(io, path, .{});
}

pub fn getenv(name_z: [*:0]const u8) []const u8 {
    const p = std.c.getenv(name_z) orelse return "";
    return std.mem.span(p);
}
