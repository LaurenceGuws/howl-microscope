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

/// Fills `ctx.lineage_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M29 canonical payload (`docs/LINEAGE_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `trace_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M29/lineage-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.trace_envelope_fingerprint_digest_hex, ctx.trace_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "lineage:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.lineage_envelope_fingerprint_digest_hex, &digest);
    ctx.lineage_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithTrace(trace: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.trace_envelope_fingerprint_digest_hex, &ctx.trace_envelope_fingerprint_digest_len, trace);
    return ctx;
}

test "lineage envelope fingerprint is deterministic for fixed trace-envelope digest" {
    var a = testCtxWithTrace(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithTrace(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.lineage_envelope_fingerprint_digest_len, b.lineage_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.lineage_envelope_fingerprint_digest_hex[0..a.lineage_envelope_fingerprint_digest_len],
        b.lineage_envelope_fingerprint_digest_hex[0..b.lineage_envelope_fingerprint_digest_len],
    );
}

test "lineage envelope fingerprint changes when trace-envelope digest changes" {
    var a = testCtxWithTrace(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithTrace(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.lineage_envelope_fingerprint_digest_hex[0..a.lineage_envelope_fingerprint_digest_len],
        b.lineage_envelope_fingerprint_digest_hex[0..b.lineage_envelope_fingerprint_digest_len],
    ));
}

test "lineage envelope fingerprint matches golden for M28 trace-envelope digest chain" {
    const golden_lineage = "ab0d29132d75a50c33523822984a11df745fa6cd934d2ee9d638b240a84c8659";
    var ctx = testCtxWithTrace(&"c6c42cdc0e94231e4ae5d1105e5add411bfe274c1a360153993dafb0ad7f31e1".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.lineage_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_lineage, ctx.lineage_envelope_fingerprint_digest_hex[0..ctx.lineage_envelope_fingerprint_digest_len]);
}
