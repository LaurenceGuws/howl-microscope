const std = @import("std");
const RunPlan = @import("run_plan.zig").RunPlan;

/// Result row for one spec (phase-1 placeholder; no real terminal I/O).
pub const RunRecord = struct {
    spec_id: []const u8,
    status: []const u8,
    notes: []const u8,
    capture_mode: []const u8,
    /// JSON value for the `observations` object (e.g. `{}` or `{"protocol_stub":true,...}`).
    observations_json: []const u8,

    pub fn deinit(self: *RunRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.spec_id);
        allocator.free(self.status);
        allocator.free(self.notes);
        allocator.free(self.capture_mode);
        allocator.free(self.observations_json);
        self.* = undefined;
    }
};

pub fn executePlaceholder(allocator: std.mem.Allocator, plan: RunPlan) !RunRecord {
    var p = plan;
    defer p.deinit(allocator);
    return RunRecord{
        .spec_id = try allocator.dupe(u8, p.spec_id),
        .status = try allocator.dupe(u8, "manual"),
        .notes = try allocator.dupe(u8, "phase-1 scaffold — no PTY execution"),
        .capture_mode = try allocator.dupe(u8, p.capture_mode),
        .observations_json = try allocator.dupe(u8, "{}"),
    };
}
