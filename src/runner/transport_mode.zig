const std = @import("std");

/// Transport seam for a run (`docs/TRANSPORT_PLAN.md`). PH1-M5 uses stubs only.
pub const TransportMode = enum {
    none,
    /// Deterministic stub handshake only (no real PTY).
    pty_stub,
    /// Guarded real-transport scaffold; requires explicit opt-in (PH1-M6+).
    pty_guarded,

    pub fn tag(self: TransportMode) []const u8 {
        return switch (self) {
            .none => "none",
            .pty_stub => "pty_stub",
            .pty_guarded => "pty_guarded",
        };
    }

    pub fn parse(s: []const u8) ?TransportMode {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "pty_stub")) return .pty_stub;
        if (std.mem.eql(u8, s, "pty_guarded")) return .pty_guarded;
        return null;
    }
};
