pub const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Arg0Expand = std.process.Child.Arg0Expand;
const EnvMap = std.process.EnvMap;
const RunError = std.process.Child.RunError;
const RunResult = std.process.Child.RunResult;
const ChildProcess = std.process.Child;
const assert = std.debug.assert;

/// Customization of std.process.Child.run:
///     - allows writing to stdin
///
/// Spawns a child process, sends bytes to stdin, waits for it, collecting stdout and stderr, and then returns.
/// If it succeeds, the caller owns result.stdout and result.stderr memory.
pub fn runWithStdin(args: struct {
    allocator: mem.Allocator,
    argv: []const []const u8,
    cwd: ?[]const u8 = null,
    cwd_dir: ?fs.Dir = null,
    env_map: ?*const EnvMap = null,
    max_output_bytes: usize = 50 * 1024,
    expand_arg0: Arg0Expand = .no_expand,
    progress_node: std.Progress.Node = std.Progress.Node.none,
    stdin: ?[]const u8 = null,
}) (std.Thread.SpawnError || std.posix.WriteError || RunError)!RunResult {
    var child = ChildProcess.init(args.argv, args.allocator);
    child.stdin_behavior = if (args.stdin) |_| .Pipe else .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.cwd = args.cwd;
    child.cwd_dir = args.cwd_dir;
    child.env_map = args.env_map;
    child.expand_arg0 = args.expand_arg0;
    child.progress_node = args.progress_node;

    var stdout: std.ArrayListUnmanaged(u8) = .empty;
    errdefer stdout.deinit(args.allocator);
    var stderr: std.ArrayListUnmanaged(u8) = .empty;
    errdefer stderr.deinit(args.allocator);

    try child.spawn();
    errdefer {
        _ = child.kill() catch {};
    }

    // write to stdin of the child
    {
        var writer_thread: ?std.Thread = null;
        defer if (writer_thread) |thread| thread.join();
        if (args.stdin) |stdin| {
            writer_thread = try std.Thread.spawn(.{}, struct {
                fn write_stdin(destination: std.fs.File, source: []const u8) void {
                    defer destination.close();
                    destination.writeAll(source) catch {};
                }
            }.write_stdin, .{ child.stdin.?, stdin });
        }
    }
    child.stdin = null; // avoids double close on child.wait()
    assert(child.stdin == null);

    try child.collectOutput(args.allocator, &stdout, &stderr, args.max_output_bytes);
    return RunResult{
        .stdout = try stdout.toOwnedSlice(args.allocator),
        .stderr = try stderr.toOwnedSlice(args.allocator),
        .term = try child.wait(),
    };
}
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    const dockerfile =
        \\FROM alpine:3.21
        \\COPY zig-out/bin/gatorcat gatorcat
        \\ENTRYPOINT ["/gatorcat"]
    ;
    const child = try runWithStdin(.{
        .allocator = gpa.allocator(),
        .argv = &.{ "docker", "build", "-t", "gatorcat", "-f-", "." },
        .stdin = dockerfile,
    });

    defer gpa.allocator().free(child.stdout);
    defer gpa.allocator().free(child.stderr);

    switch (child.term) {
        .Exited => |code| {
            std.debug.print("child exited with code {}\nstdout:\n{s}\nstderr:\n{s}\n", .{ code, child.stdout, child.stderr });
            if (code != 0) return error.ChildFailed;
        },
        .Signal => return error.Signal,
        .Stopped => return error.Stopped,
        .Unknown => return error.Unknown,
    }
}
