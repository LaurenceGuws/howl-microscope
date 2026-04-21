const std = @import("std");
const RunPlan = @import("run_plan.zig").RunPlan;
const run_execute = @import("run_execute.zig");

/// FNV-1a 64-bit over `spec_id` for deterministic stub payloads (no I/O).
fn fnvSpecId(spec_id: []const u8) u64 {
    var h: u64 = 14695981039346656037;
    for (spec_id) |c| {
        h ^= c;
        h *%= 1099511628211;
    }
    return h;
}

/// Deterministic synthetic observations; does not touch a real terminal transport.
pub fn executeProtocolStub(allocator: std.mem.Allocator, plan: RunPlan) !run_execute.RunRecord {
    var p = plan;
    defer p.deinit(allocator);

    const h = fnvSpecId(p.spec_id);

    const spec_id = try allocator.dupe(u8, p.spec_id);
    errdefer allocator.free(spec_id);
    const status = try allocator.dupe(u8, "manual");
    errdefer allocator.free(status);
    const notes = try allocator.dupe(u8, "protocol_stub — deterministic seam (no PTY)");
    errdefer allocator.free(notes);
    const capture_mode = try allocator.dupe(u8, p.capture_mode);
    errdefer allocator.free(capture_mode);
    const obs = try std.fmt.allocPrint(allocator, "{{\"protocol_stub\":true,\"spec_fnv\":{d}}}", .{h});

    return run_execute.RunRecord{
        .spec_id = spec_id,
        .status = status,
        .notes = notes,
        .capture_mode = capture_mode,
        .observations_json = obs,
    };
}
