const std = @import("std");

pub fn build(b: *std.Build) void {
    const windows = b.option(bool, "windows", "Target Microsoft Windows") orelse false;

    const exe = b.addExecutable(.{
        .name = "AssertionsBuild",
        .root_source_file = b.path("./src/assertions.zig"),
        .target = b.resolveTargetQuery(.{
            .os_tag = if (windows) .windows else null,
        }),
    });

    b.installArtifact(exe);
}
