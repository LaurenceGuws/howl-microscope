//! Capture modes (`docs/Vision.md`).
const std = @import("std");

pub const manual: []const u8 = "manual";
pub const text_observation: []const u8 = "text_observation";
pub const timed: []const u8 = "timed";

pub const all: []const []const u8 = &.{
    manual,
    text_observation,
    timed,
};

pub fn isKnown(mode: []const u8) bool {
    for (all) |m| {
        if (std.mem.eql(u8, mode, m)) return true;
    }
    return false;
}

pub fn defaultMode() []const u8 {
    return manual;
}
