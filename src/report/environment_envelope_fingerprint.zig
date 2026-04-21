const std = @import("std");
const RunContext = @import("../cli/run_context.zig").RunContext;

fn writeHexLower(dst: *[64]u8, src: *const [32]u8) void {
    const hex = "0123456789abcdef";
    inline for (0..32) |i| {
        const b = src[i];
        dst[i * 2] = hex[b >> 4];
        dst[i * 2 + 1] = hex[b & 15];
    }
}

fn appendDigestVersion(canon: *std.ArrayList(u8), allocator: std.mem.Allocator, digest_hex: *const [64]u8, digest_len: u8) !void {
    try canon.print(allocator, "{s}\n1\n", .{digest_hex[0..digest_len]});
}

/// Fills `ctx.environment_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M23 canonical payload (`docs/ENVIRONMENT_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `session_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M23/environment-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.session_envelope_fingerprint_digest_hex, ctx.session_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "environment:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.environment_envelope_fingerprint_digest_hex, &digest);
    ctx.environment_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithSessionEnvelope(se: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.session_envelope_fingerprint_digest_hex, &ctx.session_envelope_fingerprint_digest_len, se);
    return ctx;
}

test "environment envelope fingerprint is deterministic for fixed session-envelope digest" {
    var a = testCtxWithSessionEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithSessionEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.environment_envelope_fingerprint_digest_len, b.environment_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.environment_envelope_fingerprint_digest_hex[0..a.environment_envelope_fingerprint_digest_len],
        b.environment_envelope_fingerprint_digest_hex[0..b.environment_envelope_fingerprint_digest_len],
    );
}

test "environment envelope fingerprint changes when session-envelope digest changes" {
    var a = testCtxWithSessionEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithSessionEnvelope(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.environment_envelope_fingerprint_digest_hex[0..a.environment_envelope_fingerprint_digest_len],
        b.environment_envelope_fingerprint_digest_hex[0..b.environment_envelope_fingerprint_digest_len],
    ));
}

test "environment envelope fingerprint matches golden for M22 session-envelope digest chain" {
    const golden_environment_envelope = "dd59e6d080adfc5aac4cbc34c6aff533718ac40fd453ccb8f1ef4f85288e3acc";
    var ctx = testCtxWithSessionEnvelope(&"d9ac103387a17fd9217799a54fd1f2ba121ade49f8a171a0ce00bb7e6e79e0b3".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.environment_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_environment_envelope, ctx.environment_envelope_fingerprint_digest_hex[0..ctx.environment_envelope_fingerprint_digest_len]);
}
