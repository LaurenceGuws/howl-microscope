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

/// Fills `ctx.run_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M21 canonical payload (`docs/RUN_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `compare_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M21/run-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.compare_envelope_fingerprint_digest_hex, ctx.compare_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "run:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.run_envelope_fingerprint_digest_hex, &digest);
    ctx.run_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithCompareEnvelope(ce: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.compare_envelope_fingerprint_digest_hex, &ctx.compare_envelope_fingerprint_digest_len, ce);
    return ctx;
}

test "run envelope fingerprint is deterministic for fixed compare-envelope digest" {
    var a = testCtxWithCompareEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithCompareEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.run_envelope_fingerprint_digest_len, b.run_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.run_envelope_fingerprint_digest_hex[0..a.run_envelope_fingerprint_digest_len],
        b.run_envelope_fingerprint_digest_hex[0..b.run_envelope_fingerprint_digest_len],
    );
}

test "run envelope fingerprint changes when compare-envelope digest changes" {
    var a = testCtxWithCompareEnvelope(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithCompareEnvelope(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.run_envelope_fingerprint_digest_hex[0..a.run_envelope_fingerprint_digest_len],
        b.run_envelope_fingerprint_digest_hex[0..b.run_envelope_fingerprint_digest_len],
    ));
}

test "run envelope fingerprint matches golden for M20 compare-envelope digest chain" {
    const golden_run_envelope = "6eb18d774c8c3625e082076218508331bef799ed368ead1dcde5de6ac5e91a90";
    var ctx = testCtxWithCompareEnvelope(&"67ecac21cb2aa19eacf9be4d930c52e447b35bdc3e6d408fde01fd277c656dcd".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.run_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_run_envelope, ctx.run_envelope_fingerprint_digest_hex[0..ctx.run_envelope_fingerprint_digest_len]);
}
