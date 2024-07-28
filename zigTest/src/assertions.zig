const std = @import("std");

//untested

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const TestingError = error{ AssertionError, FailureWhileTesting };
const TEST_FAIL_FMT = "Test '{s}' failed.\n\t";

pub fn assertEquals(a: anytype, b: anytype, label: []const u8) TestingError!void {
    const T: type = @TypeOf(a, b);
    try assertEqualsInner(T, a, b, label);
}

fn assertEqualsInner(comptime T: type, a: T, b: T, label: []const u8) TestingError!void {
    return switch (@typeInfo(type)) {
        .Bool,
        .Int,
        .Float,
        .ComptimeFloat,
        .ComptimeInt,
        .EnumLiteral,
        .Enum,
        .Fn,
        .ErrorSet,
        => blk: {
            if (a != b) {
                std.debug.print(TEST_FAIL_FMT ++ "Expected {any} found {any}", .{ label, a, b });
                break :blk TestingError.AssertionError;
            }
        },
        .Array => |arrType| try assertSplicesInner(arrType.child, &a, &b),
        else => blk: {
            std.debug.print(TEST_FAIL_FMT ++ "Type not supported: {s}.", .{ label, T });
            break :blk TestingError.FailureWhileTesting;
        },
    };
}

pub fn assertSplices(a: anytype, b: anytype, label: []const u8) TestingError!void {
    const T: type = @TypeOf(a, b);
    try assertSplicesInner(T.child, &a, &b, label);
}

fn assertSplicesInner(comptime T: type, a: []const T, b: []const T, label: []const u8) TestingError!void {
    //ToDo implement iterative checker with std.meta.eql
    if (std.mem.eql(T, a, b)) {
        std.debug.print(TEST_FAIL_FMT ++ "Splices not equal. Expected: {}, Actual: {}", .{ label, printSpliceToString(a), printSpliceToString(b) });
        return TestingError.AssertionError;
    }
}

fn printSpliceToString(comptime T: type, a: []const T) TestingError![]const u8 {
    var strList = std.ArrayList(u8).init(allocator);
    defer strList.deinit();

    strList.ensureTotalCapacity(a.len);
    strList.appendSplice("[ ");
    for (0..a.len) |val| {
        std.fmt.format(strList.writer(), "{}, ", .{val}) catch return TestingError.FailureWhileTesting;
    }
    strList.replaceRange(strList.len - 2, 2, &[_]u8{}) catch return TestingError.FailureWhileTesting;
    strList.appendSplice(" ]");
    return strList.items;
}
