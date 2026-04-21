const std = @import("std");
const TransportMode = @import("transport_mode.zig").TransportMode;
const posix_pty = @import("posix_pty.zig");

pub fn envValueAllowsGuarded(value: ?[]const u8) bool {
    const v = value orelse return false;
    return std.mem.eql(u8, v, "1");
}

pub fn envAllowsGuarded() bool {
    return envValueAllowsGuarded(std.posix.getenv("ANA_TERM_ALLOW_GUARDED_TRANSPORT"));
}

pub fn optInAllowsGuarded(allow_flag: bool) bool {
    return allow_flag or envAllowsGuarded();
}

/// When non-null, stderr message; caller should exit with invalid-spec category.
pub fn preflightMessage(mode: TransportMode, allow_guarded_transport: bool, dry_run: bool) ?[]const u8 {
    if (mode != .pty_guarded) return null;
    if (!optInAllowsGuarded(allow_guarded_transport)) {
        return "pty_guarded requires --allow-guarded-transport or ANA_TERM_ALLOW_GUARDED_TRANSPORT=1";
    }
    if (!dry_run and !posix_pty.runtimeHostIsLinux()) {
        return "pty_guarded experiment requires a Linux host (see docs/PTY_EXPERIMENT_PLAN.md)";
    }
    return null;
}

test "preflightMessage allows pty_guarded with flag" {
    try std.testing.expect(preflightMessage(.pty_guarded, true, true) == null);
    if (posix_pty.runtimeHostIsLinux()) {
        try std.testing.expect(preflightMessage(.pty_guarded, true, false) == null);
    }
}

test "preflightMessage skips non guarded modes" {
    try std.testing.expect(preflightMessage(.none, false, false) == null);
    try std.testing.expect(preflightMessage(.pty_stub, false, false) == null);
}

test "preflightMessage rejects pty_guarded full run on non-linux host" {
    if (posix_pty.runtimeHostIsLinux()) return error.SkipZigTest;
    try std.testing.expect(preflightMessage(.pty_guarded, true, false) != null);
}

test "preflightMessage allows pty_guarded full run on linux" {
    if (!posix_pty.runtimeHostIsLinux()) return error.SkipZigTest;
    try std.testing.expect(preflightMessage(.pty_guarded, true, false) == null);
}

test "envValueAllowsGuarded" {
    try std.testing.expect(!envValueAllowsGuarded(null));
    try std.testing.expect(envValueAllowsGuarded("1"));
    try std.testing.expect(!envValueAllowsGuarded("0"));
    try std.testing.expect(!envValueAllowsGuarded(""));
}
