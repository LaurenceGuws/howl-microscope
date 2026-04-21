const std = @import("std");

/// Metadata describing how a terminal was (or would be) invoked for a run.
pub const TerminalInvocation = struct {
    /// argv0 or full command string (PH1-M2: single string; argv split deferred).
    command: []const u8,
    /// Additional argv after `command` when known.
    args: []const []const u8,
    /// Reported terminal version when available.
    version: []const u8,

    pub fn init(command: []const u8, args: []const []const u8, version: []const u8) TerminalInvocation {
        return .{
            .command = command,
            .args = args,
            .version = version,
        };
    }

    /// Placeholder until PTY launch records a real argv and `--version` scrape.
    pub fn placeholder() TerminalInvocation {
        return init("", &.{}, "");
    }
};

test "terminal invocation struct" {
    const t = TerminalInvocation.init("wezterm", &.{}, "");
    try std.testing.expectEqualStrings("wezterm", t.command);
}
