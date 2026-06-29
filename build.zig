const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .whitelist = &.{
            .{ .cpu_arch = .x86_64, .os_tag = .linux },
            .{ .cpu_arch = .aarch64, .os_tag = .linux },
        },
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const utilities = [_]struct { []const u8, []const u8 }{
        .{ "true", "src/true.zig" },
        .{ "false", "src/false.zig" },
        .{ "echo", "src/echo.zig" },
        .{ "dirname", "src/dirname.zig" },
    };

    for (utilities) |util| {
        const name = util[0];
        const src = util[1];

        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(src),
                .target = target,
                .optimize = optimize,
            }),
        });

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(
            b.fmt("run-{s}", .{name}),
            b.fmt("Run {s}", .{name}),
        );
        run_step.dependOn(&run_cmd.step);

        const options = b.addOptions();
        options.addOptionPath("exe_path", exe.getEmittedBin());

        const test_module = b.createModule(.{
            .root_source_file = b.path(src),
            .target = target,
            .optimize = optimize,
        });
        test_module.addOptions("build_options", options);

        const exe_tests = b.addTest(.{
            .root_module = test_module,
        });

        const run_exe_tests = b.addRunArtifact(exe_tests);
        run_exe_tests.step.dependOn(b.getInstallStep());

        const test_step = b.step(b.fmt("test-{s}", .{name}), b.fmt("Run test-{s}", .{name}));
        test_step.dependOn(&run_exe_tests.step);
    }
}
