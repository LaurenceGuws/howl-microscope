const std = @import("std");
const posix = std.posix;
const c = std.c;

/// PH1-M31 process-level launch evidence (maps to `RunContext.terminal_launch_*`).
pub const LaunchTelemetry = struct {
    attempt: ?u32 = null,
    elapsed_ns: ?u64 = null,
    exit_code: ?u32 = null,
    ok: ?bool = null,
    err: ?[]const u8 = null,
    /// PH1-M32 explicit outcome class (`transport.terminal_launch_outcome`).
    outcome: ?[]const u8 = null,
    /// PH1-M37 normalized failure reason for diagnostics envelope.
    diagnostics_reason: ?[]const u8 = null,
    /// PH1-M37 wall-time milliseconds from spawn to outcome.
    diagnostics_elapsed_ms: ?u32 = null,
    /// PH1-M37 signal number when signaled; null otherwise.
    diagnostics_signal: ?u32 = null,
    /// PH1-M38 64-char lowercase SHA-256 hex of launch diagnostics fingerprint.
    launch_diagnostics_fingerprint_digest: ?[]const u8 = null,
};

pub const err_spawn_failed: []const u8 = "spawn_failed";
pub const err_timeout: []const u8 = "timeout";

pub const outcome_ok: []const u8 = "ok";
pub const outcome_nonzero_exit: []const u8 = "nonzero_exit";
pub const outcome_signaled: []const u8 = "signaled";
pub const outcome_timeout: []const u8 = "timeout";
pub const outcome_spawn_failed: []const u8 = "spawn_failed";

/// PH1-M37 diagnostics failure reasons (normalized across preflight, spawn, termination).
pub const diagnostics_ok: []const u8 = "ok";
pub const diagnostics_missing_executable: []const u8 = "missing_executable";
pub const diagnostics_not_executable: []const u8 = "not_executable";
pub const diagnostics_spawn_failed: []const u8 = "spawn_failed";
pub const diagnostics_timeout: []const u8 = "timeout";
pub const diagnostics_nonzero_exit: []const u8 = "nonzero_exit";
pub const diagnostics_signaled: []const u8 = "signaled";

fn clampJsonNs(raw: u64) u64 {
    return @min(raw, @as(u64, @intCast(std.math.maxInt(i64))));
}

fn elapsedNsToMs(elapsed_ns: u64) u32 {
    const ms = (elapsed_ns + std.time.ns_per_ms - 1) / std.time.ns_per_ms;
    return @intCast(@min(ms, @as(u64, @intCast(std.math.maxInt(u32)))));
}

/// Runs `argv[0]` with remaining args with stdio discarded; polls `waitpid(WNOHANG)` until exit or `timeout_ms` elapses (then `SIGKILL`).
/// Non-Linux: returns all-null fields. Empty `argv`: returns all-null fields.
pub fn runBoundedArgvCommand(allocator: std.mem.Allocator, argv: []const []const u8, timeout_ms: u32) LaunchTelemetry {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return .{};
    if (argv.len == 0) return .{};

    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    child.spawn() catch {
        return .{
            .attempt = 1,
            .elapsed_ns = 0,
            .exit_code = null,
            .ok = false,
            .err = err_spawn_failed,
            .outcome = outcome_spawn_failed,
            .diagnostics_reason = diagnostics_spawn_failed,
            .diagnostics_elapsed_ms = 0,
            .diagnostics_signal = null,
        };
    };

    child.waitForSpawn() catch {
        return .{
            .attempt = 1,
            .elapsed_ns = 0,
            .exit_code = null,
            .ok = false,
            .err = err_spawn_failed,
            .outcome = outcome_spawn_failed,
            .diagnostics_reason = diagnostics_spawn_failed,
            .diagnostics_elapsed_ms = 0,
            .diagnostics_signal = null,
        };
    };

    const pid = child.id;
    const t_start = std.time.Instant.now() catch {
        posix.kill(pid, posix.SIG.KILL) catch {};
        var st_kill: c_int = undefined;
        _ = c.waitpid(pid, &st_kill, 0);
        return .{
            .attempt = 1,
            .elapsed_ns = 0,
            .exit_code = null,
            .ok = false,
            .err = err_spawn_failed,
            .outcome = outcome_spawn_failed,
            .diagnostics_reason = diagnostics_spawn_failed,
            .diagnostics_elapsed_ms = 0,
            .diagnostics_signal = null,
        };
    };

    const budget_ns = @as(u64, timeout_ms) * std.time.ns_per_ms;

    while (true) {
        var status: c_int = undefined;
        const wr = c.waitpid(pid, &status, 1); // WNOHANG
        if (wr == 0) {
            const now = std.time.Instant.now() catch {
                posix.kill(pid, posix.SIG.KILL) catch {};
                var st_clock: c_int = undefined;
                _ = c.waitpid(pid, &st_clock, 0);
                return .{
                    .attempt = 1,
                    .elapsed_ns = 0,
                    .exit_code = null,
                    .ok = false,
                    .err = err_spawn_failed,
                    .outcome = outcome_spawn_failed,
                    .diagnostics_reason = diagnostics_spawn_failed,
                    .diagnostics_elapsed_ms = 0,
                    .diagnostics_signal = null,
                };
            };
            const elapsed_raw = now.since(t_start);
            if (elapsed_raw > budget_ns) {
                posix.kill(pid, posix.SIG.KILL) catch {};
                var st_to: c_int = undefined;
                _ = c.waitpid(pid, &st_to, 0);
                const el = clampJsonNs(now.since(t_start));
                return .{
                    .attempt = 1,
                    .elapsed_ns = el,
                    .exit_code = null,
                    .ok = false,
                    .err = err_timeout,
                    .outcome = outcome_timeout,
                    .diagnostics_reason = diagnostics_timeout,
                    .diagnostics_elapsed_ms = elapsedNsToMs(el),
                    .diagnostics_signal = null,
                };
            }
            std.Thread.sleep(1 * std.time.ns_per_ms);
            continue;
        }
        if (wr == -1) {
            switch (posix.errno(wr)) {
                .INTR => continue,
                else => {
                    const now_e = std.time.Instant.now() catch {
                        return .{
                            .attempt = 1,
                            .elapsed_ns = 0,
                            .exit_code = null,
                            .ok = false,
                            .err = err_spawn_failed,
                            .outcome = outcome_spawn_failed,
                            .diagnostics_reason = diagnostics_spawn_failed,
                            .diagnostics_elapsed_ms = 0,
                            .diagnostics_signal = null,
                        };
                    };
                    const el_e = clampJsonNs(now_e.since(t_start));
                    return .{
                        .attempt = 1,
                        .elapsed_ns = el_e,
                        .exit_code = null,
                        .ok = false,
                        .err = err_spawn_failed,
                        .outcome = outcome_spawn_failed,
                        .diagnostics_reason = diagnostics_spawn_failed,
                        .diagnostics_elapsed_ms = elapsedNsToMs(el_e),
                        .diagnostics_signal = null,
                    };
                },
            }
        }
        if (wr != pid) {
            const now_u = std.time.Instant.now() catch {
                return .{
                    .attempt = 1,
                    .elapsed_ns = 0,
                    .exit_code = null,
                    .ok = false,
                    .err = err_spawn_failed,
                    .outcome = outcome_spawn_failed,
                    .diagnostics_reason = diagnostics_spawn_failed,
                    .diagnostics_elapsed_ms = 0,
                    .diagnostics_signal = null,
                };
            };
            const el_u = clampJsonNs(now_u.since(t_start));
            return .{
                .attempt = 1,
                .elapsed_ns = el_u,
                .exit_code = null,
                .ok = false,
                .err = err_spawn_failed,
                .outcome = outcome_spawn_failed,
                .diagnostics_reason = diagnostics_spawn_failed,
                .diagnostics_elapsed_ms = elapsedNsToMs(el_u),
                .diagnostics_signal = null,
            };
        }

        const now_done = std.time.Instant.now() catch unreachable;
        const elapsed_final = clampJsonNs(now_done.since(t_start));
        const elapsed_final_ms = elapsedNsToMs(elapsed_final);
        const ustatus: u32 = @bitCast(status);
        if (posix.W.IFEXITED(ustatus)) {
            const ec = posix.W.EXITSTATUS(ustatus);
            if (ec == 0) {
                return .{
                    .attempt = 1,
                    .elapsed_ns = elapsed_final,
                    .exit_code = 0,
                    .ok = true,
                    .err = null,
                    .outcome = outcome_ok,
                    .diagnostics_reason = diagnostics_ok,
                    .diagnostics_elapsed_ms = elapsed_final_ms,
                    .diagnostics_signal = null,
                };
            }
            return .{
                .attempt = 1,
                .elapsed_ns = elapsed_final,
                .exit_code = ec,
                .ok = false,
                .err = null,
                .outcome = outcome_nonzero_exit,
                .diagnostics_reason = diagnostics_nonzero_exit,
                .diagnostics_elapsed_ms = elapsed_final_ms,
                .diagnostics_signal = null,
            };
        }
        if (posix.W.IFSIGNALED(ustatus)) {
            const sig = posix.W.TERMSIG(ustatus);
            return .{
                .attempt = 1,
                .elapsed_ns = elapsed_final,
                .exit_code = null,
                .ok = false,
                .err = null,
                .outcome = outcome_signaled,
                .diagnostics_reason = diagnostics_signaled,
                .diagnostics_elapsed_ms = elapsed_final_ms,
                .diagnostics_signal = sig,
            };
        }
        return .{
            .attempt = 1,
            .elapsed_ns = elapsed_final,
            .exit_code = null,
            .ok = false,
            .err = err_spawn_failed,
            .outcome = outcome_spawn_failed,
            .diagnostics_reason = diagnostics_spawn_failed,
            .diagnostics_elapsed_ms = elapsed_final_ms,
            .diagnostics_signal = null,
        };
    }
}

/// Runs `/bin/sh -c <cmd>` with stdio discarded; polls `waitpid(WNOHANG)` until exit or `timeout_ms` elapses (then `SIGKILL`).
/// Non-Linux: returns all-null fields. Empty `cmd`: returns all-null fields.
pub fn runBoundedShellCommand(allocator: std.mem.Allocator, cmd: []const u8, timeout_ms: u32) LaunchTelemetry {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return .{};
    if (cmd.len == 0) return .{};

    const argv = [_][]const u8{ "/bin/sh", "-c", cmd };
    var child = std.process.Child.init(&argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    child.spawn() catch {
        return .{
            .attempt = 1,
            .elapsed_ns = 0,
            .exit_code = null,
            .ok = false,
            .err = err_spawn_failed,
            .outcome = outcome_spawn_failed,
        };
    };

    child.waitForSpawn() catch {
        return .{
            .attempt = 1,
            .elapsed_ns = 0,
            .exit_code = null,
            .ok = false,
            .err = err_spawn_failed,
            .outcome = outcome_spawn_failed,
        };
    };

    const pid = child.id;
    const t_start = std.time.Instant.now() catch {
        posix.kill(pid, posix.SIG.KILL) catch {};
        var st_kill: c_int = undefined;
        _ = c.waitpid(pid, &st_kill, 0);
        return .{
            .attempt = 1,
            .elapsed_ns = 0,
            .exit_code = null,
            .ok = false,
            .err = err_spawn_failed,
            .outcome = outcome_spawn_failed,
        };
    };

    const budget_ns = @as(u64, timeout_ms) * std.time.ns_per_ms;

    while (true) {
        var status: c_int = undefined;
        const wr = c.waitpid(pid, &status, 1); // WNOHANG
        if (wr == 0) {
            const now = std.time.Instant.now() catch {
                posix.kill(pid, posix.SIG.KILL) catch {};
                var st_clock: c_int = undefined;
                _ = c.waitpid(pid, &st_clock, 0);
                return .{
                    .attempt = 1,
                    .elapsed_ns = 0,
                    .exit_code = null,
                    .ok = false,
                    .err = err_spawn_failed,
                    .outcome = outcome_spawn_failed,
                    .diagnostics_reason = diagnostics_spawn_failed,
                    .diagnostics_elapsed_ms = 0,
                    .diagnostics_signal = null,
                };
            };
            const elapsed_raw = now.since(t_start);
            if (elapsed_raw > budget_ns) {
                posix.kill(pid, posix.SIG.KILL) catch {};
                var st_to: c_int = undefined;
                _ = c.waitpid(pid, &st_to, 0);
                const el = clampJsonNs(now.since(t_start));
                return .{
                    .attempt = 1,
                    .elapsed_ns = el,
                    .exit_code = null,
                    .ok = false,
                    .err = err_timeout,
                    .outcome = outcome_timeout,
                    .diagnostics_reason = diagnostics_timeout,
                    .diagnostics_elapsed_ms = elapsedNsToMs(el),
                    .diagnostics_signal = null,
                };
            }
            std.Thread.sleep(1 * std.time.ns_per_ms);
            continue;
        }
        if (wr == -1) {
            switch (posix.errno(wr)) {
                .INTR => continue,
                else => {
                    const now_e = std.time.Instant.now() catch {
                        return .{
                            .attempt = 1,
                            .elapsed_ns = 0,
                            .exit_code = null,
                            .ok = false,
                            .err = err_spawn_failed,
                            .outcome = outcome_spawn_failed,
                            .diagnostics_reason = diagnostics_spawn_failed,
                            .diagnostics_elapsed_ms = 0,
                            .diagnostics_signal = null,
                        };
                    };
                    const el_e = clampJsonNs(now_e.since(t_start));
                    return .{
                        .attempt = 1,
                        .elapsed_ns = el_e,
                        .exit_code = null,
                        .ok = false,
                        .err = err_spawn_failed,
                        .outcome = outcome_spawn_failed,
                        .diagnostics_reason = diagnostics_spawn_failed,
                        .diagnostics_elapsed_ms = elapsedNsToMs(el_e),
                        .diagnostics_signal = null,
                    };
                },
            }
        }
        if (wr != pid) {
            const now_u = std.time.Instant.now() catch {
                return .{
                    .attempt = 1,
                    .elapsed_ns = 0,
                    .exit_code = null,
                    .ok = false,
                    .err = err_spawn_failed,
                    .outcome = outcome_spawn_failed,
                    .diagnostics_reason = diagnostics_spawn_failed,
                    .diagnostics_elapsed_ms = 0,
                    .diagnostics_signal = null,
                };
            };
            const el_u = clampJsonNs(now_u.since(t_start));
            return .{
                .attempt = 1,
                .elapsed_ns = el_u,
                .exit_code = null,
                .ok = false,
                .err = err_spawn_failed,
                .outcome = outcome_spawn_failed,
                .diagnostics_reason = diagnostics_spawn_failed,
                .diagnostics_elapsed_ms = elapsedNsToMs(el_u),
                .diagnostics_signal = null,
            };
        }

        const now_done = std.time.Instant.now() catch unreachable;
        const elapsed_final = clampJsonNs(now_done.since(t_start));
        const elapsed_final_ms = elapsedNsToMs(elapsed_final);
        const ustatus: u32 = @bitCast(status);
        if (posix.W.IFEXITED(ustatus)) {
            const ec = posix.W.EXITSTATUS(ustatus);
            if (ec == 0) {
                return .{
                    .attempt = 1,
                    .elapsed_ns = elapsed_final,
                    .exit_code = 0,
                    .ok = true,
                    .err = null,
                    .outcome = outcome_ok,
                    .diagnostics_reason = diagnostics_ok,
                    .diagnostics_elapsed_ms = elapsed_final_ms,
                    .diagnostics_signal = null,
                };
            }
            return .{
                .attempt = 1,
                .elapsed_ns = elapsed_final,
                .exit_code = ec,
                .ok = false,
                .err = null,
                .outcome = outcome_nonzero_exit,
                .diagnostics_reason = diagnostics_nonzero_exit,
                .diagnostics_elapsed_ms = elapsed_final_ms,
                .diagnostics_signal = null,
            };
        }
        if (posix.W.IFSIGNALED(ustatus)) {
            const sig = posix.W.TERMSIG(ustatus);
            return .{
                .attempt = 1,
                .elapsed_ns = elapsed_final,
                .exit_code = null,
                .ok = false,
                .err = null,
                .outcome = outcome_signaled,
                .diagnostics_reason = diagnostics_signaled,
                .diagnostics_elapsed_ms = elapsed_final_ms,
                .diagnostics_signal = sig,
            };
        }
        return .{
            .attempt = 1,
            .elapsed_ns = elapsed_final,
            .exit_code = null,
            .ok = false,
            .err = err_spawn_failed,
            .outcome = outcome_spawn_failed,
            .diagnostics_reason = diagnostics_spawn_failed,
            .diagnostics_elapsed_ms = elapsed_final_ms,
            .diagnostics_signal = null,
        };
    }
}

test "runBoundedShellCommand true exits 0 on Linux" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const t = runBoundedShellCommand(std.testing.allocator, "true", 5_000);
    try std.testing.expectEqual(@as(?u32, 1), t.attempt);
    try std.testing.expect(t.elapsed_ns != null);
    try std.testing.expectEqual(@as(?u32, 0), t.exit_code);
    try std.testing.expectEqual(@as(?bool, true), t.ok);
    try std.testing.expectEqual(@as(?[]const u8, null), t.err);
    try std.testing.expectEqualStrings(outcome_ok, t.outcome.?);
}

test "runBoundedArgvCommand bin true exits 0 on Linux" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const t = runBoundedArgvCommand(std.testing.allocator, &.{ "/bin/true" }, 5_000);
    try std.testing.expectEqual(@as(?u32, 1), t.attempt);
    try std.testing.expect(t.elapsed_ns != null);
    try std.testing.expectEqual(@as(?u32, 0), t.exit_code);
    try std.testing.expectEqual(@as(?bool, true), t.ok);
    try std.testing.expectEqualStrings(outcome_ok, t.outcome.?);
}

test "runBoundedShellCommand false exits 1 on Linux" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const t = runBoundedShellCommand(std.testing.allocator, "false", 5_000);
    try std.testing.expectEqual(@as(?u32, 1), t.attempt);
    try std.testing.expectEqual(@as(?u32, 1), t.exit_code);
    try std.testing.expectEqual(@as(?bool, false), t.ok);
    try std.testing.expectEqualStrings(outcome_nonzero_exit, t.outcome.?);
}

test "runBoundedShellCommand times out sleep on Linux" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const t = runBoundedShellCommand(std.testing.allocator, "sleep 30", 250);
    try std.testing.expectEqual(@as(?u32, 1), t.attempt);
    try std.testing.expectEqual(@as(?u32, null), t.exit_code);
    try std.testing.expectEqual(@as(?bool, false), t.ok);
    try std.testing.expectEqual(err_timeout, t.err.?);
    try std.testing.expectEqualStrings(outcome_timeout, t.outcome.?);
}

test "runBoundedShellCommand signaled when child dies by signal on Linux" {
    const builtin = @import("builtin");
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const t = runBoundedShellCommand(std.testing.allocator, "kill -9 $$", 5_000);
    try std.testing.expectEqual(@as(?u32, 1), t.attempt);
    try std.testing.expectEqual(@as(?u32, null), t.exit_code);
    try std.testing.expectEqual(@as(?bool, false), t.ok);
    try std.testing.expectEqual(@as(?[]const u8, null), t.err);
    try std.testing.expectEqualStrings(outcome_signaled, t.outcome.?);
}
