const std = @import("std");
const RunContext = @import("../cli/run_context.zig").RunContext;
const run_execute = @import("../runner/run_execute.zig");

fn writeHexLower(dst: *[64]u8, src: *const [32]u8) void {
    const hex = "0123456789abcdef";
    inline for (0..32) |i| {
        const b = src[i];
        dst[i * 2] = hex[b >> 4];
        dst[i * 2 + 1] = hex[b & 15];
    }
}

/// Fills `ctx.specset_fingerprint_digest_*` from SHA-256 of the PH1-M12 canonical payload (`docs/SPECSET_FINGERPRINT_PLAN.md`).
/// Call after `run_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator, records: []const run_execute.RunRecord) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M12/specset/fp/v1\n");
    if (ctx.suite_name) |sn| {
        try canon.print(allocator, "{s}\n", .{sn});
    } else {
        try canon.appendSlice(allocator, "null\n");
    }
    for (records) |r| {
        try canon.print(allocator, "{s}\n", .{r.spec_id});
    }

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.specset_fingerprint_digest_hex, &digest);
    ctx.specset_fingerprint_digest_len = 64;
}

test "populate is deterministic for same suite and spec order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var r = [_]run_execute.RunRecord{.{ .spec_id = "p1", .status = "manual", .notes = "", .capture_mode = "manual", .observations_json = "{}" }};

    var ctx = RunContext.initDefault();
    ctx.suite_name = "suite-a";
    try populate(&ctx, a, &r);

    var ctx2 = RunContext.initDefault();
    ctx2.suite_name = "suite-a";
    try populate(&ctx2, a, &r);

    try std.testing.expectEqualSlices(u8, ctx.specset_fingerprint_digest_hex[0..64], ctx2.specset_fingerprint_digest_hex[0..64]);
}

test "populate changes when spec_id order changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var ab = [_]run_execute.RunRecord{
        .{ .spec_id = "a", .status = "manual", .notes = "", .capture_mode = "manual", .observations_json = "{}" },
        .{ .spec_id = "b", .status = "manual", .notes = "", .capture_mode = "manual", .observations_json = "{}" },
    };
    var ba = [_]run_execute.RunRecord{
        .{ .spec_id = "b", .status = "manual", .notes = "", .capture_mode = "manual", .observations_json = "{}" },
        .{ .spec_id = "a", .status = "manual", .notes = "", .capture_mode = "manual", .observations_json = "{}" },
    };

    var ctx_ab = RunContext.initDefault();
    try populate(&ctx_ab, a, &ab);

    var ctx_ba = RunContext.initDefault();
    try populate(&ctx_ba, a, &ba);

    try std.testing.expect(!std.mem.eql(u8, ctx_ab.specset_fingerprint_digest_hex[0..64], ctx_ba.specset_fingerprint_digest_hex[0..64]));
}

test "populate changes when suite label changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var ctx_named = RunContext.initDefault();
    ctx_named.suite_name = "named";
    try populate(&ctx_named, a, &.{});

    var ctx_null = RunContext.initDefault();
    try populate(&ctx_null, a, &.{});

    try std.testing.expect(!std.mem.eql(u8, ctx_named.specset_fingerprint_digest_hex[0..64], ctx_null.specset_fingerprint_digest_hex[0..64]));
}
