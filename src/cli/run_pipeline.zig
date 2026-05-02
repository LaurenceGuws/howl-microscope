const std = @import("std");
const compat_io = @import("../compat_io.zig");
const errors = @import("../core/errors.zig");
const loader = @import("../dsl/loader.zig");
const validator = @import("../dsl/validator.zig");
const run_plan_mod = @import("../runner/run_plan.zig");
const run_execute = @import("../runner/run_execute.zig");
const protocol_stub = @import("../runner/protocol_stub.zig");
const TerminalInvocation = @import("../runner/terminal_invocation.zig").TerminalInvocation;
const artifact_paths = @import("../report/artifact_paths.zig");
const json_writer = @import("../report/json_writer.zig");
const run_fingerprint = @import("../report/run_fingerprint.zig");
const specset_fingerprint = @import("../report/specset_fingerprint.zig");
const resultset_fingerprint = @import("../report/resultset_fingerprint.zig");
const transport_fingerprint = @import("../report/transport_fingerprint.zig");
const launch_diagnostics_fingerprint = @import("../report/launch_diagnostics_fingerprint.zig");
const exec_summary_fingerprint = @import("../report/exec_summary_fingerprint.zig");
const context_summary_fingerprint = @import("../report/context_summary_fingerprint.zig");
const metadata_envelope_fingerprint = @import("../report/metadata_envelope_fingerprint.zig");
const artifact_bundle_fingerprint = @import("../report/artifact_bundle_fingerprint.zig");
const report_envelope_fingerprint = @import("../report/report_envelope_fingerprint.zig");
const compare_envelope_fingerprint = @import("../report/compare_envelope_fingerprint.zig");
const run_envelope_fingerprint = @import("../report/run_envelope_fingerprint.zig");
const session_envelope_fingerprint = @import("../report/session_envelope_fingerprint.zig");
const environment_envelope_fingerprint = @import("../report/environment_envelope_fingerprint.zig");
const artifact_manifest_fingerprint = @import("../report/artifact_manifest_fingerprint.zig");
const provenance_envelope_fingerprint = @import("../report/provenance_envelope_fingerprint.zig");
const integrity_envelope_fingerprint = @import("../report/integrity_envelope_fingerprint.zig");
const consistency_envelope_fingerprint = @import("../report/consistency_envelope_fingerprint.zig");
const trace_envelope_fingerprint = @import("../report/trace_envelope_fingerprint.zig");
const lineage_envelope_fingerprint = @import("../report/lineage_envelope_fingerprint.zig");
const state_envelope_fingerprint = @import("../report/state_envelope_fingerprint.zig");
const markdown_writer = @import("../report/markdown_writer.zig");
const env_writer = @import("../report/env_writer.zig");
const run_context_mod = @import("run_context.zig");
const RunContext = run_context_mod.RunContext;
const transport_guard_preflight = @import("../runner/transport_guard_preflight.zig");
const posix_pty = @import("../runner/posix_pty.zig");
const real_terminal_launch = @import("../runner/real_terminal_launch.zig");
const launch_preflight = @import("../runner/launch_preflight.zig");

pub fn executeSpecPaths(allocator: std.mem.Allocator, spec_paths: []const []const u8, ctx_in: RunContext) u8 {
    var ctx = ctx_in;
    var launch_preflight_failed: bool = false;
    if (spec_paths.len == 0) {
        printErr("no probe specs to run\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    }

    if (transport_guard_preflight.preflightMessage(ctx.transport_mode, ctx.allow_guarded_transport, ctx.dry_run)) |msg| {
        printErr(msg) catch {};
        printErr("\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    }

    if (ctx.transport_mode == .pty_guarded and !ctx.dry_run and posix_pty.runtimeHostIsLinux() and ctx.terminal_exec_argc == 0) {
        printErr("pty_guarded full run on Linux requires a non-empty resolved terminal argv (--terminal-cmd and/or a PH1-M33/PH1-M34 profile; see docs/CLI.md)\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    }

    var records = std.ArrayList(run_execute.RunRecord).empty;
    defer {
        for (records.items) |*r| r.deinit(allocator);
        records.deinit(allocator);
    }

    for (spec_paths) |path| {
        var raw = loader.loadFile(allocator, path) catch return errors.Category.runtime_failure.exitCode();
        defer raw.deinit(allocator);

        if (validator.validate(path, raw.text)) |v| {
            printViolation(v) catch {};
            return errors.Category.invalid_spec.exitCode();
        }
        const sid = validator.extractId(raw.text) orelse {
            printErr("could not parse `id` string\n") catch {};
            return errors.Category.invalid_spec.exitCode();
        };

        const plan = run_plan_mod.buildPlan(allocator, path, sid, ctx.capture_mode) catch return errors.Category.runtime_failure.exitCode();
        const rec = switch (ctx.execution_mode) {
            .placeholder => run_execute.executePlaceholder(allocator, plan) catch return errors.Category.runtime_failure.exitCode(),
            .protocol_stub => protocol_stub.executeProtocolStub(allocator, plan) catch return errors.Category.runtime_failure.exitCode(),
        };
        records.append(allocator, rec) catch return errors.Category.runtime_failure.exitCode();
    }

    if (ctx.transport_mode == .pty_guarded and !ctx.dry_run) {
        ctx.capturePtyHostSnapshot();
        ctx.pty_capability_notes = "linux /dev/ptmx grantpt unlockpt ptsname_r slave open";
        ctx.pty_experiment_attempt = 1;
        blk: {
            var pair = posix_pty.openMinimal() catch |err| {
                ctx.pty_experiment_open_ok = false;
                ctx.pty_experiment_error = posix_pty.openErrorTag(err);
                break :blk;
            };
            defer pair.deinit();
            ctx.pty_experiment_open_ok = true;
            ctx.pty_experiment_error = null;
        }
        ctx.pty_experiment_elapsed_ns = 0;

        if (posix_pty.runtimeHostIsLinux() and ctx.terminal_exec_argc > 0) {
            var launch_argv: [run_context_mod.terminal_exec_argc_max][]const u8 = undefined;
            const na = @as(usize, ctx.terminal_exec_argc);
            for (0..na) |k| {
                launch_argv[k] = ctx.terminal_exec_argv_flat[k][0..ctx.terminal_exec_argv_lens[k]];
            }
            const probe = launch_preflight.probeArgv0ExecutableLinux(launch_argv[0]);
            launch_preflight.applyProbeToContext(&ctx, &probe);
            // PH1-M36: fail-closed for any unsuccessful probe on the guarded argv path (reason fidelity).
            const block_launch = !probe.ok;
            if (block_launch) {
                launch_preflight_failed = true;
                // PH1-M37: populate diagnostics envelope for preflight failure.
                if (probe.reason.len > 0) {
                    const n = @min(probe.reason.len, run_context_mod.terminal_launch_diagnostics_reason_cap);
                    @memcpy(ctx.terminal_launch_diagnostics_reason_buf[0..n], probe.reason[0..n]);
                    ctx.terminal_launch_diagnostics_reason_len = @intCast(n);
                }
                ctx.terminal_launch_diagnostics_elapsed_ms = 0;
                ctx.terminal_launch_diagnostics_signal = null;
            } else if (probe.ok) {
                const telem = real_terminal_launch.runBoundedArgvCommand(allocator, launch_argv[0..na], ctx.timeout_ms);
                ctx.terminal_launch_attempt = telem.attempt;
                ctx.terminal_launch_elapsed_ns = telem.elapsed_ns;
                ctx.terminal_launch_exit_code = telem.exit_code;
                ctx.terminal_launch_ok = telem.ok;
                ctx.terminal_launch_error = telem.err;
                ctx.terminal_launch_outcome = telem.outcome;
                // PH1-M37: copy diagnostics envelope from telemetry.
                if (telem.diagnostics_reason) |dr| {
                    const n = @min(dr.len, run_context_mod.terminal_launch_diagnostics_reason_cap);
                    @memcpy(ctx.terminal_launch_diagnostics_reason_buf[0..n], dr[0..n]);
                    ctx.terminal_launch_diagnostics_reason_len = @intCast(n);
                }
                ctx.terminal_launch_diagnostics_elapsed_ms = telem.diagnostics_elapsed_ms;
                ctx.terminal_launch_diagnostics_signal = telem.diagnostics_signal;
            }
        }
    }

    if (ctx.dry_run) {
        printStdout("dry-run: ok, planned {d} spec(s)\n", .{records.items.len}) catch return errors.Category.runtime_failure.exitCode();
        return 0;
    }

    const run_dir = artifact_paths.nextRunDirectory(allocator, "artifacts") catch return errors.Category.runtime_failure.exitCode();
    defer allocator.free(run_dir);

    const run_id = std.fs.path.basename(run_dir);

    _ = TerminalInvocation.init(
        if (ctx.terminal_cmd.len > 0) ctx.terminal_cmd else ctx.terminal_name,
        &.{},
        "",
    );

    ctx.captureHostIdentity();
    run_fingerprint.populate(&ctx, allocator, run_id, records.items) catch return errors.Category.runtime_failure.exitCode();
    specset_fingerprint.populate(&ctx, allocator, records.items) catch return errors.Category.runtime_failure.exitCode();
    resultset_fingerprint.populate(&ctx, allocator, records.items) catch return errors.Category.runtime_failure.exitCode();
    transport_fingerprint.populate(&ctx, allocator, run_id) catch return errors.Category.runtime_failure.exitCode();
    launch_diagnostics_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    exec_summary_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    const term = compat_io.getenv("TERM");
    context_summary_fingerprint.populate(&ctx, allocator, term) catch return errors.Category.runtime_failure.exitCode();
    metadata_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    artifact_bundle_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    report_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    compare_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    run_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    session_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    environment_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    artifact_manifest_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    provenance_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    integrity_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    consistency_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    trace_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    lineage_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    state_envelope_fingerprint.populate(&ctx, allocator) catch return errors.Category.runtime_failure.exitCode();
    json_writer.writeRun(allocator, run_dir, run_id, records.items, ctx) catch return errors.Category.runtime_failure.exitCode();
    markdown_writer.writeRunSummary(allocator, run_dir, run_id, records.items, ctx) catch return errors.Category.runtime_failure.exitCode();
    env_writer.writeEnvJson(allocator, run_dir, ctx) catch return errors.Category.runtime_failure.exitCode();

    printStdout("wrote run artifacts under {s}\n", .{run_dir}) catch return errors.Category.runtime_failure.exitCode();
    if (launch_preflight_failed) {
        printErr("terminal launch preflight failed: argv[0] is not available as an executable (see run.json terminal_launch_preflight_*)\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    }
    return 0;
}

fn printViolation(v: validator.Violation) !void {
    std.debug.print("{s}: [{s}] {s}\n", .{ v.path, v.field, v.message });
}

fn printErr(msg: []const u8) !void {
    std.debug.print("{s}", .{msg});
}

fn printStdout(comptime fmt: []const u8, args: anytype) !void {
    std.debug.print(fmt, args);
}
