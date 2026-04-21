const std = @import("std");
const run_context_mod = @import("../cli/run_context.zig");
const RunContext = run_context_mod.RunContext;

pub const source_cli_override = "cli_override";
pub const source_profile = "profile";
pub const source_fallback = "fallback";

/// Recorded in `run.json` when a built-in executable template applies (PH1-M34).
pub const exec_template_version = "1";

pub const template_id_kitty_v1 = "kitty_exec_v1";
pub const template_id_ghostty_v1 = "ghostty_exec_v1";
pub const template_id_konsole_v1 = "konsole_exec_v1";
pub const template_id_zide_terminal_v1 = "zide_terminal_exec_v1";

/// Deterministic argv for direct exec (PH1-M34). `kitty --detach` returns quickly after forking the UI.
const argv_kitty = [_][]const u8{ "kitty", "--detach" };
const argv_ghostty = [_][]const u8{"ghostty"};
const argv_konsole = [_][]const u8{"konsole"};
const argv_zide = [_][]const u8{"zide-terminal"};

/// Built-in profile + executable template contract (PH1-M34).
pub const ProfileExecSpec = struct {
    profile_id: []const u8,
    template_id: []const u8,
    argv: []const []const u8,
};

const Profile = struct {
    id: []const u8,
    cmd: []const u8,
};

fn profileMatch(terminal_name: []const u8) ?Profile {
    if (terminal_name.len == 0) return null;
    if (std.ascii.eqlIgnoreCase(terminal_name, "kitty")) return .{ .id = "kitty", .cmd = "kitty" };
    if (std.ascii.eqlIgnoreCase(terminal_name, "ghostty")) return .{ .id = "ghostty", .cmd = "ghostty" };
    if (std.ascii.eqlIgnoreCase(terminal_name, "konsole")) return .{ .id = "konsole", .cmd = "konsole" };
    if (std.ascii.eqlIgnoreCase(terminal_name, "zide-terminal")) return .{ .id = "zide-terminal", .cmd = "zide-terminal" };
    return null;
}

/// Returns the PH1-M34 executable template for a known `--terminal` profile, if any.
pub fn profileExecSpec(terminal_name: []const u8) ?ProfileExecSpec {
    if (terminal_name.len == 0) return null;
    if (std.ascii.eqlIgnoreCase(terminal_name, "kitty")) {
        return .{ .profile_id = "kitty", .template_id = template_id_kitty_v1, .argv = &argv_kitty };
    }
    if (std.ascii.eqlIgnoreCase(terminal_name, "ghostty")) {
        return .{ .profile_id = "ghostty", .template_id = template_id_ghostty_v1, .argv = &argv_ghostty };
    }
    if (std.ascii.eqlIgnoreCase(terminal_name, "konsole")) {
        return .{ .profile_id = "konsole", .template_id = template_id_konsole_v1, .argv = &argv_konsole };
    }
    if (std.ascii.eqlIgnoreCase(terminal_name, "zide-terminal")) {
        return .{ .profile_id = "zide-terminal", .template_id = template_id_zide_terminal_v1, .argv = &argv_zide };
    }
    return null;
}

fn copyId(ctx: *RunContext, id: []const u8) void {
    const n = @min(id.len, run_context_mod.terminal_profile_id_cap);
    @memcpy(ctx.terminal_profile_id_buf[0..n], id[0..n]);
    ctx.terminal_profile_id_len = @intCast(n);
}

fn clearTemplateMeta(ctx: *RunContext) void {
    ctx.terminal_exec_template_id_len = 0;
    ctx.terminal_exec_template_version_len = 0;
}

fn copyTemplateMeta(ctx: *RunContext, template_id: []const u8, version: []const u8) void {
    clearTemplateMeta(ctx);
    const ni = @min(template_id.len, run_context_mod.terminal_exec_template_id_cap);
    @memcpy(ctx.terminal_exec_template_id_buf[0..ni], template_id[0..ni]);
    ctx.terminal_exec_template_id_len = @intCast(ni);
    const nv = @min(version.len, ctx.terminal_exec_template_version_buf.len);
    @memcpy(ctx.terminal_exec_template_version_buf[0..nv], version[0..nv]);
    ctx.terminal_exec_template_version_len = @intCast(nv);
}

fn clearArgv(ctx: *RunContext) void {
    ctx.terminal_exec_argc = 0;
    @memset(std.mem.sliceAsBytes(ctx.terminal_exec_argv_lens[0..]), 0);
}

fn forceSingleArgFromSlice(ctx: *RunContext, arg: []const u8) void {
    clearArgv(ctx);
    const n = @min(arg.len, run_context_mod.terminal_exec_arg_max);
    if (n == 0) return;
    @memcpy(ctx.terminal_exec_argv_flat[0][0..n], arg[0..n]);
    ctx.terminal_exec_argv_lens[0] = @intCast(n);
    ctx.terminal_exec_argc = 1;
}

fn copyArgvFromSpec(ctx: *RunContext, args: []const []const u8) bool {
    if (args.len > run_context_mod.terminal_exec_argc_max) return false;
    clearArgv(ctx);
    for (args, 0..) |a, i_usize| {
        const i: u8 = @intCast(i_usize);
        if (a.len > run_context_mod.terminal_exec_arg_max) return false;
        @memcpy(ctx.terminal_exec_argv_flat[i][0..a.len], a);
        ctx.terminal_exec_argv_lens[i] = @intCast(a.len);
    }
    ctx.terminal_exec_argc = @intCast(args.len);
    return true;
}

/// Splits `terminal_cmd_cli` on ASCII whitespace into argv slots; on overflow uses a single token copy.
fn materializeCliArgv(ctx: *RunContext) void {
    clearArgv(ctx);
    const s = ctx.terminal_cmd_cli;
    var slot: usize = 0;
    var j: usize = 0;
    while (j < s.len) : (j += 1) {
        while (j < s.len and std.ascii.isWhitespace(s[j])) j += 1;
        if (j >= s.len) break;
        const st = j;
        while (j < s.len and !std.ascii.isWhitespace(s[j])) j += 1;
        const tok = s[st..j];
        if (tok.len == 0) continue;
        if (slot >= run_context_mod.terminal_exec_argc_max or tok.len > run_context_mod.terminal_exec_arg_max) {
            forceSingleArgFromSlice(ctx, s);
            return;
        }
        @memcpy(ctx.terminal_exec_argv_flat[slot][0..tok.len], tok);
        ctx.terminal_exec_argv_lens[slot] = @intCast(tok.len);
        slot += 1;
    }
    if (slot == 0 and s.len > 0) {
        forceSingleArgFromSlice(ctx, s);
    } else {
        ctx.terminal_exec_argc = @intCast(slot);
    }
}

fn joinArgvIntoCmdBuffer(ctx: *RunContext) void {
    if (ctx.terminal_exec_argc == 0) {
        ctx.terminal_cmd_effective_len = 0;
        ctx.terminal_cmd = "";
        return;
    }
    var pos: usize = 0;
    var i: usize = 0;
    while (i < @as(usize, ctx.terminal_exec_argc)) : (i += 1) {
        if (i > 0) {
            if (pos >= run_context_mod.terminal_cmd_storage_cap) break;
            ctx.terminal_cmd_effective_buf[pos] = ' ';
            pos += 1;
        }
        const len = ctx.terminal_exec_argv_lens[i];
        const take = @min(len, run_context_mod.terminal_cmd_storage_cap - pos);
        @memcpy(ctx.terminal_cmd_effective_buf[pos..][0..take], ctx.terminal_exec_argv_flat[i][0..take]);
        pos += take;
    }
    ctx.terminal_cmd_effective_len = @intCast(pos);
    ctx.terminal_cmd = ctx.terminal_cmd_effective_buf[0..pos];
}

/// Fills `terminal_cmd` (space-joined argv), argv slots, template metadata, `terminal_cmd_source`, and profile id buffers (PH1-M33 + PH1-M34).
/// Call after CLI parse (`terminal_cmd_cli` set from `--terminal-cmd` when present).
pub fn resolveEffective(ctx: *RunContext) void {
    ctx.terminal_profile_id_len = 0;
    ctx.terminal_cmd_effective_len = 0;
    clearArgv(ctx);
    clearTemplateMeta(ctx);

    if (ctx.terminal_cmd_cli.len > 0) {
        materializeCliArgv(ctx);
        joinArgvIntoCmdBuffer(ctx);
        ctx.terminal_cmd_source = source_cli_override;
        if (profileMatch(ctx.terminal_name)) |p| {
            copyId(ctx, p.id);
        }
        return;
    }

    if (profileExecSpec(ctx.terminal_name)) |spec| {
        if (!copyArgvFromSpec(ctx, spec.argv)) {
            if (profileMatch(ctx.terminal_name)) |legacy| {
                forceSingleArgFromSlice(ctx, legacy.cmd);
                joinArgvIntoCmdBuffer(ctx);
                ctx.terminal_cmd_source = source_profile;
                copyId(ctx, legacy.id);
            }
            return;
        }
        copyTemplateMeta(ctx, spec.template_id, exec_template_version);
        joinArgvIntoCmdBuffer(ctx);
        ctx.terminal_cmd_source = source_profile;
        copyId(ctx, spec.profile_id);
        return;
    }

    forceSingleArgFromSlice(ctx, ctx.terminal_name);
    joinArgvIntoCmdBuffer(ctx);
    ctx.terminal_cmd_source = source_fallback;
}

pub fn profileIdSlice(ctx: *const RunContext) []const u8 {
    return ctx.terminal_profile_id_buf[0..ctx.terminal_profile_id_len];
}

test "resolve cli_override uses argv and optional profile id" {
    var ctx = RunContext.initDefault();
    ctx.terminal_name = "kitty";
    ctx.terminal_cmd_cli = "custom -e sh";
    resolveEffective(&ctx);
    try std.testing.expectEqualStrings("custom -e sh", ctx.terminal_cmd);
    try std.testing.expectEqualStrings(source_cli_override, ctx.terminal_cmd_source);
    try std.testing.expectEqualStrings("kitty", profileIdSlice(&ctx));
}

test "resolve profile for kitty" {
    var ctx = RunContext.initDefault();
    ctx.terminal_name = "KiTTY";
    resolveEffective(&ctx);
    try std.testing.expectEqualStrings("kitty --detach", ctx.terminal_cmd);
    try std.testing.expectEqualStrings(source_profile, ctx.terminal_cmd_source);
    try std.testing.expectEqualStrings("kitty", profileIdSlice(&ctx));
    try std.testing.expectEqual(@as(u8, 2), ctx.terminal_exec_argc);
    try std.testing.expectEqualStrings(template_id_kitty_v1, ctx.terminal_exec_template_id_buf[0..ctx.terminal_exec_template_id_len]);
    try std.testing.expectEqualStrings(exec_template_version, ctx.terminal_exec_template_version_buf[0..ctx.terminal_exec_template_version_len]);
}

test "resolve profile for ghostty" {
    var ctx = RunContext.initDefault();
    ctx.terminal_name = "GhOsTTY";
    resolveEffective(&ctx);
    try std.testing.expectEqualStrings("ghostty", ctx.terminal_cmd);
    try std.testing.expectEqualStrings(source_profile, ctx.terminal_cmd_source);
    try std.testing.expectEqualStrings("ghostty", profileIdSlice(&ctx));
    try std.testing.expectEqual(@as(u8, 1), ctx.terminal_exec_argc);
    try std.testing.expectEqualStrings(template_id_ghostty_v1, ctx.terminal_exec_template_id_buf[0..ctx.terminal_exec_template_id_len]);
    try std.testing.expectEqualStrings(exec_template_version, ctx.terminal_exec_template_version_buf[0..ctx.terminal_exec_template_version_len]);
}

test "resolve profile for konsole" {
    var ctx = RunContext.initDefault();
    ctx.terminal_name = "KONsole";
    resolveEffective(&ctx);
    try std.testing.expectEqualStrings("konsole", ctx.terminal_cmd);
    try std.testing.expectEqualStrings(source_profile, ctx.terminal_cmd_source);
    try std.testing.expectEqualStrings("konsole", profileIdSlice(&ctx));
    try std.testing.expectEqual(@as(u8, 1), ctx.terminal_exec_argc);
    try std.testing.expectEqualStrings(template_id_konsole_v1, ctx.terminal_exec_template_id_buf[0..ctx.terminal_exec_template_id_len]);
    try std.testing.expectEqualStrings(exec_template_version, ctx.terminal_exec_template_version_buf[0..ctx.terminal_exec_template_version_len]);
}

test "resolve profile for zide-terminal" {
    var ctx = RunContext.initDefault();
    ctx.terminal_name = "ZIDE-TERMINAL";
    resolveEffective(&ctx);
    try std.testing.expectEqualStrings("zide-terminal", ctx.terminal_cmd);
    try std.testing.expectEqualStrings(source_profile, ctx.terminal_cmd_source);
    try std.testing.expectEqualStrings("zide-terminal", profileIdSlice(&ctx));
}

test "resolve cli_override with unknown terminal leaves profile id empty" {
    var ctx = RunContext.initDefault();
    ctx.terminal_name = "foot";
    ctx.terminal_cmd_cli = "my-term -e sh";
    resolveEffective(&ctx);
    try std.testing.expectEqualStrings("my-term -e sh", ctx.terminal_cmd);
    try std.testing.expectEqualStrings(source_cli_override, ctx.terminal_cmd_source);
    try std.testing.expectEqual(@as(u8, 0), ctx.terminal_profile_id_len);
}

test "resolve fallback uses terminal name" {
    var ctx = RunContext.initDefault();
    ctx.terminal_name = "alacritty";
    resolveEffective(&ctx);
    try std.testing.expectEqualStrings("alacritty", ctx.terminal_cmd);
    try std.testing.expectEqualStrings(source_fallback, ctx.terminal_cmd_source);
    try std.testing.expectEqual(@as(u8, 0), ctx.terminal_profile_id_len);
    try std.testing.expectEqual(@as(u8, 1), ctx.terminal_exec_argc);
    try std.testing.expectEqual(@as(u8, 0), ctx.terminal_exec_template_id_len);
}

test "profileExecSpec kitty uses detach argv" {
    const s = profileExecSpec("KiTTY").?;
    try std.testing.expectEqualStrings("kitty", s.profile_id);
    try std.testing.expectEqualStrings(template_id_kitty_v1, s.template_id);
    try std.testing.expectEqual(@as(usize, 2), s.argv.len);
    try std.testing.expectEqualStrings("kitty", s.argv[0]);
    try std.testing.expectEqualStrings("--detach", s.argv[1]);
}

test "profileExecSpec unknown is null" {
    try std.testing.expectEqual(@as(?ProfileExecSpec, null), profileExecSpec("foot"));
}
