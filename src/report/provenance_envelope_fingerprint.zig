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

/// Fills `ctx.provenance_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M25 canonical payload (`docs/PROVENANCE_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `artifact_manifest_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M25/provenance-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.artifact_manifest_fingerprint_digest_hex, ctx.artifact_manifest_fingerprint_digest_len);

    try canon.appendSlice(allocator, "provenance:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.provenance_envelope_fingerprint_digest_hex, &digest);
    ctx.provenance_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithArtifactManifest(am: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.artifact_manifest_fingerprint_digest_hex, &ctx.artifact_manifest_fingerprint_digest_len, am);
    return ctx;
}

test "provenance envelope fingerprint is deterministic for fixed artifact-manifest digest" {
    var a = testCtxWithArtifactManifest(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithArtifactManifest(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.provenance_envelope_fingerprint_digest_len, b.provenance_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.provenance_envelope_fingerprint_digest_hex[0..a.provenance_envelope_fingerprint_digest_len],
        b.provenance_envelope_fingerprint_digest_hex[0..b.provenance_envelope_fingerprint_digest_len],
    );
}

test "provenance envelope fingerprint changes when artifact-manifest digest changes" {
    var a = testCtxWithArtifactManifest(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithArtifactManifest(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.provenance_envelope_fingerprint_digest_hex[0..a.provenance_envelope_fingerprint_digest_len],
        b.provenance_envelope_fingerprint_digest_hex[0..b.provenance_envelope_fingerprint_digest_len],
    ));
}

test "provenance envelope fingerprint matches golden for M24 artifact-manifest digest chain" {
    const golden_provenance = "f56eb65942e63e5d5889c29130529cdbf681764c4d2beab18b0d3d8ebcb06e79";
    var ctx = testCtxWithArtifactManifest(&"090073497e9199080a37d57412b9fac50abc2622b366f3bcfff3ffd66858b3b2".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.provenance_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_provenance, ctx.provenance_envelope_fingerprint_digest_hex[0..ctx.provenance_envelope_fingerprint_digest_len]);
}
