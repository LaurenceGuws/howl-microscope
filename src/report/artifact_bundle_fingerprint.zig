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

/// Fills `ctx.artifact_bundle_fingerprint_digest_*` from SHA-256 of the PH1-M18 canonical payload (`docs/ARTIFACT_BUNDLE_FINGERPRINT_PLAN.md`).
/// Call after `metadata_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M18/artifact-bundle/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.metadata_envelope_fingerprint_digest_hex, ctx.metadata_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "artifact:env.json\nartifact:run.json\nartifact:summary.md\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.artifact_bundle_fingerprint_digest_hex, &digest);
    ctx.artifact_bundle_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithMetadataEnvelope(me: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.metadata_envelope_fingerprint_digest_hex, &ctx.metadata_envelope_fingerprint_digest_len, me);
    return ctx;
}

test "artifact bundle fingerprint is deterministic for fixed metadata-envelope digest" {
    var a = testCtxWithMetadataEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithMetadataEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.artifact_bundle_fingerprint_digest_len, b.artifact_bundle_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.artifact_bundle_fingerprint_digest_hex[0..a.artifact_bundle_fingerprint_digest_len],
        b.artifact_bundle_fingerprint_digest_hex[0..b.artifact_bundle_fingerprint_digest_len],
    );
}

test "artifact bundle fingerprint changes when metadata-envelope digest changes" {
    var a = testCtxWithMetadataEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithMetadataEnvelope(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.artifact_bundle_fingerprint_digest_hex[0..a.artifact_bundle_fingerprint_digest_len],
        b.artifact_bundle_fingerprint_digest_hex[0..b.artifact_bundle_fingerprint_digest_len],
    ));
}
