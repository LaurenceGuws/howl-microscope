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

/// Fills `ctx.context_summary_fingerprint_digest_*` from SHA-256 of the PH1-M16 canonical payload (`docs/CONTEXT_SUMMARY_FINGERPRINT_PLAN.md`).
/// Call after `exec_summary_fingerprint.populate` when emitting `run.json`. Pass the same `term` string written to root `term`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator, term: []const u8) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M16/context-summary/fp/v1\n");
    try canon.print(allocator, "{s}\n{s}\n{s}\n", .{
        term,
        ctx.terminal_cmd,
        if (ctx.allow_guarded_transport) "true" else "false",
    });
    try canon.print(allocator, "{s}\n{s}\n{s}\n", .{
        ctx.host_identity_machine[0..ctx.host_identity_machine_len],
        ctx.host_identity_release[0..ctx.host_identity_release_len],
        ctx.host_identity_sysname[0..ctx.host_identity_sysname_len],
    });

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.context_summary_fingerprint_digest_hex, &digest);
    ctx.context_summary_fingerprint_digest_len = 64;
}

test "populate is deterministic for same RunContext snapshot and term" {
    var ctx = RunContext.initDefault();
    var ctx2 = RunContext.initDefault();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    try populate(&ctx, a, "xterm-256color");
    try populate(&ctx2, a, "xterm-256color");

    try std.testing.expectEqualSlices(u8, ctx.context_summary_fingerprint_digest_hex[0..64], ctx2.context_summary_fingerprint_digest_hex[0..64]);
}

test "populate changes when term string differs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var a_ctx = RunContext.initDefault();
    try populate(&a_ctx, a, "dumb");

    var b_ctx = RunContext.initDefault();
    try populate(&b_ctx, a, "xterm");

    try std.testing.expect(!std.mem.eql(u8, a_ctx.context_summary_fingerprint_digest_hex[0..64], b_ctx.context_summary_fingerprint_digest_hex[0..64]));
}

test "populate changes when terminal_cmd differs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var empty_cmd = RunContext.initDefault();
    try populate(&empty_cmd, a, "xterm");

    var with_cmd = RunContext.initDefault();
    with_cmd.terminal_cmd = "wezterm start";
    try populate(&with_cmd, a, "xterm");

    try std.testing.expect(!std.mem.eql(u8, empty_cmd.context_summary_fingerprint_digest_hex[0..64], with_cmd.context_summary_fingerprint_digest_hex[0..64]));
}

test "populate changes when allow_guarded_transport differs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var off = RunContext.initDefault();
    try populate(&off, a, "");

    var on = RunContext.initDefault();
    on.allow_guarded_transport = true;
    try populate(&on, a, "");

    try std.testing.expect(!std.mem.eql(u8, off.context_summary_fingerprint_digest_hex[0..64], on.context_summary_fingerprint_digest_hex[0..64]));
}

test "populate changes when host_identity_machine differs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var m1 = RunContext.initDefault();
    const s1 = "aarch64";
    @memcpy(m1.host_identity_machine[0..s1.len], s1);
    m1.host_identity_machine_len = @intCast(s1.len);
    try populate(&m1, a, "");

    var m2 = RunContext.initDefault();
    const s2 = "x86_64";
    @memcpy(m2.host_identity_machine[0..s2.len], s2);
    m2.host_identity_machine_len = @intCast(s2.len);
    try populate(&m2, a, "");

    try std.testing.expect(!std.mem.eql(u8, m1.context_summary_fingerprint_digest_hex[0..64], m2.context_summary_fingerprint_digest_hex[0..64]));
}
