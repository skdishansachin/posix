//! The `echo` utility writes arguments to standard output, separated by
//! spaces and followed by a newline.
//!
//! Copyright 2026 S.K. Dishan Sachin
//!
//! This implementation follows the POSIX.1-2024 specification.
//! See https://pubs.opengroup.org/onlinepubs/9799919799/utilities/echo.html

const std = @import("std");
const build_options = @import("build_options");
const linux = std.os.linux;

fn writeAll(fd: linux.fd_t, buffer: [*]const u8, count: usize) void {
    var remaining = count;
    var ptr = buffer;

    while (remaining > 0) {
        const rc = linux.write(fd, ptr, remaining);

        if (rc == @as(usize, @bitCast(@as(isize, -1)))) {
            const err = linux.errno(rc);
            switch (err) {
                .INTR => continue, // Retry on signal interrupt
                .AGAIN => continue, // Retry on would-block
                else => std.process.exit(1), // Exit on other error
            }
        }

        remaining -= rc;
        ptr += rc;
    }
}

pub fn main(init: std.process.Init.Minimal) !void {
    var it = init.args.iterate();
    _ = it.next();

    var needs_space = true;
    while (it.next()) |arg| {
        if (!needs_space) {
            writeAll(linux.STDOUT_FILENO, "\x20".ptr, 1);
        }
        needs_space = false;

        var idx: usize = 0;
        while (idx < arg.len) {
            if (arg[idx] == '\\' and idx + 1 < arg.len) {
                const next = arg[idx + 1];

                switch (next) {
                    'a' => writeAll(linux.STDOUT_FILENO, "\x07".ptr, 1),
                    'b' => writeAll(linux.STDOUT_FILENO, "\x08".ptr, 1),
                    'c' => return,
                    'f' => writeAll(linux.STDOUT_FILENO, "\x0C".ptr, 1),
                    'n' => writeAll(linux.STDOUT_FILENO, "\x0A".ptr, 1),
                    'r' => writeAll(linux.STDOUT_FILENO, "\x0D".ptr, 1),
                    't' => writeAll(linux.STDOUT_FILENO, "\x09".ptr, 1),
                    'v' => writeAll(linux.STDOUT_FILENO, "\x0B".ptr, 1),
                    '\\' => writeAll(linux.STDOUT_FILENO, "\x5C".ptr, 1),
                    '0' => {
                        var value: u8 = 0;
                        var digits: usize = 0;

                        while (digits < 3) {
                            const pos = idx + 2 + digits;
                            if (pos >= arg.len) break;
                            const char = arg[pos];
                            if (char < '0' or char > '7') break;
                            value = value * 8 + (char - '0');
                            digits += 1;
                        }

                        if (digits == 0) {
                            writeAll(linux.STDOUT_FILENO, "\x00".ptr, 1);
                        } else {
                            writeAll(linux.STDOUT_FILENO, &.{value}, 1);
                        }

                        idx += digits;
                    },
                    else => {
                        writeAll(linux.STDOUT_FILENO, &.{ '\\', next }, 2);
                    },
                }

                idx += 2;
            } else {
                writeAll(linux.STDOUT_FILENO, arg.ptr + idx, 1);
                idx += 1;
            }
        }
    }
    writeAll(linux.STDOUT_FILENO, "\x0A".ptr, 1);
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

test "echo no arguments outputs newline" {
    const r = try run(&.{build_options.exe_path});
    defer r.deinit();
    try std.testing.expectEqual(@as(u8, 0), r.exitCode());
    try std.testing.expectEqualStrings("\n", r.stdout);
}

test "echo single argument" {
    const r = try run(&.{ build_options.exe_path, "hello" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\n", r.stdout);
}

test "echo multiple arguments separated by space" {
    const r = try run(&.{ build_options.exe_path, "hello", "world" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello world\n", r.stdout);
}

test "echo many arguments" {
    const r = try run(&.{ build_options.exe_path, "a", "b", "c", "d", "e" });
    defer r.deinit();
    try std.testing.expectEqualStrings("a b c d e\n", r.stdout);
}

test "echo empty string argument" {
    const r = try run(&.{ build_options.exe_path, "" });
    defer r.deinit();
    try std.testing.expectEqualStrings("\n", r.stdout);
}

test "echo escape backslash-n produces newline" {
    const r = try run(&.{ build_options.exe_path, "hello\\nworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\nworld\n", r.stdout);
}

test "echo escape backslash-t produces tab" {
    const r = try run(&.{ build_options.exe_path, "hello\\tworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\tworld\n", r.stdout);
}

test "echo escape backslash-backslash produces backslash" {
    const r = try run(&.{ build_options.exe_path, "hello\\\\world" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\\world\n", r.stdout);
}

test "echo escape backslash-a produces bell" {
    const r = try run(&.{ build_options.exe_path, "hello\\aworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\x07world\n", r.stdout);
}

test "echo escape backslash-b produces backspace" {
    const r = try run(&.{ build_options.exe_path, "hello\\bworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\x08world\n", r.stdout);
}

test "echo escape backslash-f produces form feed" {
    const r = try run(&.{ build_options.exe_path, "hello\\fworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\x0Cworld\n", r.stdout);
}

test "echo escape backslash-r produces carriage return" {
    const r = try run(&.{ build_options.exe_path, "hello\\rworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\rworld\n", r.stdout);
}

test "echo escape backslash-v produces vertical tab" {
    const r = try run(&.{ build_options.exe_path, "hello\\vworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\x0Bworld\n", r.stdout);
}

test "echo escape backslash-c stops output" {
    const r = try run(&.{ build_options.exe_path, "hello\\cworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello", r.stdout);
}

test "echo octal escape zero" {
    const r = try run(&.{ build_options.exe_path, "\\0" });
    defer r.deinit();
    try std.testing.expectEqualStrings("\x00\n", r.stdout);
}

test "echo octal escape 012 is newline" {
    const r = try run(&.{ build_options.exe_path, "\\012" });
    defer r.deinit();
    try std.testing.expectEqualStrings("\n\n", r.stdout);
}

test "echo octal escape 0141 is letter a" {
    const r = try run(&.{ build_options.exe_path, "\\0141" });
    defer r.deinit();
    try std.testing.expectEqualStrings("a\n", r.stdout);
}

test "echo unknown escape outputs literal" {
    const r = try run(&.{ build_options.exe_path, "hello\\xworld" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello\\xworld\n", r.stdout);
}

test "echo spaces in argument preserved" {
    const r = try run(&.{ build_options.exe_path, "hello world" });
    defer r.deinit();
    try std.testing.expectEqualStrings("hello world\n", r.stdout);
}
