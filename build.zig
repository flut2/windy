const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = .{
        .use_gtk = b.option(bool, "use_gtk",
            \\Whether to use GTK as the dialog provider on Linux (requires gtk3 development headers).
            \\Zenity is used otherwise and assumed to exist on the computer running the program.
        ) orelse true,
    };

    const opt_step = b.addOptions();
    inline for (@typeInfo(@TypeOf(options)).@"struct".fields) |field|
        opt_step.addOption(field.type, field.name, @field(options, field.name));

    const mod = b.addModule("zig-dialog", .{
        .root_source_file = b.path("src/zd.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = builtin.os.tag == .windows or builtin.os.tag == .macos,
        .imports = &.{
            .{ .name = "options", .module = opt_step.createModule() },
        },
    });

    if (builtin.os.tag == .windows) if (b.lazyDependency("zigwin32", .{})) |dep|
        mod.addImport("win32", dep.module("win32"));

    if ((builtin.os.tag == .linux or builtin.os.tag.isBSD()) and options.use_gtk) {
        mod.link_libc = true;
        mod.linkSystemLibrary("gtk+-3.0", .{});
    }
}
