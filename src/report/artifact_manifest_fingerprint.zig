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

/// Fills `ctx.artifact_manifest_fingerprint_digest_*` from SHA-256 of the PH1-M24 canonical payload (`docs/ARTIFACT_MANIFEST_FINGERPRINT_PLAN.md`).
/// Call after `environment_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M24/artifact-manifest/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.environment_envelope_fingerprint_digest_hex, ctx.environment_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "artifact-manifest:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.artifact_manifest_fingerprint_digest_hex, &digest);
    ctx.artifact_manifest_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithEnvironmentEnvelope(ee: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.environment_envelope_fingerprint_digest_hex, &ctx.environment_envelope_fingerprint_digest_len, ee);
    return ctx;
}

test "artifact manifest fingerprint is deterministic for fixed environment-envelope digest" {
    var a = testCtxWithEnvironmentEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithEnvironmentEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.artifact_manifest_fingerprint_digest_len, b.artifact_manifest_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.artifact_manifest_fingerprint_digest_hex[0..a.artifact_manifest_fingerprint_digest_len],
        b.artifact_manifest_fingerprint_digest_hex[0..b.artifact_manifest_fingerprint_digest_len],
    );
}

test "artifact manifest fingerprint changes when environment-envelope digest changes" {
    var a = testCtxWithEnvironmentEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithEnvironmentEnvelope(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.artifact_manifest_fingerprint_digest_hex[0..a.artifact_manifest_fingerprint_digest_len],
        b.artifact_manifest_fingerprint_digest_hex[0..b.artifact_manifest_fingerprint_digest_len],
    ));
}

test "artifact manifest fingerprint matches golden for M23 environment-envelope digest chain" {
    const golden_artifact_manifest = "090073497e9199080a37d57412b9fac50abc2622b366f3bcfff3ffd66858b3b2";
    var ctx = testCtxWithEnvironmentEnvelope(&"dd59e6d080adfc5aac4cbc34c6aff533718ac40fd453ccb8f1ef4f85288e3acc".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.artifact_manifest_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_artifact_manifest, ctx.artifact_manifest_fingerprint_digest_hex[0..ctx.artifact_manifest_fingerprint_digest_len]);
}
