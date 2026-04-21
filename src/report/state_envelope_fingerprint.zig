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

/// Fills `ctx.state_envelope_fingerprint_digest_*` from SHA-256 of the PH1-M30 canonical payload (`docs/STATE_ENVELOPE_FINGERPRINT_PLAN.md`).
/// Call after `lineage_envelope_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M30/state-envelope/fp/v1\n");

    try appendDigestVersion(&canon, allocator, &ctx.lineage_envelope_fingerprint_digest_hex, ctx.lineage_envelope_fingerprint_digest_len);

    try canon.appendSlice(allocator, "state:run.json:v0.1\n");

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.state_envelope_fingerprint_digest_hex, &digest);
    ctx.state_envelope_fingerprint_digest_len = 64;
}

fn fillDigest(dst: *[64]u8, len: *u8, hex_lower_64: *const [64]u8) void {
    @memcpy(dst, hex_lower_64);
    len.* = 64;
}

fn testCtxWithLineage(lineage: *const [64]u8) RunContext {
    var ctx = RunContext.initDefault();
    fillDigest(&ctx.lineage_envelope_fingerprint_digest_hex, &ctx.lineage_envelope_fingerprint_digest_len, lineage);
    return ctx;
}

test "state envelope fingerprint is deterministic for fixed lineage-envelope digest" {
    var a = testCtxWithLineage(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithLineage(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expectEqual(a.state_envelope_fingerprint_digest_len, b.state_envelope_fingerprint_digest_len);
    try std.testing.expectEqualSlices(
        u8,
        a.state_envelope_fingerprint_digest_hex[0..a.state_envelope_fingerprint_digest_len],
        b.state_envelope_fingerprint_digest_hex[0..b.state_envelope_fingerprint_digest_len],
    );
}

test "state envelope fingerprint changes when lineage-envelope digest changes" {
    var a = testCtxWithLineage(&"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".*);
    var b = testCtxWithLineage(&"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".*);
    try populate(&a, std.testing.allocator);
    try populate(&b, std.testing.allocator);
    try std.testing.expect(!std.mem.eql(
        u8,
        a.state_envelope_fingerprint_digest_hex[0..a.state_envelope_fingerprint_digest_len],
        b.state_envelope_fingerprint_digest_hex[0..b.state_envelope_fingerprint_digest_len],
    ));
}

test "state envelope fingerprint matches golden for M29 lineage-envelope digest chain" {
    const golden_state = "fc9e33e37e4d5cc403f7738cb104509dee956b6cfee8c3170f119ecfa078a6ee";
    var ctx = testCtxWithLineage(&"ab0d29132d75a50c33523822984a11df745fa6cd934d2ee9d638b240a84c8659".*);
    try populate(&ctx, std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 64), ctx.state_envelope_fingerprint_digest_len);
    try std.testing.expectEqualStrings(golden_state, ctx.state_envelope_fingerprint_digest_hex[0..ctx.state_envelope_fingerprint_digest_len]);
}
