const std = @import("std");
const errors = @import("../core/errors.zig");
const discovery = @import("../dsl/discovery.zig");
const modes = @import("../capture/modes.zig");
const run_pipeline = @import("run_pipeline.zig");
const RunContext = @import("run_context.zig").RunContext;
const terminal_profile = @import("../runner/terminal_profile.zig");
const ExecutionMode = @import("../runner/execution_mode.zig").ExecutionMode;
const TransportMode = @import("../runner/transport_mode.zig").TransportMode;

pub fn execute(allocator: std.mem.Allocator, argv: []const []const u8) u8 {
    var ctx = RunContext.initDefault();
    var roots = std.ArrayList([]const u8).empty;
    defer roots.deinit(allocator);

    var i: usize = 0;
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
        roots.append(allocator, argv[i]) catch return errors.Category.runtime_failure.exitCode();
        i += 1;
    }

    const roots_slice: []const []const u8 = if (roots.items.len == 0) &[_][]const u8{"probes/smoke"} else roots.items;

    const spec_paths = discovery.discover(allocator, roots_slice) catch return errors.Category.runtime_failure.exitCode();
    defer discovery.freePaths(allocator, spec_paths);

    terminal_profile.resolveEffective(&ctx);
    return run_pipeline.executeSpecPaths(allocator, spec_paths, ctx);
}

fn printErr(msg: []const u8) !void {
    var buf: [256]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    try w.interface.print("{s}", .{msg});
    try w.interface.flush();
}
