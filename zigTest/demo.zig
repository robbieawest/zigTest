const std = @import("std");
const assertions = @import("src/assertions.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    const x: []const u8 = "Hello World!";
    const yar: []const u8 = &[_]u8{ 'W', 'o', 'r' };

    var y: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);
    defer y.deinit();

    try y.appendSlice("Hello ");
    try y.appendSlice(yar);
    try y.appendSlice("dd!");

    assertions.assertEquals(x, y.items, "Slices test") catch
        std.debug.print("Error found!\n", .{});
}
