const std = @import("std");

//untested

fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("\n" ++ fmt ++ "\n\n", args);
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const TestingError = error{ AssertionError, FailureWhileTesting, TypeNotSupported };
const TEST_FAIL_FMT = "Test '{s}' failed.\n  Error: >> ";

pub fn assertEquals(a: anytype, b: anytype, label: []const u8) TestingError!void {
    const T: type = @TypeOf(a, b);
    try assertEqualsInner(T, a, b, label);
}

fn assertEqualsInner(comptime T: type, a: T, b: T, label: []const u8) TestingError!void {
    println("{any}", .{@typeInfo(@TypeOf(a))});
    return switch (@typeInfo(@TypeOf(b))) {
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
                println(TEST_FAIL_FMT ++ "Expected {any} found {any}", .{ label, a, b });
                break :blk TestingError.AssertionError;
            }
        },
        .Pointer => |pointer| blk: {
            switch (pointer.size) {
                .Slice => break :blk try assertSlicesInner(pointer.child, a, b, label),
                else => |size| {
                    println(TEST_FAIL_FMT ++ "Pointer type not suppored: {any}, Size: {any}, Child: {any}.", .{ label, T, size, pointer.child });
                    break :blk TestingError.TypeNotSupported;
                },
            }
        },
        .Array => |arrType| try assertSlicesInner(arrType.child, a, b),
        else => blk: {
            println(TEST_FAIL_FMT ++ "Type not supported: {any}.", .{ label, T });
            break :blk TestingError.TypeNotSupported;
        },
    };
}

pub fn assertSlices(a: anytype, b: anytype, label: []const u8) TestingError!void {
    const T: type = @TypeOf(a, b);
    try assertSlicesInner(T.child, &a, &b, label);
}

fn assertSlicesInner(comptime T: type, a: []const T, b: []const T, label: []const u8) TestingError!void {
    //ToDo implement iterative checker with std.meta.eql
    if (std.mem.eql(T, a, b)) {
        const expected_fail_message = printSliceToString(T, a) catch {
            println("error at expected", .{});
            return TestingError.FailureWhileTesting;
        };
        println("expected_message: {s}", .{expected_fail_message});
        const actual_fail_message = printSliceToString(T, b) catch return TestingError.FailureWhileTesting;
        println("actual_message: {s}", .{actual_fail_message});
        println(TEST_FAIL_FMT ++ "Splices not equal. Expected: {s}, Actual: {s}", .{ label, expected_fail_message, actual_fail_message });
        return TestingError.AssertionError;
    }
}

fn printSliceToString(comptime T: type, a: []const T) ![]const u8 {
    var strList = std.ArrayList(u8).init(allocator);
    defer strList.deinit();

    try strList.ensureTotalCapacity(a.len);
    try strList.appendSlice("[ ");
    for (0..a.len) |i| {
        try std.fmt.format(strList.writer(), "{c}, ", .{a[i]});
        println("'{s}'", .{strList.items});
    }
    strList.replaceRangeAssumeCapacity(strList.items.len - 2, 2, &[0]u8{});
    try strList.appendSlice(" ]");
    println("strList at end: {s}", .{strList.items});
    return strList.items;
}

test "assertEquals_test" {
    const x: i32 = 100;
    const y: i32 = 100;
    try assertEquals(x, y, "");
}

test "assertEquals_test_messages" {
    const x: i32 = 50;
    const y: i32 = 100;
    assertEquals(x, y, "This test is an int test, it should fail!") catch {};
}

test "assertEquals_slice" {
    const x: []const u8 = "Hello World!";
    const yar: []const u8 = &[_]u8{ 'W', 'o', 'r' };

    var y: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);
    defer y.deinit();

    try y.appendSlice("Hello ");
    try y.appendSlice(yar);
    try y.appendSlice("ld!");

    try assertEquals(x, y.items, "Splices test");
}
