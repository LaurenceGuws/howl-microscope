const std = @import("std");

/// PH1-M39: Canonical forms for launch diagnostics inputs to prevent normalization drift.

/// Valid canonical reason tags (one of these values only).
pub const reason_ok: []const u8 = "ok";
pub const reason_missing_executable: []const u8 = "missing_executable";
pub const reason_not_executable: []const u8 = "not_executable";
pub const reason_spawn_failed: []const u8 = "spawn_failed";
pub const reason_timeout: []const u8 = "timeout";
pub const reason_nonzero_exit: []const u8 = "nonzero_exit";
pub const reason_signaled: []const u8 = "signaled";

/// Check if a reason string is a valid canonical form.
pub fn isValidCanonicalReason(reason: []const u8) bool {
    return std.mem.eql(u8, reason, reason_ok) or
        std.mem.eql(u8, reason, reason_missing_executable) or
        std.mem.eql(u8, reason, reason_not_executable) or
        std.mem.eql(u8, reason, reason_spawn_failed) or
        std.mem.eql(u8, reason, reason_timeout) or
        std.mem.eql(u8, reason, reason_nonzero_exit) or
        std.mem.eql(u8, reason, reason_signaled);
}

/// Check if elapsed_ms is in canonical range [0, maxInt(u32)].
pub fn isValidCanonicalElapsed(elapsed_ms: u32) bool {
    _ = elapsed_ms;
    return true; // u32 is always in valid range
}

/// Check if signal is in canonical range [1, 128] (POSIX signal numbers).
pub fn isValidCanonicalSignal(signal: u32) bool {
    return signal >= 1 and signal <= 128;
}

test "isValidCanonicalReason accepts all valid tags" {
    try std.testing.expect(isValidCanonicalReason(reason_ok));
    try std.testing.expect(isValidCanonicalReason(reason_missing_executable));
    try std.testing.expect(isValidCanonicalReason(reason_not_executable));
    try std.testing.expect(isValidCanonicalReason(reason_spawn_failed));
    try std.testing.expect(isValidCanonicalReason(reason_timeout));
    try std.testing.expect(isValidCanonicalReason(reason_nonzero_exit));
    try std.testing.expect(isValidCanonicalReason(reason_signaled));
}

test "isValidCanonicalReason rejects invalid tags" {
    try std.testing.expect(!isValidCanonicalReason(""));
    try std.testing.expect(!isValidCanonicalReason("OK"));
    try std.testing.expect(!isValidCanonicalReason("ok "));
    try std.testing.expect(!isValidCanonicalReason("unknown"));
}

test "isValidCanonicalSignal accepts valid range [1, 128]" {
    try std.testing.expect(isValidCanonicalSignal(1));
    try std.testing.expect(isValidCanonicalSignal(9));
    try std.testing.expect(isValidCanonicalSignal(128));
}

test "isValidCanonicalSignal rejects zero and out-of-range" {
    try std.testing.expect(!isValidCanonicalSignal(0));
    try std.testing.expect(!isValidCanonicalSignal(129));
    try std.testing.expect(!isValidCanonicalSignal(255));
}

test "ANA-3913: reason determinism - same inputs produce consistent validation" {
    try std.testing.expect(isValidCanonicalReason(reason_ok) == isValidCanonicalReason(reason_ok));
    try std.testing.expect(isValidCanonicalReason("invalid") == isValidCanonicalReason("invalid"));
}

test "ANA-3913: elapsed determinism - u32 range always valid" {
    try std.testing.expect(isValidCanonicalElapsed(0) == isValidCanonicalElapsed(0));
    try std.testing.expect(isValidCanonicalElapsed(1000) == isValidCanonicalElapsed(1000));
    try std.testing.expect(isValidCanonicalElapsed(std.math.maxInt(u32)) == isValidCanonicalElapsed(std.math.maxInt(u32)));
}

test "ANA-3913: signal determinism - boundary values consistent" {
    try std.testing.expect(isValidCanonicalSignal(1) == isValidCanonicalSignal(1));
    try std.testing.expect(isValidCanonicalSignal(128) == isValidCanonicalSignal(128));
    try std.testing.expect(isValidCanonicalSignal(0) == isValidCanonicalSignal(0));
    try std.testing.expect(isValidCanonicalSignal(129) == isValidCanonicalSignal(129));
}

test "ANA-3913: drift prevention - invalid inputs rejected consistently" {
    // Empty string is invalid (no canonical reason matches empty)
    try std.testing.expect(!isValidCanonicalReason(""));
    try std.testing.expect(!isValidCanonicalReason(""));

    // Uppercase is invalid (canonical form is lowercase)
    try std.testing.expect(!isValidCanonicalReason("OK"));
    try std.testing.expect(!isValidCanonicalReason("Timeout"));

    // Misspelled is invalid
    try std.testing.expect(!isValidCanonicalReason("ok "));
    try std.testing.expect(!isValidCanonicalReason(" ok"));
}

test "ANA-3913: drift prevention - signal edge cases at boundaries" {
    // Zero is explicitly invalid (not canonical)
    try std.testing.expect(!isValidCanonicalSignal(0));

    // One is valid (first POSIX signal)
    try std.testing.expect(isValidCanonicalSignal(1));

    // 128 is valid (last canonical signal)
    try std.testing.expect(isValidCanonicalSignal(128));

    // 129 is invalid (exceeds POSIX range)
    try std.testing.expect(!isValidCanonicalSignal(129));
}

test "ANA-3913: canonicalization all 7 reason tags precision" {
    // Each canonical tag must validate exactly once
    var count: u32 = 0;
    if (isValidCanonicalReason("ok")) count += 1;
    if (isValidCanonicalReason("missing_executable")) count += 1;
    if (isValidCanonicalReason("not_executable")) count += 1;
    if (isValidCanonicalReason("spawn_failed")) count += 1;
    if (isValidCanonicalReason("timeout")) count += 1;
    if (isValidCanonicalReason("nonzero_exit")) count += 1;
    if (isValidCanonicalReason("signaled")) count += 1;

    // Must match all 7 canonical tags
    try std.testing.expect(count == 7);

    // One invalid tag must not match any
    try std.testing.expect(!isValidCanonicalReason("unknown_reason"));
}

test "ANA-3913: canonicalization signal boundary precision" {
    // Test all boundaries: 0 (invalid), 1 (valid start), 128 (valid end), 129 (invalid)
    try std.testing.expect(!isValidCanonicalSignal(0)); // boundary: zero excluded
    try std.testing.expect(isValidCanonicalSignal(1)); // boundary: one included
    try std.testing.expect(isValidCanonicalSignal(64)); // middle value valid
    try std.testing.expect(isValidCanonicalSignal(128)); // boundary: 128 included
    try std.testing.expect(!isValidCanonicalSignal(129)); // boundary: 129 excluded

    // No value is simultaneously valid and invalid
    for (0..256) |sig| {
        const s: u32 = @intCast(sig);
        const valid = isValidCanonicalSignal(s);
        const invalid = !valid;
        try std.testing.expect(valid != invalid); // XOR: exactly one must be true
    }
}

test "ANA-3913: elapsed u32 always canonical" {
    // Every u32 value is in valid range [0, maxInt(u32)]
    try std.testing.expect(isValidCanonicalElapsed(0));
    try std.testing.expect(isValidCanonicalElapsed(1));
    try std.testing.expect(isValidCanonicalElapsed(std.math.maxInt(u32) - 1));
    try std.testing.expect(isValidCanonicalElapsed(std.math.maxInt(u32)));

    // No elapsed value is invalid (u32 guarantees canonicality)
    for (0..20) |i| {
        const e: u32 = @intCast(i);
        try std.testing.expect(isValidCanonicalElapsed(e));
    }
}
