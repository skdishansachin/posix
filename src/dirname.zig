//! The `dirname` utility writes the directory portion of a pathname.
//!
//! Copyright 2026 S.K. Dishan Sachin
//!
//! This implementation follows the POSIX.1-2024 specification.
//! See https://pubs.opengroup.org/onlinepubs/9799919799/utilities/dirname.html

const std = @import("std");
const build_options = @import("build_options");
const linux = std.os.linux;

fn writeAll(fd: linux.fd_t, buf: [*]const u8, count: usize) void {
    var remaining = count;
    var ptr = buf;

    while (remaining > 0) {
        const rc = linux.write(fd, ptr, remaining);

        if (rc == @as(usize, @bitCast(@as(isize, -1)))) {
            const err = linux.errno(rc);
            switch (err) {
                .INTR => continue,
                .AGAIN => continue,
                else => std.process.exit(1),
            }
        }

        remaining -= rc;
        ptr += rc;
    }
}

fn isAllSlashes(s: []const u8) bool {
    for (s) |c| {
        if (c != '/') return false;
    }
    return s.len > 0;
}

test "isAllSlashes returns true for all slashes" {
    try std.testing.expect(isAllSlashes("/"));
    try std.testing.expect(isAllSlashes("//"));
    try std.testing.expect(isAllSlashes("////"));
}

test "isAllSlashes returns false for non-slash content" {
    try std.testing.expect(!isAllSlashes(""));
    try std.testing.expect(!isAllSlashes("a"));
    try std.testing.expect(!isAllSlashes("/abc/"));
    try std.testing.expect(!isAllSlashes("abc"));
    try std.testing.expect(!isAllSlashes("a/b"));
}

fn trimTrailingSlashes(s: []const u8) []const u8 {
    var end = s.len;
    // Don't trim past the first character
    while (end > 1 and s[end - 1] == '/') {
        end -= 1;
    }
    return s[0..end];
}

test "trimTrailingSlashes removes trailing slashes" {
    try std.testing.expectEqualStrings("/usr/bin", trimTrailingSlashes("/usr/bin/"));
    try std.testing.expectEqualStrings("/usr/bin", trimTrailingSlashes("/usr/bin///"));
}

test "trimTrailingSlashes preserves leading slashes" {
    try std.testing.expectEqualStrings("/", trimTrailingSlashes("//"));
    try std.testing.expectEqualStrings("/", trimTrailingSlashes("///"));
}

test "trimTrailingSlashes no trailing slashes" {
    try std.testing.expectEqualStrings("/usr/bin", trimTrailingSlashes("/usr/bin"));
    try std.testing.expectEqualStrings("/", trimTrailingSlashes("/"));
    try std.testing.expectEqualStrings("a", trimTrailingSlashes("a"));
}

test "trimTrailingSlashes single character" {
    try std.testing.expectEqualStrings("/", trimTrailingSlashes("/"));
    try std.testing.expectEqualStrings("a", trimTrailingSlashes("a"));
}

pub fn main(init: std.process.Init.Minimal) !void {
    var it = init.args.iterate();
    _ = it.next();

    while (it.next()) |arg| {
        if (arg.len == 0) {
            writeAll(linux.STDOUT_FILENO, ".\n".ptr, 2);
            break;
        }

        if (isAllSlashes(arg)) {
            writeAll(linux.STDOUT_FILENO, "/\n".ptr, 2);
            break;
        }

        const trimmed = trimTrailingSlashes(arg);

        const last_slash = std.mem.lastIndexOfScalar(u8, trimmed, '/');

        if (last_slash == null) {
            writeAll(linux.STDOUT_FILENO, ".\n".ptr, 2);
        } else if (last_slash == 0) {
            writeAll(linux.STDOUT_FILENO, "/\n".ptr, 2);
        } else {
            const result = trimmed[0..last_slash.?];
            var buf: [4096]u8 = undefined;
            @memcpy(buf[0..result.len], result);
            buf[result.len] = '\n';
            writeAll(linux.STDOUT_FILENO, &buf, result.len + 1);
        }
    }
}

/// TestResult of spawning a CLI utility as a child process.
/// Captures the termination reason, stdout, and stderr.
/// Caller must call `deinit()` to free captured output.
const TestResult = struct {
    term: std.process.Child.Term,
    stdout: []const u8,
    stderr: []const u8,

    /// Frees captured stdout and stderr memory.
    pub fn deinit(self: TestResult) void {
        std.testing.allocator.free(self.stdout);
        std.testing.allocator.free(self.stderr);
    }

    /// Returns the exit code. Panics if process was killed by signal.
    pub fn exitCode(self: TestResult) u8 {
        return switch (self.term) {
            .exited => |code| code,
            else => unreachable,
        };
    }
};

/// Spawns the given command and captures its output.
/// Uses `std.testing.io` and `std.testing.allocator`.
/// Caller must call `result.deinit()` on the returned TestResult.
fn run(argv: []const []const u8) !TestResult {
    var child = try std.process.spawn(std.testing.io, .{
        .argv = argv,
        .stdout = .pipe,
        .stderr = .pipe,
    });

    var multi_buffer: std.Io.File.MultiReader.Buffer(2) = undefined;
    var multi: std.Io.File.MultiReader = undefined;
    multi.init(std.testing.allocator, std.testing.io, multi_buffer.toStreams(), &.{
        child.stdout.?,
        child.stderr.?,
    });
    defer multi.deinit();

    while (multi.fill(1, .none)) |_| {} else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }
    try multi.checkAnyError();

    const term = try child.wait(std.testing.io);

    return .{
        .term = term,
        .stdout = try multi.toOwnedSlice(0),
        .stderr = try multi.toOwnedSlice(1),
    };
}

test "dirname /usr/lib returns /usr" {
    const r = try run(&.{ build_options.exe_path, "/usr/lib" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("/usr\n", r.stdout);
}

test "dirname /usr/ returns /" {
    const r = try run(&.{ build_options.exe_path, "/usr/" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("/\n", r.stdout);
}

test "dirname / returns /" {
    const r = try run(&.{ build_options.exe_path, "/" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("/\n", r.stdout);
}

test "dirname // returns / (implementation-defined)" {
    const r = try run(&.{ build_options.exe_path, "//" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("/\n", r.stdout);
}

test "dirname //// returns /" {
    const r = try run(&.{ build_options.exe_path, "////" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("/\n", r.stdout);
}

test "dirname empty string returns ." {
    const r = try run(&.{ build_options.exe_path, "" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings(".\n", r.stdout);
}

test "dirname usr returns ." {
    const r = try run(&.{ build_options.exe_path, "usr" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings(".\n", r.stdout);
}

test "dirname . returns ." {
    const r = try run(&.{ build_options.exe_path, "." });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings(".\n", r.stdout);
}

test "dirname .. returns ." {
    const r = try run(&.{ build_options.exe_path, ".." });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings(".\n", r.stdout);
}

test "dirname /usr/lib/ returns /usr" {
    const r = try run(&.{ build_options.exe_path, "/usr/lib/" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("/usr\n", r.stdout);
}

test "dirname /usr/lib/// returns /usr" {
    const r = try run(&.{ build_options.exe_path, "/usr/lib///" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("/usr\n", r.stdout);
}

test "dirname /a/b/c returns /a/b" {
    const r = try run(&.{ build_options.exe_path, "/a/b/c" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("/a/b\n", r.stdout);
}

test "dirname foo/bar returns foo" {
    const r = try run(&.{ build_options.exe_path, "foo/bar" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("foo\n", r.stdout);
}

test "dirname ../foo returns .." {
    const r = try run(&.{ build_options.exe_path, "../foo" });
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("..\n", r.stdout);
}
