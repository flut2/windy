const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const zd_mod = b.dependency("zig_dialog", .{ .target = target, .optimize = optimize });
    const exe = b.addExecutable(.{
        .name = "Example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zd", .module = zd_mod.module("zig-dialog") },
            },
        }),
    });

    const run_step = b.addRunArtifact(exe);
    const run = b.step("run", "Run the example");
    run.dependOn(&run_step.step);

    b.installArtifact(exe);
}
