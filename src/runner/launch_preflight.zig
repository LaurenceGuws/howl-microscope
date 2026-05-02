//! PH1-M35: deterministic argv[0] availability before bounded terminal launch (see `docs/LAUNCH_PREFLIGHT_PLAN.md`).

const std = @import("std");
const run_context_mod = @import("../cli/run_context.zig");
const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("stdlib.h");
});

/// Preflight not applicable (wrong OS, empty probe, or harness path that skips preflight).
pub const reason_na = "na";
/// Resolved target exists and is executable.
pub const reason_ok = "ok";
/// No candidate path or file missing.
pub const reason_missing_executable = "missing_executable";
/// Path exists but is not a regular executable file.
pub const reason_not_executable = "not_executable";

/// PH1-M36: no resolved path for normalization (failed probe or pre-`realpath`).
pub const path_normalization_na = "na";
/// PH1-M36: `realpath` produced **`terminal_exec_resolved_path`** (see `tryCanonicalizeResolvedPathLinux`).
pub const path_normalization_canonical = "canonical";
/// PH1-M36: probe path kept verbatim (`realpath` unavailable or failed).
pub const path_normalization_literal = "literal";

/// Result of an `argv[0]` availability probe; copied into `RunContext` for artifacts.
pub const Probe = struct {
    ok: bool,
    reason: []const u8,
    resolved_path_buf: [512]u8 = std.mem.zeroes([512]u8),
    resolved_path_len: u16 = 0,
    /// PH1-M36: how **`terminal_exec_resolved_path`** will be labeled when emitted.
    path_normalization: []const u8 = path_normalization_na,

    pub fn resolvedPathSlice(self: *const Probe) ?[]const u8 {
        if (self.resolved_path_len == 0) return null;
        return self.resolved_path_buf[0..self.resolved_path_len];
    }
};

fn copyResolvedPath(p: *Probe, path: []const u8) void {
    const n = @min(path.len, p.resolved_path_buf.len);
    @memcpy(p.resolved_path_buf[0..n], path[0..n]);
    p.resolved_path_len = @intCast(n);
}

/// PH1-M36: replace probe buffer with **`realpath`** output when possible (Linux).
fn tryCanonicalizeResolvedPathLinux(p: *Probe, probe_path: []const u8) void {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return;
    var out_buf: [std.fs.max_path_bytes]u8 = undefined;
    var in_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    if (probe_path.len + 1 > in_buf.len) return;
    @memcpy(in_buf[0..probe_path.len], probe_path);
    in_buf[probe_path.len] = 0;
    if (c.realpath(&in_buf, &out_buf)) |canon| {
        copyResolvedPath(p, std.mem.span(canon));
        p.path_normalization = path_normalization_canonical;
    } else {
        p.path_normalization = path_normalization_literal;
    }
}

fn finishFromPath(path: []const u8) Probe {
    var zbuf: [4096]u8 = undefined;
    if (path.len + 1 > zbuf.len) return .{ .ok = false, .reason = reason_missing_executable };
    @memcpy(zbuf[0..path.len], path);
    zbuf[path.len] = 0;
    if (c.access(@ptrCast(&zbuf), c.X_OK) != 0) return .{ .ok = false, .reason = reason_not_executable };
    var p = Probe{ .ok = true, .reason = reason_ok, .path_normalization = path_normalization_literal };
    copyResolvedPath(&p, path);
    tryCanonicalizeResolvedPathLinux(&p, path);
    return p;
}

/// Linux: resolve **`argv[0]`** against **`PATH`** (bare name) or treat **`/`** paths as explicit. Other OS: **`reason_na`**.
pub fn probeArgv0ExecutableLinux(argv0: []const u8) Probe {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) {
        return .{ .ok = false, .reason = reason_na };
    }
    if (argv0.len == 0) {
        return .{ .ok = false, .reason = reason_missing_executable };
    }

    if (std.mem.indexOfScalar(u8, argv0, '/')) |_| {
        if (argv0.len == 0) {
            return .{ .ok = false, .reason = reason_missing_executable };
        }
        return finishFromPath(argv0);
    }

    const path_env = if (c.getenv("PATH")) |p| std.mem.span(p) else "";
    var it = std.mem.tokenizeScalar(u8, path_env, ':');
    var cand_buf: [4096]u8 = undefined;
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const written = std.fmt.bufPrint(&cand_buf, "{s}/{s}", .{ dir, argv0 }) catch continue;
        const r = finishFromPath(written);
        if (r.ok) return r;
        if (std.mem.eql(u8, r.reason, reason_not_executable)) return r;
    }

    return .{ .ok = false, .reason = reason_missing_executable };
}

/// Copies probe results into `ctx` for **`run.json`** (PH1-M35).
pub fn applyProbeToContext(ctx: *run_context_mod.RunContext, probe: *const Probe) void {
    ctx.terminal_launch_preflight_ok = probe.ok;
    ctx.terminal_launch_preflight_reason = probe.reason;
    ctx.terminal_exec_resolved_path_len = 0;
    ctx.terminal_exec_resolved_path_normalization = null;
    if (probe.resolvedPathSlice()) |rp| {
        const n = @min(rp.len, run_context_mod.terminal_exec_resolved_path_cap);
        @memcpy(ctx.terminal_exec_resolved_path_buf[0..n], rp[0..n]);
        ctx.terminal_exec_resolved_path_len = @intCast(n);
        ctx.terminal_exec_resolved_path_normalization = probe.path_normalization;
    }
}

test "probeArgv0ExecutableLinux finds /bin/true" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const p = probeArgv0ExecutableLinux("/bin/true");
    try std.testing.expect(p.ok);
    try std.testing.expectEqualStrings(reason_ok, p.reason);
    try std.testing.expectEqualStrings(path_normalization_canonical, p.path_normalization);
    try std.testing.expect(std.mem.eql(u8, p.resolvedPathSlice().?, "/bin/true") or std.mem.endsWith(u8, p.resolvedPathSlice().?, "/bin/true"));
}

test "probeArgv0ExecutableLinux bare true uses PATH" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const p = probeArgv0ExecutableLinux("true");
    try std.testing.expect(p.ok);
    try std.testing.expectEqualStrings(reason_ok, p.reason);
    try std.testing.expectEqualStrings(path_normalization_canonical, p.path_normalization);
    try std.testing.expect(std.mem.endsWith(u8, p.resolvedPathSlice().?, "/true"));
}

test "probeArgv0ExecutableLinux missing basename" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const p = probeArgv0ExecutableLinux("no_such_binary_howl_microscope_m35_xyz");
    try std.testing.expect(!p.ok);
    try std.testing.expectEqualStrings(reason_missing_executable, p.reason);
}

test "probeArgv0ExecutableLinux non-executable regular file" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var f = try tmp.dir.createFile("not-exec.sh", .{ .truncate = true });
        defer f.close();
        try f.writeAll("#!/bin/sh\necho hi\n");
        try f.chmod(@as(std.fs.File.Mode, 0o644));
    }

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/not-exec.sh", .{tmp.sub_path[0..]});
    defer std.testing.allocator.free(path);

    const p = probeArgv0ExecutableLinux(path);
    try std.testing.expect(!p.ok);
    try std.testing.expectEqualStrings(reason_not_executable, p.reason);
}
