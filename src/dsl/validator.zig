const std = @import("std");
const categories = @import("../probes/categories.zig");

pub const Violation = struct {
    path: []const u8,
    field: []const u8,
    message: []const u8,
};

/// Phase-1 structural validation (line-oriented; seed specs are simple).
pub fn validate(path: []const u8, text: []const u8) ?Violation {
    if (!hasTopLevelKey(text, "id")) {
        return .{ .path = path, .field = "id", .message = "missing required string key `id`" };
    }
    if (!hasTopLevelKey(text, "kind")) {
        return .{ .path = path, .field = "kind", .message = "missing required string key `kind`" };
    }
    if (!hasTopLevelKey(text, "title")) {
        return .{ .path = path, .field = "title", .message = "missing required string key `title`" };
    }
    if (std.mem.indexOf(u8, text, "[[steps]]") == null) {
        return .{ .path = path, .field = "steps", .message = "need at least one `[[steps]]` table" };
    }
    if (!stepsContainWrite(text)) {
        return .{ .path = path, .field = "steps", .message = "each step must include a `write` assignment (phase-1)" };
    }
    const kind = extractStringField(text, "kind") orelse {
        return .{ .path = path, .field = "kind", .message = "could not parse `kind` string value" };
    };
    if (!categories.isKnown(kind)) {
        return .{ .path = path, .field = "kind", .message = "unknown probe kind for phase-1" };
    }
    return null;
}

fn hasTopLevelKey(text: []const u8, key: []const u8) bool {
    var iter = std.mem.splitScalar(u8, text, '\n');
    while (iter.next()) |raw| {
        const line = trimEnd(raw);
        if (line.len == 0) continue;
        if (line[0] == '#' or line[0] == ';') continue;
        if (line[0] == '[') {
            if (std.mem.startsWith(u8, line, "[[")) break;
            continue;
        }
        if (keyAssignment(line, key)) return true;
    }
    return false;
}

fn keyAssignment(line: []const u8, key: []const u8) bool {
    if (!std.mem.startsWith(u8, line, key)) return false;
    const rest = line[key.len..];
    const t = std.mem.trimStart(u8, rest, " \t");
    return t.len != 0 and t[0] == '=';
}

fn stepsContainWrite(text: []const u8) bool {
    const start = std.mem.indexOf(u8, text, "[[steps]]") orelse return false;
    const after = text[start..];
    return std.mem.indexOf(u8, after, "write") != null and
        (std.mem.indexOf(u8, after, "write =") != null or std.mem.indexOf(u8, after, "write=") != null);
}

pub fn extractId(text: []const u8) ?[]const u8 {
    return extractStringField(text, "id");
}

fn extractStringField(text: []const u8, key: []const u8) ?[]const u8 {
    var iter = std.mem.splitScalar(u8, text, '\n');
    while (iter.next()) |raw| {
        const line = trimEnd(raw);
        if (line.len == 0 or line[0] == '#' or line[0] == ';') continue;
        if (line[0] == '[') continue;
        if (!keyAssignment(line, key)) continue;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const rhs = std.mem.trim(u8, line[eq + 1 ..], " \t");
        if (rhs.len < 2) return null;
        const q = rhs[0];
        if (q != '"' and q != '\'') return null;
        const end = std.mem.lastIndexOfScalar(u8, rhs, q) orelse return null;
        if (end <= 0) return null;
        return rhs[1..end];
    }
    return null;
}

fn trimEnd(s: []const u8) []const u8 {
    return std.mem.trimEnd(u8, std.mem.trimStart(u8, s, " \t\r"), " \t\r");
}
