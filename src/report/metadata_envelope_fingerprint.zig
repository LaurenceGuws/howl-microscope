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

/// Fills `ctx.metadata_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M17 canonical payload (`docs/METADATA_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `context_summary_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M17/metadata-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.run_fingerprint_digest_hex, ctx.run_fingerprint_digest_len);
    try appendDigestVersion(&canon, allocator, &ctx.specset_fingerprint_digest_hex, ctx.specset_fingerprint_digest_len);
    try appendDigestVersion(&canon, allocator, &ctx.resultset_fingerprint_digest_hex, ctx.resultset_fingerprint_digest_len);
    try appendDigestVersion(&canon, allocator, &ctx.transport_fingerprint_digest_hex, ctx.transport_fingerprint_digest_len);
    try appendDigestVersion(&canon, allocator, &ctx.exec_summary_fingerprint_digest_hex, ctx.exec_summary_fingerprint_digest_len);
    try appendDigestVersion(&canon, allocator, &ctx.context_summary_fingerprint_digest_hex, ctx.context_summary_fingerprint_digest_len);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.metadata_envelope_fingerprint_digest_hex, &digest);
    ctx.metadata_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithUpstreamDigests(run_a: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.run_fingerprint_digest_hex, &ctx.run_fingerprint_digest_len, run_a);
    fillDigest(&ctx.specset_fingerprint_digest_hex, &ctx.specset_fingerprint_digest_len, &"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc".*);
    fillDigest(&ctx.resultset_fingerprint_digest_hex, &ctx.resultset_fingerprint_digest_len, &"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd".*);
    fillDigest(&ctx.transport_fingerprint_digest_hex, &ctx.transport_fingerprint_digest_len, &"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee".*);
    fillDigest(&ctx.exec_summary_fingerprint_digest_hex, &ctx.exec_summary_fingerprint_digest_len, &"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".*);
    fillDigest(&ctx.context_summary_fingerprint_digest_hex, &ctx.context_summary_fingerprint_digest_len, &"1111111111111111111111111111111111111111111111111111111111111111".*);
    return ctx;
}

test "metadata envelope fingerprint is deterministic for fixed upstream digests" {
    var a = testCtxWithUpstreamDigests(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithUpstreamDigests(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.metadata_envelope_fingerprint_digest_len, b.metadata_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.metadata_envelope_fingerprint_digest_hex[0..a.metadata_envelope_fingerprint_digest_len],
        b.metadata_envelope_fingerprint_digest_hex[0..b.metadata_envelope_fingerprint_digest_len],
    );
}

test "metadata envelope fingerprint changes when an upstream digest changes" {
    var a = testCtxWithUpstreamDigests(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithUpstreamDigests(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.metadata_envelope_fingerprint_digest_hex[0..a.metadata_envelope_fingerprint_digest_len],
        b.metadata_envelope_fingerprint_digest_hex[0..b.metadata_envelope_fingerprint_digest_len],
    ));
}
