//! Minimal Linux PTY pair: open master (`/dev/ptmx`), `grantpt` / `unlockpt`, open slave, then caller closes both.
//! No interactive I/O. See `docs/PTY_EXPERIMENT_PLAN.md`.

const std = @import("std");
const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("fcntl.h");
    @cInclude("sys/utsname.h");
});

extern "c" fn grantpt(fd: c_int) c_int;
extern "c" fn unlockpt(fd: c_int) c_int;
extern "c" fn ptsname_r(fd: c_int, buf: [*]u8, buflen: usize) c_int;

pub const OpenError = error{
    UnsupportedHost,
    OpenPtmx,
    GrantPt,
    UnlockPt,
    PtsName,
    OpenSlave,
};

pub const PtyPair = struct {
    master: c_int,
    slave: c_int,

    pub fn deinit(self: *PtyPair) void {
        _ = c.close(self.slave);
        _ = c.close(self.master);
        self.* = undefined;
    }
};

/// Uses `uname` so behavior matches host OS (not only compile target metadata).
pub fn runtimeHostIsLinux() bool {
    var u: c.struct_utsname = undefined;
    if (c.uname(&u) != 0) return false;
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

    const master = c.open("/dev/ptmx", c.O_RDWR, @as(c_int, 0));
    if (master < 0) return error.OpenPtmx;
    errdefer _ = c.close(master);

    if (grantpt(master) != 0) return error.GrantPt;
    if (unlockpt(master) != 0) return error.UnlockPt;

    var buf: [4096]u8 = undefined;
    if (ptsname_r(master, &buf, buf.len) != 0) return error.PtsName;
    const slave_path = std.mem.sliceTo(&buf, 0);

    var path_buf: [4096]u8 = undefined;
    if (slave_path.len + 1 > path_buf.len) return error.OpenSlave;
    @memcpy(path_buf[0..slave_path.len], slave_path);
    path_buf[slave_path.len] = 0;
    const slave = c.open(&path_buf, c.O_RDWR, @as(c_int, 0));
    if (slave < 0) return error.OpenSlave;

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
