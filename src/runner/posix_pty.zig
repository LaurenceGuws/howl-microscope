//! Minimal Linux PTY pair: open master (`/dev/ptmx`), `grantpt` / `unlockpt`, open slave, then caller closes both.
//! No interactive I/O. See `docs/PTY_EXPERIMENT_PLAN.md`.

const std = @import("std");

extern "c" fn grantpt(fd: std.posix.fd_t) i32;
extern "c" fn unlockpt(fd: std.posix.fd_t) i32;
extern "c" fn ptsname_r(fd: std.posix.fd_t, buf: [*]u8, buflen: usize) i32;

pub const OpenError = error{
    UnsupportedHost,
    OpenPtmx,
    GrantPt,
    UnlockPt,
    PtsName,
    OpenSlave,
};

pub const PtyPair = struct {
    master: std.posix.fd_t,
    slave: std.posix.fd_t,

    pub fn deinit(self: *PtyPair) void {
        std.posix.close(self.slave);
        std.posix.close(self.master);
        self.* = undefined;
    }
};

/// Uses `uname` so behavior matches host OS (not only compile target metadata).
pub fn runtimeHostIsLinux() bool {
    const u = std.posix.uname();
    const sys = std.mem.sliceTo(&u.sysname, 0);
    return std.mem.eql(u8, sys, "Linux");
}

pub fn openErrorTag(err: OpenError) []const u8 {
    return switch (err) {
        error.UnsupportedHost => "unsupported_host",
        error.OpenPtmx => "open_ptmx",
        error.GrantPt => "grantpt",
        error.UnlockPt => "unlockpt",
        error.PtsName => "ptsname_r",
        error.OpenSlave => "open_slave",
    };
}

pub fn openMinimal() OpenError!PtyPair {
    if (!runtimeHostIsLinux()) return error.UnsupportedHost;

    const master = std.posix.openZ("/dev/ptmx", .{ .ACCMODE = .RDWR }, 0) catch return error.OpenPtmx;
    errdefer std.posix.close(master);

    if (grantpt(master) != 0) return error.GrantPt;
    if (unlockpt(master) != 0) return error.UnlockPt;

    var buf: [4096]u8 = undefined;
    if (ptsname_r(master, &buf, buf.len) != 0) return error.PtsName;
    const slave_path = std.mem.sliceTo(&buf, 0);

    const slave = std.posix.open(slave_path, .{ .ACCMODE = .RDWR }, 0) catch return error.OpenSlave;

    return .{
        .master = master,
        .slave = slave,
    };
}

test "openMinimal Linux closes cleanly" {
    if (!runtimeHostIsLinux()) return error.SkipZigTest;
    var p = try openMinimal();
    defer p.deinit();
}

test "openErrorTag maps OpenError to stable strings" {
    try std.testing.expectEqualStrings("unsupported_host", openErrorTag(error.UnsupportedHost));
    try std.testing.expectEqualStrings("open_ptmx", openErrorTag(error.OpenPtmx));
    try std.testing.expectEqualStrings("grantpt", openErrorTag(error.GrantPt));
    try std.testing.expectEqualStrings("unlockpt", openErrorTag(error.UnlockPt));
    try std.testing.expectEqualStrings("ptsname_r", openErrorTag(error.PtsName));
    try std.testing.expectEqualStrings("open_slave", openErrorTag(error.OpenSlave));
}
