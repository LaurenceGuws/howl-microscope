const std = @import("std");
const parse = @import("cli/parse.zig");
const dispatch = @import("cli/dispatch.zig");

pub fn main(init: std.process.Init) u8 {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const argv = parse.argvRest(allocator, init.minimal.args) catch return 3;
    defer parse.freeArgv(allocator, argv);

    return dispatch.run(allocator, argv);
}
