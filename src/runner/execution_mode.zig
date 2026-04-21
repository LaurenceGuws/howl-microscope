const std = @import("std");

/// How probe specs are executed for this run (`docs/PROTO_EXEC_PLAN.md`).
pub const ExecutionMode = enum {
    placeholder,
    protocol_stub,

    pub fn tag(self: ExecutionMode) []const u8 {
        return switch (self) {
            .placeholder => "placeholder",
            .protocol_stub => "protocol_stub",
        };
    }

    pub fn parse(s: []const u8) ?ExecutionMode {
        if (std.mem.eql(u8, s, "placeholder")) return .placeholder;
        if (std.mem.eql(u8, s, "protocol_stub")) return .protocol_stub;
        return null;
    }
};
