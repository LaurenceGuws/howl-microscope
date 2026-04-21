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

/// Fills `ctx.session_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M22 canonical payload (`docs/SESSION_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `run_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M22/session-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.run_envelope_fingerprint_digest_hex, ctx.run_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "session:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.session_envelope_fingerprint_digest_hex, &digest);
    ctx.session_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithRunEnvelope(re: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.run_envelope_fingerprint_digest_hex, &ctx.run_envelope_fingerprint_digest_len, re);
    return ctx;
}

test "session envelope fingerprint is deterministic for fixed run-envelope digest" {
    var a = testCtxWithRunEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithRunEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.session_envelope_fingerprint_digest_len, b.session_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.session_envelope_fingerprint_digest_hex[0..a.session_envelope_fingerprint_digest_len],
        b.session_envelope_fingerprint_digest_hex[0..b.session_envelope_fingerprint_digest_len],
    );
}

test "session envelope fingerprint changes when run-envelope digest changes" {
    var a = testCtxWithRunEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithRunEnvelope(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.session_envelope_fingerprint_digest_hex[0..a.session_envelope_fingerprint_digest_len],
        b.session_envelope_fingerprint_digest_hex[0..b.session_envelope_fingerprint_digest_len],
    ));
}

test "session envelope fingerprint matches golden for M21 run-envelope digest chain" {
    const golden_session_envelope = "d9ac103387a17fd9217799a54fd1f2ba121ade49f8a171a0ce00bb7e6e79e0b3";
    var ctx = testCtxWithRunEnvelope(&"6eb18d774c8c3625e082076218508331bef799ed368ead1dcde5de6ac5e91a90".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.session_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_session_envelope, ctx.session_envelope_fingerprint_digest_hex[0..ctx.session_envelope_fingerprint_digest_len]);
}
