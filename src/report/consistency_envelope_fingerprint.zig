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

/// Fills `ctx.consistency_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M27 canonical payload (`docs/CONSISTENCY_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `integrity_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M27/consistency-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.integrity_envelope_fingerprint_digest_hex, ctx.integrity_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "consistency:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.consistency_envelope_fingerprint_digest_hex, &digest);
    ctx.consistency_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithIntegrity(integ: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.integrity_envelope_fingerprint_digest_hex, &ctx.integrity_envelope_fingerprint_digest_len, integ);
    return ctx;
}

test "consistency envelope fingerprint is deterministic for fixed integrity-envelope digest" {
    var a = testCtxWithIntegrity(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithIntegrity(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.consistency_envelope_fingerprint_digest_len, b.consistency_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.consistency_envelope_fingerprint_digest_hex[0..a.consistency_envelope_fingerprint_digest_len],
        b.consistency_envelope_fingerprint_digest_hex[0..b.consistency_envelope_fingerprint_digest_len],
    );
}

test "consistency envelope fingerprint changes when integrity-envelope digest changes" {
    var a = testCtxWithIntegrity(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithIntegrity(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.consistency_envelope_fingerprint_digest_hex[0..a.consistency_envelope_fingerprint_digest_len],
        b.consistency_envelope_fingerprint_digest_hex[0..b.consistency_envelope_fingerprint_digest_len],
    ));
}

test "consistency envelope fingerprint matches golden for M26 integrity-envelope digest chain" {
    const golden_consistency = "40b1a4678654405c7d0d72dcc6cc992d8038d983fb28455b34ccba3a2132207a";
    var ctx = testCtxWithIntegrity(&"85006478d27f84d40319d5107072b420417a8bf12a81c966bf04e0d15dd01fa0".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.consistency_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_consistency, ctx.consistency_envelope_fingerprint_digest_hex[0..ctx.consistency_envelope_fingerprint_digest_len]);
}
