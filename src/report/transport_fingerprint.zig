const std = @import("std");
const RunContext = @import("../cli/run_context.zig").RunContext;
const transport_stub = @import("../runner/transport_stub.zig");

fn writeHexLower(dst: *[64]u8, src: *const [32]u8) void {
    const hex = "0123456789abcdef";
    inline for (0..32) |i| {
        const b = src[i];
        dst[i * 2] = hex[b >> 4];
        dst[i * 2 + 1] = hex[b & 15];
    }
}

/// Fills `ctx.transport_fingerprint_digest_*` from SHA-256 of the PH1-M14 canonical payload (`docs/TRANSPORT_FINGERPRINT_PLAN.md`).
/// Call after `resultset_fingerprint.populate` when emitting `run.json` (pass the same `run_id` as `writeRun`).
pub fn populate(ctx: *RunContext, allocator: std.mem.Allocator, run_id: []const u8) !void {
    var canon: std.ArrayList(u8) = .empty;
    defer canon.deinit(allocator);

    try canon.appendSlice(allocator, "PH1-M14/transport/fp/v4\n");

    const guarded_opt_in = ctx.transport_mode == .pty_guarded;
    const guarded_state: []const u8 = blk: {
        if (ctx.transport_mode != .pty_guarded) break :blk "na";
        if (ctx.dry_run) break :blk "scaffold_only";
        break :blk "experiment_linux_pty";
    };

    try canon.print(allocator, "{s}\n{d}\n{s}\n{s}\n", .{
        ctx.transport_mode.tag(),
        ctx.timeout_ms,
        if (guarded_opt_in) "true" else "false",
        guarded_state,
    });

    if (transport_stub.handshakeString(ctx.transport_mode)) |hs| {
        try canon.print(allocator, "{s}\n", .{hs});
    } else {
        try canon.appendSlice(allocator, "null\n");
    }

    const lat_ns = transport_stub.handshakeLatencyNs(ctx.transport_mode, run_id);
    try canon.print(allocator, "{d}\n", .{lat_ns});

    if (ctx.transport_mode == .pty_guarded) {
        if (ctx.pty_capability_notes) |n| {
            try canon.print(allocator, "{s}\n", .{n});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.pty_experiment_attempt) |a| {
            try canon.print(allocator, "{d}\n", .{a});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.pty_experiment_elapsed_ns) |e| {
            try canon.print(allocator, "{d}\n", .{e});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.pty_experiment_error) |e| {
            try canon.print(allocator, "{s}\n", .{e});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        const pty_host_null = std.mem.eql(u8, guarded_state, "scaffold_only");
        if (pty_host_null) {
            try canon.appendSlice(allocator, "null\nnull\n");
        } else {
            try canon.print(allocator, "{s}\n", .{ctx.pty_experiment_host_machine[0..ctx.pty_experiment_host_machine_len]});
            try canon.print(allocator, "{s}\n", .{ctx.pty_experiment_host_release[0..ctx.pty_experiment_host_release_len]});
        }
        if (ctx.pty_experiment_open_ok) |b| {
            try canon.print(allocator, "{s}\n", .{if (b) "true" else "false"});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_launch_attempt) |a| {
            try canon.print(allocator, "{d}\n", .{a});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_launch_elapsed_ns) |e| {
            try canon.print(allocator, "{d}\n", .{e});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_launch_error) |e| {
            try canon.print(allocator, "{s}\n", .{e});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_launch_exit_code) |code| {
            try canon.print(allocator, "{d}\n", .{code});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_launch_ok) |b| {
            try canon.print(allocator, "{s}\n", .{if (b) "true" else "false"});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_launch_outcome) |o| {
            try canon.print(allocator, "{s}\n", .{o});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_launch_preflight_ok) |b| {
            try canon.print(allocator, "{s}\n", .{if (b) "true" else "false"});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_launch_preflight_reason) |r| {
            try canon.print(allocator, "{s}\n", .{r});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        // PH1-M37: include diagnostics reason in canonical transport payload (v4).
        if (ctx.terminal_launch_diagnostics_reason_len > 0) {
            const reason = ctx.terminal_launch_diagnostics_reason_buf[0..ctx.terminal_launch_diagnostics_reason_len];
            try canon.print(allocator, "{s}\n", .{reason});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_exec_resolved_path_len > 0) {
            try canon.print(allocator, "{s}\n", .{ctx.terminal_exec_resolved_path_buf[0..ctx.terminal_exec_resolved_path_len]});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
        if (ctx.terminal_exec_resolved_path_normalization) |tag| {
            try canon.print(allocator, "{s}\n", .{tag});
        } else {
            try canon.appendSlice(allocator, "null\n");
        }
    }

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canon.items, &digest, .{});

    writeHexLower(&ctx.transport_fingerprint_digest_hex, &digest);
    ctx.transport_fingerprint_digest_len = 64;
}

test "populate is deterministic for same transport context and run_id" {
    var ctx = RunContext.initDefault();
    var ctx2 = RunContext.initDefault();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    try populate(&ctx, a, "run-same");
    try populate(&ctx2, a, "run-same");

    try std.testing.expectEqualSlices(u8, ctx.transport_fingerprint_digest_hex[0..64], ctx2.transport_fingerprint_digest_hex[0..64]);
}

test "populate changes when transport mode changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var ctx_none = RunContext.initDefault();
    try populate(&ctx_none, a, "rid");

    var ctx_stub = RunContext.initDefault();
    ctx_stub.transport_mode = .pty_stub;
    try populate(&ctx_stub, a, "rid");

    try std.testing.expect(!std.mem.eql(u8, ctx_none.transport_fingerprint_digest_hex[0..64], ctx_stub.transport_fingerprint_digest_hex[0..64]));
}

test "populate changes when run_id changes stub handshake latency" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var ctx_a = RunContext.initDefault();
    ctx_a.transport_mode = .pty_stub;
    try populate(&ctx_a, a, "run-aaa");

    var ctx_b = RunContext.initDefault();
    ctx_b.transport_mode = .pty_stub;
    try populate(&ctx_b, a, "run-bbb");

    try std.testing.expect(!std.mem.eql(u8, ctx_a.transport_fingerprint_digest_hex[0..64], ctx_b.transport_fingerprint_digest_hex[0..64]));
}
