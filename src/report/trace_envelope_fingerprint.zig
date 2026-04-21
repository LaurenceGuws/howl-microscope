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

/// Fills `ctx.trace_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M28 canonical payload (`docs/TRACE_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `consistency_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M28/trace-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.consistency_envelope_fingerprint_digest_hex, ctx.consistency_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "trace:run.json:v0.2\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.trace_envelope_fingerprint_digest_hex, &digest);
    ctx.trace_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithConsistency(cons: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.consistency_envelope_fingerprint_digest_hex, &ctx.consistency_envelope_fingerprint_digest_len, cons);
    return ctx;
}

test "trace envelope fingerprint is deterministic for fixed consistency-envelope digest" {
    var a = testCtxWithConsistency(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithConsistency(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.trace_envelope_fingerprint_digest_len, b.trace_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.trace_envelope_fingerprint_digest_hex[0..a.trace_envelope_fingerprint_digest_len],
        b.trace_envelope_fingerprint_digest_hex[0..b.trace_envelope_fingerprint_digest_len],
    );
}

test "trace envelope fingerprint changes when consistency-envelope digest changes" {
    var a = testCtxWithConsistency(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithConsistency(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.trace_envelope_fingerprint_digest_hex[0..a.trace_envelope_fingerprint_digest_len],
        b.trace_envelope_fingerprint_digest_hex[0..b.trace_envelope_fingerprint_digest_len],
    ));
}

test "trace envelope fingerprint matches golden for M27 consistency-envelope digest chain" {
    const golden_trace = "c6c42cdc0e94231e4ae5d1105e5add411bfe274c1a360153993dafb0ad7f31e1";
    var ctx = testCtxWithConsistency(&"40b1a4678654405c7d0d72dcc6cc992d8038d983fb28455b34ccba3a2132207a".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.trace_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_trace, ctx.trace_envelope_fingerprint_digest_hex[0..ctx.trace_envelope_fingerprint_digest_len]);
}
