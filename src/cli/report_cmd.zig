const std = @import("std");
const errors = @import("../core/errors.zig");
const run_json_validate = @import("../report/run_json_validate.zig");

const max_read = 4 * 1024 * 1024;

pub fn execute(allocator: std.mem.Allocator, argv: []const []const u8) u8 {
    if (argv.len == 0) {
        printErr("usage: howl-microscope report <run.json|run-directory>\n") catch {};
        return errors.Category.unknown_command.exitCode();
    }
    const target = argv[0];

    var owned: ?[]const u8 = null;
    defer if (owned) |p| allocator.free(p);

    const json_path: []const u8 = if (std.mem.endsWith(u8, target, ".json")) target else blk: {
        const p = std.fs.path.join(allocator, &.{ target, "run.json" }) catch return errors.Category.runtime_failure.exitCode();
        owned = p;
        break :blk p;
    };

    const data = std.fs.cwd().readFileAlloc(allocator, json_path, max_read) catch {
        printErr("could not read run.json\n") catch {};
        return errors.Category.runtime_failure.exitCode();
    };
    defer allocator.free(data);

    const trimmed = std.mem.trim(u8, data, " \n\r\t");
    if (trimmed.len == 0) {
        printErr("invalid run.json (empty)\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    }

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, trimmed, .{}) catch {
        printErr("invalid run.json (malformed JSON)\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    };
    defer parsed.deinit();

    switch (parsed.value) {
        .object => {},
        else => {
            printErr("invalid run.json (expected top-level JSON object)\n") catch {};
            return errors.Category.invalid_spec.exitCode();
        },
    }

    if (run_json_validate.validateRunReport(parsed.value)) |msg| {
        printErr("invalid run.json (schema)\n") catch {};
        printErr(msg) catch {};
        printErr("\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    }

    printStdout("ok: validated {s}\n", .{json_path}) catch return errors.Category.runtime_failure.exitCode();
    return 0;
}

fn printErr(msg: []const u8) !void {
    var buf: [256]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    try w.interface.print("{s}", .{msg});
    try w.interface.flush();
}

fn printStdout(comptime fmt: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    try w.interface.print(fmt, args);
    try w.interface.flush();
}
