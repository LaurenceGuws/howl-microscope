const std = @import("std");
const c = @cImport({
    @cInclude("time.h");
});

/// Returns a new directory path `artifacts_root/YYYY-MM-DD/run-XXX/` (creates directories).
pub fn nextRunDirectory(allocator: std.mem.Allocator, artifact_root: []const u8) ![]const u8 {
    const sec_now = c.time(null);
    if (sec_now < 0) return error.Unexpected;
    const sec: u64 = @intCast(sec_now);
    const es = std.time.epoch.EpochSeconds{ .secs = sec };

    var date_buf: [10]u8 = undefined;
    const date_slice = try formatDate(date_buf[0..], es.secs);

    const day_path = try std.fs.path.join(allocator, &.{ artifact_root, date_slice });
    defer allocator.free(day_path);

    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    try std.Io.Dir.cwd().createDirPath(io, day_path);

    var dir = try std.Io.Dir.cwd().openDir(io, day_path, .{ .iterate = true });
    defer dir.close(io);

    const max_run = try maxRunIndexIn(io, &dir);
    const next = max_run + 1;
    const label = try std.fmt.allocPrint(allocator, "run-{d:0>3}", .{next});
    defer allocator.free(label);

    const full = try std.fs.path.join(allocator, &.{ artifact_root, date_slice, label });
    try std.Io.Dir.cwd().createDirPath(io, full);
    return full;
}

/// Largest `N` among child directories named `run-N` (decimal), or `0` if none.
pub fn maxRunIndexIn(io: std.Io, dir: *const std.Io.Dir) !u32 {
    var max_run: u32 = 0;
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .directory) continue;
        const name = std.mem.sliceTo(e.name, 0);
        if (!std.mem.startsWith(u8, name, "run-")) continue;
        const n = parseRunSuffix(name) orelse continue;
        max_run = @max(max_run, n);
    }
    return max_run;
}

fn formatDate(buf: []u8, unix_secs: u64) ![]const u8 {
    const es = std.time.epoch.EpochSeconds{ .secs = unix_secs };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return try std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        yd.year,
        md.month.numeric(),
        md.day_index + 1,
    });
}

test "maxRunIndexIn scans run-N directories" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makeDir("run-001");
    try tmp.dir.makeDir("run-007");
    try tmp.dir.makeDir("noise");
    var dir = try tmp.dir.openDir(".", .{ .iterate = true });
    defer dir.close();
    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    const m = try maxRunIndexIn(io, &dir);
    try std.testing.expectEqual(@as(u32, 7), m);
}

test "parseRunSuffix" {
    try std.testing.expectEqual(@as(?u32, 1), parseRunSuffix("run-1"));
    try std.testing.expectEqual(@as(?u32, 42), parseRunSuffix("run-42"));
    try std.testing.expect(parseRunSuffix("run-") == null);
    try std.testing.expect(parseRunSuffix("run-x") == null);
    try std.testing.expect(parseRunSuffix("other-1") == null);
}

fn parseRunSuffix(name: []const u8) ?u32 {
    const prefix = "run-";
    if (!std.mem.startsWith(u8, name, prefix)) return null;
    return std.fmt.parseUnsigned(u32, name[prefix.len..], 10) catch null;
}
