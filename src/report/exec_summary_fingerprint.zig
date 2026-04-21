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

/// Fills `ctx.exec_summary_fingerprint_digest_*` from SHA-256 of the PH1-M15 canonical payload (`docs/EXEC_SUMMARY_FINGERPRINT_PLAN.md`).
/// Call after `transport_fingerprint.populate` when emitting `run.json`.
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M15/exec-summary/fp/v1\n");
    try canon.print(allocator, "{s}\n{s}\n{s}\n{s}\n{s}\n", .{
        ctx.execution_mode.tag(),
        if (ctx.strict) "true" else "false",
        ctx.platform,
        ctx.capture_mode,
        ctx.terminal_name,
    });

    if (ctx.suite_name) |s| {
        try canon.print(allocator, "{s}\n", .{s});
    } else {
        try canon.appendSlice(allocator, "null\n");
    }
    if (ctx.comparison_id) |s| {
        try canon.print(allocator, "{s}\n", .{s});
    } else {
        try canon.appendSlice(allocator, "null\n");
    }
    if (ctx.run_group) |s| {
        try canon.print(allocator, "{s}\n", .{s});
    } else {
        try canon.appendSlice(allocator, "null\n");
    }

    try canon.print(allocator, "{s}\n{d}\n", .{ ctx.transport_mode.tag(), ctx.timeout_ms });

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.exec_summary_fingerprint_digest_hex, &digest);
    ctx.exec_summary_fingerprint_digest_len = 64;
}

test "populate is deterministic for same RunContext snapshot" {
    var ctx = RunContext.initDefault();
    var ctx2 = RunContext.initDefault();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    try populate(&ctx, a);
    try populate(&ctx2, a);

    try std.testing.expectEqualSlices(u8, ctx.exec_summary_fingerprint_digest_hex[0..64], ctx2.exec_summary_fingerprint_digest_hex[0..64]);
}

test "populate changes when strict flag differs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var loose = RunContext.initDefault();
    try populate(&loose, a);

    var strict_ctx = RunContext.initDefault();
    strict_ctx.strict = true;
    try populate(&strict_ctx, a);

    try std.testing.expect(!std.mem.eql(u8, loose.exec_summary_fingerprint_digest_hex[0..64], strict_ctx.exec_summary_fingerprint_digest_hex[0..64]));
}

test "populate changes when execution_mode differs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var ph = RunContext.initDefault();
    try populate(&ph, a);

    var stub = RunContext.initDefault();
    stub.execution_mode = .protocol_stub;
    try populate(&stub, a);

    try std.testing.expect(!std.mem.eql(u8, ph.exec_summary_fingerprint_digest_hex[0..64], stub.exec_summary_fingerprint_digest_hex[0..64]));
}

test "populate changes when suite_name present vs absent" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var null_suite = RunContext.initDefault();
    try populate(&null_suite, a);

    var named = RunContext.initDefault();
    named.suite_name = "s1";
    try populate(&named, a);

    try std.testing.expect(!std.mem.eql(u8, null_suite.exec_summary_fingerprint_digest_hex[0..64], named.exec_summary_fingerprint_digest_hex[0..64]));
}

test "populate changes when transport_mode differs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var none = RunContext.initDefault();
    try populate(&none, a);

    var stub = RunContext.initDefault();
    stub.transport_mode = .pty_stub;
    try populate(&stub, a);

    try std.testing.expect(!std.mem.eql(u8, none.exec_summary_fingerprint_digest_hex[0..64], stub.exec_summary_fingerprint_digest_hex[0..64]));
}

test "populate changes when timeout_ms differs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var a30 = RunContext.initDefault();
    a30.timeout_ms = 30_000;
    try populate(&a30, a);

    var b60 = RunContext.initDefault();
    b60.timeout_ms = 60_000;
    try populate(&b60, a);

    try std.testing.expect(!std.mem.eql(u8, a30.exec_summary_fingerprint_digest_hex[0..64], b60.exec_summary_fingerprint_digest_hex[0..64]));
}
