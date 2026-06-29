//! The `true` utility always returns with exit code 0.
//!
//! Copyright 2026 S.K. Dishan Sachin
//!
//! This implementation follows the POSIX.1-2024 specification.
//! See https://pubs.opengroup.org/onlinepubs/9799919799/utilities/true.html

const std = @import("std");
const build_options = @import("build_options");

pub fn main() !void {
    std.process.exit(0);
}

test "true exits with code 0" {
    var child = try std.process.spawn(std.testing.io, .{
        .argv = &.{build_options.exe_path},
        .stdout = .close,
        .stderr = .close,
    });
    const term = try child.wait(std.testing.io);
    try std.testing.expectEqual(@as(u8, 0), term.exited);
}
