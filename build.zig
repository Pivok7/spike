const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "spike",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // SDL3
    const sdl3_dep = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,

        .ext_ttf = true,
    });
    exe.root_module.addImport("sdl3", sdl3_dep.module("sdl3"));

    exe.root_module.link_libc = true;

    // library for forkpty
    exe.root_module.linkSystemLibrary("util", .{});

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
