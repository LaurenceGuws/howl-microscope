const std = @import("std");
const errors = @import("../core/errors.zig");
const categories = @import("../probes/categories.zig");
const discovery = @import("../dsl/discovery.zig");
const run_cmd = @import("run_cmd.zig");
const run_suite_cmd = @import("run_suite_cmd.zig");
const report_cmd = @import("report_cmd.zig");
const compare_cmd = @import("compare_cmd.zig");

fn printListStub(allocator: std.mem.Allocator, roots: []const []const u8) !void {
    const paths = try discovery.discover(allocator, roots);
    defer discovery.freePaths(allocator, paths);

    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    try w.interface.print("# probe kinds: ", .{});
    for (categories.all, 0..) |c, i| {
        if (i > 0) try w.interface.print(", ", .{});
        try w.interface.print("{s}", .{c});
    }
    try w.interface.print("\n", .{});
    for (paths) |p| {
        try w.interface.print("{s}\n", .{p});
    }
    try w.interface.flush();
}

fn printStdout(comptime fmt: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    try w.interface.print(fmt, args);
    try w.interface.flush();
}

fn printStderr(comptime fmt: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    try w.interface.print(fmt, args);
    try w.interface.flush();
}

pub fn run(allocator: std.mem.Allocator, argv: []const []const u8) u8 {
    if (argv.len == 0) {
        usageStderr() catch {};
        return errors.Category.unknown_command.exitCode();
    }
    const cmd = argv[0];
    if (std.mem.eql(u8, cmd, "list")) {
        printListStub(allocator, argv[1..]) catch return errors.Category.runtime_failure.exitCode();
        return 0;
    }
    if (std.mem.eql(u8, cmd, "run")) {
        return run_cmd.execute(allocator, argv[1..]);
    }
    if (std.mem.eql(u8, cmd, "run-suite")) {
        return run_suite_cmd.execute(allocator, argv[1..]);
    }
    if (std.mem.eql(u8, cmd, "report")) {
        return report_cmd.execute(allocator, argv[1..]);
    }
    if (std.mem.eql(u8, cmd, "compare")) {
        return compare_cmd.execute(allocator, argv[1..]);
    }
    if (std.mem.eql(u8, cmd, "doctor")) {
        printStdout(
            "doctor: phase-1 scaffold OK (cwd and env checks expand later)\n",
            .{},
        ) catch return errors.Category.runtime_failure.exitCode();
        return 0;
    }

    printStderr("unknown command: {s}\n", .{cmd}) catch {};
    return errors.Category.unknown_command.exitCode();
}

fn usageStderr() !void {
    var buf: [1024]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    try w.interface.print(
        \\usage: howl-microscope <command> [args...]
        \\
        \\commands:
        \\  list        Enumerate probe specs (.toml)
        \\  run         Run specs and write artifacts
        \\  run-suite   Run a named suite (baseline-linux)
        \\  report      Validate or render report from run.json
        \\  compare     Compare two run.json files
        \\  doctor      Environment diagnostics
        \\
    , .{});
    try w.interface.flush();
}
