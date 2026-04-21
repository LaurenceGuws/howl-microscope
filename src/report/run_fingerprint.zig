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

/// Fills `ctx.run_fingerprint_digest_*` from SHA-256 of the PH1-M11 canonical payload.
/// Call after `captureHostIdentity` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator, run_id: []const u8, records: []const run_execute.RunRecord) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.print(allocator, "PH1-M11/fp/v1\n{s}\n{s}\n{s}\n{s}\n", .{
        run_id,
        ctx.platform,
        ctx.execution_mode.tag(),
        ctx.transport_mode.tag(),
    });
    try canon.print(allocator, "{s}\n{s}\n{s}\n", .{
        ctx.host_identity_machine[0..ctx.host_identity_machine_len],
        ctx.host_identity_release[0..ctx.host_identity_release_len],
        ctx.host_identity_sysname[0..ctx.host_identity_sysname_len],
    });
    for (records) |r| {
        try canon.print(allocator, "{s}\n", .{r.spec_id});
    }

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.run_fingerprint_digest_hex, &digest);
    ctx.run_fingerprint_digest_len = 64;
}

test "populate is deterministic for same inputs" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var ctx = RunContext.initDefault();
    ctx.platform = "linux";
    ctx.captureHostIdentity();
    try populate(&ctx, a, "run-abc", &.{});

    var ctx2 = RunContext.initDefault();
    ctx2.platform = "linux";
    ctx2.captureHostIdentity();
    try populate(&ctx2, a, "run-abc", &.{});

    try std.testing.expectEqualSlices(u8, ctx.run_fingerprint_digest_hex[0..64], ctx2.run_fingerprint_digest_hex[0..64]);
}

test "populate changes when spec_id list changes" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var r1 = [_]run_execute.RunRecord{.{ .spec_id = "p1", .status = "manual", .notes = "", .capture_mode = "manual", .observations_json = "{}" }};
    var r2 = [_]run_execute.RunRecord{.{ .spec_id = "p2", .status = "manual", .notes = "", .capture_mode = "manual", .observations_json = "{}" }};

    var ctx_a = RunContext.initDefault();
    ctx_a.platform = "linux";
    ctx_a.captureHostIdentity();
    try populate(&ctx_a, a, "rid", &r1);

    var ctx_b = RunContext.initDefault();
    ctx_b.platform = "linux";
    ctx_b.captureHostIdentity();
    try populate(&ctx_b, a, "rid", &r2);

    try std.testing.expect(!std.mem.eql(u8, ctx_a.run_fingerprint_digest_hex[0..64], ctx_b.run_fingerprint_digest_hex[0..64]));
}
