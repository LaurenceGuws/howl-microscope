const std = @import("std");
const TransportMode = @import("transport_mode.zig").TransportMode;

fn fnvRunId(run_id: []const u8) u64 {
    var h: u64 = 14695981039346656037;
    for (run_id) |c| {
        h ^= c;
        h *%= 1099511628211;
    }
    return h;
}

/// Deterministic latency that fits JSON i64 (report validator uses signed integers).
fn positiveLatencyNs(run_id: []const u8, salt: u64) u64 {
    const h = fnvRunId(run_id) ^ salt;
    const cap: u64 = @intCast(std.math.maxInt(i64));
    const v = h % cap;
    return if (v == 0) 1 else v;
}

/// Human-readable handshake token for stub transport (deterministic per mode).
pub fn handshakeString(mode: TransportMode) ?[]const u8 {
    return switch (mode) {
        .none => null,
        .pty_stub => "stub-handshake-v1",
        .pty_guarded => "guarded-handshake-v1",
    };
}

/// Synthetic handshake latency in nanoseconds (`0` for `none`; FNV of `run_id` for stub modes).
pub fn handshakeLatencyNs(mode: TransportMode, run_id: []const u8) u64 {
    return switch (mode) {
        .none => 0,
        .pty_stub => positiveLatencyNs(run_id, 0),
        .pty_guarded => positiveLatencyNs(run_id, 0x9e3779b97f4a7c15),
    };
}
