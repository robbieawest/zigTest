const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigTestLib = b.addStaticLibrary(.{
        .name = "zigTest",
        .root_source_file = b.path("./zigTest/src/assertions.zig"),
        .target = target,
        .optimize = optimize,
    });

    const demoExe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("./zigTest/demo.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(zigTestLib);
    if (b.option(bool, "enable-demo", "install the demo too") orelse false)
        b.installArtifact(demoExe);
}
