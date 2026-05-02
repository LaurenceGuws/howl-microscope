const std = @import("std");

/// Raw spec document as read from disk (phase-1: no semantic parse).
pub const RawSpec = struct {
    path: []const u8,
    text: []const u8,

    pub fn deinit(self: *RawSpec, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.text);
        self.* = undefined;
    }
};

const max_spec_bytes = 4 * 1024 * 1024;

/// Reads a UTF-8 spec file into memory. Caller must `RawSpec.deinit`.
pub fn loadFile(allocator: std.mem.Allocator, path: []const u8) !RawSpec {
    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    const data = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_spec_bytes)) catch |err| switch (err) {
        error.FileTooBig => return error.OutOfMemory,
        else => |e| return e,
    };
    errdefer allocator.free(data);
    return RawSpec{
        .path = try allocator.dupe(u8, path),
        .text = data,
    };
}
