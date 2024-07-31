const std = @import("std");

pub fn build(b: *std.Build) void {
    const windows = b.option(bool, "windows", "Target Microsoft Windows") orelse false;
    const test_step = b.step("test", "Run unit tests");

    const exe = b.addExecutable(.{
        .name = "AssertionsBuild",
        .root_source_file = b.path("./src/assertions.zig"),
        .target = b.resolveTargetQuery(.{
            .os_tag = if (windows) .windows else null,
        }),
    });

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("./src/assertions.zig"),
        .target = b.host,
    });

    b.installArtifact(exe);
    b.installArtifact(unit_tests);
    test_step.dependOn(&unit_tests.step);
}
