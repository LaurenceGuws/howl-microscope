const std = @import("std");
const errors = @import("../core/errors.zig");
const modes = @import("../capture/modes.zig");
const suite_manifest = @import("suite_manifest.zig");
const run_pipeline = @import("run_pipeline.zig");
const RunContext = @import("run_context.zig").RunContext;
const terminal_profile = @import("../runner/terminal_profile.zig");
const ExecutionMode = @import("../runner/execution_mode.zig").ExecutionMode;
const TransportMode = @import("../runner/transport_mode.zig").TransportMode;

pub fn execute(allocator: std.mem.Allocator, argv: []const []const u8) u8 {
    if (argv.len == 0) {
        printErr("usage: howl-microscope run-suite <name> [--capture <mode>] [--terminal <name>] ...\n") catch {};
        return errors.Category.unknown_command.exitCode();
    }

    const suite_name = argv[0];
    if (!std.mem.eql(u8, suite_name, "baseline-linux")) {
        printErr("unknown suite (only baseline-linux is defined)\n") catch {};
        return errors.Category.unknown_command.exitCode();
    }

    var ctx = RunContext.initDefault();
    ctx.suite_name = suite_name;

    var i: usize = 1;
    while (i < argv.len) {
        if (std.mem.eql(u8, argv[i], "--dry-run")) {
            ctx.dry_run = true;
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--strict")) {
            ctx.strict = true;
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--exec-mode")) {
            if (i + 1 >= argv.len) {
                printErr("--exec-mode requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            const em = ExecutionMode.parse(argv[i + 1]) orelse {
                printErr("invalid --exec-mode (use placeholder or protocol_stub)\n") catch {};
                return errors.Category.invalid_spec.exitCode();
            };
            ctx.execution_mode = em;
            i += 2;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--transport")) {
            if (i + 1 >= argv.len) {
                printErr("--transport requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            const tm = TransportMode.parse(argv[i + 1]) orelse {
                printErr("invalid --transport (use none, pty_stub, or pty_guarded)\n") catch {};
                return errors.Category.invalid_spec.exitCode();
            };
            ctx.transport_mode = tm;
            i += 2;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--allow-guarded-transport")) {
            ctx.allow_guarded_transport = true;
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--timeout-ms")) {
            if (i + 1 >= argv.len) {
                printErr("--timeout-ms requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            const n = std.fmt.parseUnsigned(u32, argv[i + 1], 10) catch {
                printErr("--timeout-ms must be a positive integer\n") catch {};
                return errors.Category.invalid_spec.exitCode();
            };
            if (n == 0) {
                printErr("--timeout-ms must be > 0\n") catch {};
                return errors.Category.invalid_spec.exitCode();
            }
            ctx.timeout_ms = n;
            i += 2;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--capture")) {
            if (i + 1 >= argv.len) {
                printErr("--capture requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            ctx.capture_mode = argv[i + 1];
            if (!modes.isKnown(ctx.capture_mode)) {
                printErr("invalid --capture mode\n") catch {};
                return errors.Category.invalid_spec.exitCode();
            }
            i += 2;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--terminal")) {
            if (i + 1 >= argv.len) {
                printErr("--terminal requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            ctx.terminal_name = argv[i + 1];
            i += 2;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--terminal-cmd")) {
            if (i + 1 >= argv.len) {
                printErr("--terminal-cmd requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            ctx.terminal_cmd_cli = argv[i + 1];
            i += 2;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--platform")) {
            if (i + 1 >= argv.len) {
                printErr("--platform requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            ctx.platform = argv[i + 1];
            i += 2;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--comparison-id")) {
            if (i + 1 >= argv.len) {
                printErr("--comparison-id requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            ctx.comparison_id = argv[i + 1];
            i += 2;
            continue;
        }
        if (std.mem.eql(u8, argv[i], "--run-group")) {
            if (i + 1 >= argv.len) {
                printErr("--run-group requires a value\n") catch {};
                return errors.Category.unknown_command.exitCode();
            }
            ctx.run_group = argv[i + 1];
            i += 2;
            continue;
        }
        if (argv[i].len > 0 and argv[i][0] == '-') {
            printErr("unknown flag\n") catch {};
            return errors.Category.unknown_command.exitCode();
        }
        printErr("unexpected positional argument\n") catch {};
        return errors.Category.unknown_command.exitCode();
    }

    const paths = suite_manifest.loadBaselineLinux(allocator) catch |err| {
        const msg: []const u8 = switch (err) {
            error.EmptyManifest => "suite manifest has no probe paths",
            error.DuplicateEntry => "suite manifest has a duplicate path",
            error.NonTomlEntry => "suite manifest entries must be .toml paths",
            error.MissingFile => "suite manifest references a missing file",
            else => "could not load suite manifest",
        };
        printErr(msg) catch {};
        const cat: errors.Category = switch (err) {
            error.EmptyManifest, error.DuplicateEntry, error.NonTomlEntry, error.MissingFile => .invalid_spec,
            else => .runtime_failure,
        };
        return cat.exitCode();
    };
    defer suite_manifest.freePathList(allocator, paths);

    terminal_profile.resolveEffective(&ctx);
    return run_pipeline.executeSpecPaths(allocator, paths, ctx);
}

fn printErr(msg: []const u8) !void {
    std.debug.print("{s}", .{msg});
}
