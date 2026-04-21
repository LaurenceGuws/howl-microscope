const std = @import("std");

/// In-memory description of what will be executed for one spec (phase-1 stub).
pub const RunPlan = struct {
    spec_path: []const u8,
    spec_id: []const u8,
    capture_mode: []const u8,

    pub fn deinit(self: *RunPlan, allocator: std.mem.Allocator) void {
        allocator.free(self.spec_path);
        allocator.free(self.spec_id);
        allocator.free(self.capture_mode);
        self.* = undefined;
    }
};

pub fn buildPlan(
    allocator: std.mem.Allocator,
    spec_path: []const u8,
    spec_id: []const u8,
    capture_mode: []const u8,
) !RunPlan {
    return RunPlan{
        .spec_path = try allocator.dupe(u8, spec_path),
        .spec_id = try allocator.dupe(u8, spec_id),
        .capture_mode = try allocator.dupe(u8, capture_mode),
    };
}
