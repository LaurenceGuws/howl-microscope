//! Probe kind taxonomy (`docs/Vision.md`, `docs/DSL.md`).
const std = @import("std");

pub const vt_sequence: []const u8 = "vt_sequence";
pub const render_workload: []const u8 = "render_workload";
pub const input_probe: []const u8 = "input_probe";
pub const perf_probe: []const u8 = "perf_probe";

pub const all: []const []const u8 = &.{
    vt_sequence,
    render_workload,
    input_probe,
    perf_probe,
};

pub fn isKnown(kind: []const u8) bool {
    for (all) |k| {
        if (std.mem.eql(u8, kind, k)) return true;
    }
    return false;
}
