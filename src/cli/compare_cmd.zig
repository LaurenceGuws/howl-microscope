const std = @import("std");
const errors = @import("../core/errors.zig");
const run_json = @import("../compare/run_json.zig");
const compare_markdown = @import("../compare/compare_markdown.zig");
const compare_json = @import("../compare/compare_json.zig");

const max_read = 4 * 1024 * 1024;

pub fn execute(allocator: std.mem.Allocator, argv: []const []const u8) u8 {
    var io_ctx = std.Io.Threaded.init_single_threaded;
    const io = io_ctx.io();
    if (argv.len < 2) {
        printErr("usage: howl-microscope compare <run.json|dir> <run.json|dir>\n") catch {};
        return errors.Category.unknown_command.exitCode();
    }

    var owned_a: ?[]const u8 = null;
    defer if (owned_a) |p| allocator.free(p);
    var owned_b: ?[]const u8 = null;
    defer if (owned_b) |p| allocator.free(p);

    const path_a = resolveRunJson(allocator, argv[0], &owned_a) catch return errors.Category.runtime_failure.exitCode();
    const path_b = resolveRunJson(allocator, argv[1], &owned_b) catch return errors.Category.runtime_failure.exitCode();

    const data_a = std.Io.Dir.cwd().readFileAlloc(io, path_a, allocator, .limited(max_read)) catch {
        printErr("could not read first run.json\n") catch {};
        return errors.Category.runtime_failure.exitCode();
    };
    defer allocator.free(data_a);
    const data_b = std.Io.Dir.cwd().readFileAlloc(io, path_b, allocator, .limited(max_read)) catch {
        printErr("could not read second run.json\n") catch {};
        return errors.Category.runtime_failure.exitCode();
    };
    defer allocator.free(data_b);

    const parsed_a = std.json.parseFromSlice(std.json.Value, allocator, std.mem.trim(u8, data_a, " \n\r\t"), .{}) catch {
        printErr("invalid JSON in first run file\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    };
    defer parsed_a.deinit();
    const parsed_b = std.json.parseFromSlice(std.json.Value, allocator, std.mem.trim(u8, data_b, " \n\r\t"), .{}) catch {
        printErr("invalid JSON in second run file\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    };
    defer parsed_b.deinit();

    switch (parsed_a.value) {
        .object => {},
        else => {
            printErr("first file: expected top-level JSON object\n") catch {};
            return errors.Category.invalid_spec.exitCode();
        },
    }
    switch (parsed_b.value) {
        .object => {},
        else => {
            printErr("second file: expected top-level JSON object\n") catch {};
            return errors.Category.invalid_spec.exitCode();
        },
    }

    var map_a = run_json.parseResultsMapCompare(allocator, parsed_a.value) catch |err| {
        switch (err) {
            error.DuplicateSpecId => printErr("first run.json: duplicate spec_id in results\n") catch {},
            error.MissingSpecOrStatus => printErr("first run.json: result row missing spec_id or status\n") catch {},
            error.InvalidResultRow => printErr("first run.json: result entry must be an object\n") catch {},
            error.MissingResults, error.BadResults, error.NotObject => printErr("first run.json: invalid results array\n") catch {},
            error.OutOfMemory => return errors.Category.runtime_failure.exitCode(),
        }
        return errors.Category.invalid_spec.exitCode();
    };
    defer run_json.deinitMap(allocator, &map_a);

    var map_b = run_json.parseResultsMapCompare(allocator, parsed_b.value) catch |err| {
        switch (err) {
            error.DuplicateSpecId => printErr("second run.json: duplicate spec_id in results\n") catch {},
            error.MissingSpecOrStatus => printErr("second run.json: result row missing spec_id or status\n") catch {},
            error.InvalidResultRow => printErr("second run.json: result entry must be an object\n") catch {},
            error.MissingResults, error.BadResults, error.NotObject => printErr("second run.json: invalid results array\n") catch {},
            error.OutOfMemory => return errors.Category.runtime_failure.exitCode(),
        }
        return errors.Category.invalid_spec.exitCode();
    };
    defer run_json.deinitMap(allocator, &map_b);

    const rows = run_json.diffResults(allocator, &map_a, &map_b) catch return errors.Category.runtime_failure.exitCode();
    defer run_json.deinitDiffRows(allocator, rows);

    var meta_arena = std.heap.ArenaAllocator.init(allocator);
    defer meta_arena.deinit();
    const meta_alloc = meta_arena.allocator();

    const meta_a = run_json.parseRunMeta(meta_alloc, parsed_a.value) catch {
        printErr("could not parse metadata from first run.json\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    };
    const meta_b = run_json.parseRunMeta(meta_alloc, parsed_b.value) catch {
        printErr("could not parse metadata from second run.json\n") catch {};
        return errors.Category.invalid_spec.exitCode();
    };
    const meta_diff = run_json.diffRunMeta(meta_a, meta_b);

    std.Io.Dir.cwd().createDirPath(io, "artifacts/compare") catch return errors.Category.runtime_failure.exitCode();
    compare_markdown.writeFile(allocator, "artifacts/compare/compare.md", rows, path_a, path_b, &meta_diff) catch return errors.Category.runtime_failure.exitCode();
    compare_json.writeFile(allocator, "artifacts/compare/compare.json", rows, path_a, path_b, &meta_diff) catch return errors.Category.runtime_failure.exitCode();

    printStdout("compare: wrote artifacts/compare/compare.md and artifacts/compare/compare.json\n", .{}) catch return errors.Category.runtime_failure.exitCode();
    return 0;
}

fn resolveRunJson(allocator: std.mem.Allocator, target: []const u8, owned_out: *?[]const u8) ![]const u8 {
    if (std.mem.endsWith(u8, target, ".json")) return target;
    const p = try std.fs.path.join(allocator, &.{ target, "run.json" });
    owned_out.* = p;
    return p;
}

fn printErr(msg: []const u8) !void {
    std.debug.print("{s}", .{msg});
}

fn printStdout(comptime fmt: []const u8, args: anytype) !void {
    std.debug.print(fmt, args);
}
