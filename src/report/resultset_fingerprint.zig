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

/// Fills `ctx.resultset_fingerprint_digest_*` from SHA-256 of the PH1-M13 canonical payload (`docs/RESULTSET_FINGERPRINT_PLAN.md`).
/// Call after `specset_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator, records: []const run_execute.RunRecord) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M13/resultset/fp/v1\n");
    for (records) |r| {
        try canon.print(allocator, "{s}\n{s}\n{s}\n{s}\n", .{ r.spec_id, r.status, r.capture_mode, r.notes });
    }

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.resultset_fingerprint_digest_hex, &digest);
    ctx.resultset_fingerprint_digest_len = 64;
}

test "populate is deterministic for same result rows" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var r = [_]run_execute.RunRecord{.{ .spec_id = "p1", .status = "manual", .notes = "n", .capture_mode = "manual", .observations_json = "{}" }};

    var ctx = RunContext.initDefault();
    try populate(&ctx, a, &r);

    var ctx2 = RunContext.initDefault();
    try populate(&ctx2, a, &r);

    try std.testing.expectEqualSlices(u8, ctx.resultset_fingerprint_digest_hex[0..64], ctx2.resultset_fingerprint_digest_hex[0..64]);
}

test "populate changes when status changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var r_ok = [_]run_execute.RunRecord{.{ .spec_id = "p", .status = "pass", .notes = "", .capture_mode = "manual", .observations_json = "{}" }};
    var r_fail = [_]run_execute.RunRecord{.{ .spec_id = "p", .status = "fail", .notes = "", .capture_mode = "manual", .observations_json = "{}" }};

    var ctx_ok = RunContext.initDefault();
    try populate(&ctx_ok, a, &r_ok);

    var ctx_fail = RunContext.initDefault();
    try populate(&ctx_fail, a, &r_fail);

    try std.testing.expect(!std.mem.eql(u8, ctx_ok.resultset_fingerprint_digest_hex[0..64], ctx_fail.resultset_fingerprint_digest_hex[0..64]));
}

test "populate changes when notes change" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var r_a = [_]run_execute.RunRecord{.{ .spec_id = "p", .status = "manual", .notes = "a", .capture_mode = "manual", .observations_json = "{}" }};
    var r_b = [_]run_execute.RunRecord{.{ .spec_id = "p", .status = "manual", .notes = "b", .capture_mode = "manual", .observations_json = "{}" }};

    var ctx_a = RunContext.initDefault();
    try populate(&ctx_a, a, &r_a);

    var ctx_b = RunContext.initDefault();
    try populate(&ctx_b, a, &r_b);

    try std.testing.expect(!std.mem.eql(u8, ctx_a.resultset_fingerprint_digest_hex[0..64], ctx_b.resultset_fingerprint_digest_hex[0..64]));
}
