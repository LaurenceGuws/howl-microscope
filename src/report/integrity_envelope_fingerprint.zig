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

/// Fills `ctx.integrity_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M26 canonical payload (`docs/INTEGRITY_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `provenance_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M26/integrity-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.provenance_envelope_fingerprint_digest_hex, ctx.provenance_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "integrity:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.integrity_envelope_fingerprint_digest_hex, &digest);
    ctx.integrity_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithProvenance(pe: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.provenance_envelope_fingerprint_digest_hex, &ctx.provenance_envelope_fingerprint_digest_len, pe);
    return ctx;
}

test "integrity envelope fingerprint is deterministic for fixed provenance-envelope digest" {
    var a = testCtxWithProvenance(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithProvenance(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.integrity_envelope_fingerprint_digest_len, b.integrity_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.integrity_envelope_fingerprint_digest_hex[0..a.integrity_envelope_fingerprint_digest_len],
        b.integrity_envelope_fingerprint_digest_hex[0..b.integrity_envelope_fingerprint_digest_len],
    );
}

test "integrity envelope fingerprint changes when provenance-envelope digest changes" {
    var a = testCtxWithProvenance(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithProvenance(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.integrity_envelope_fingerprint_digest_hex[0..a.integrity_envelope_fingerprint_digest_len],
        b.integrity_envelope_fingerprint_digest_hex[0..b.integrity_envelope_fingerprint_digest_len],
    ));
}

test "integrity envelope fingerprint matches golden for M25 provenance-envelope digest chain" {
    const golden_integrity = "85006478d27f84d40319d5107072b420417a8bf12a81c966bf04e0d15dd01fa0";
    var ctx = testCtxWithProvenance(&"f56eb65942e63e5d5889c29130529cdbf681764c4d2beab18b0d3d8ebcb06e79".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.integrity_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_integrity, ctx.integrity_envelope_fingerprint_digest_hex[0..ctx.integrity_envelope_fingerprint_digest_len]);
}
