const std = @import("std");

fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n\n", args);
}

fn printerr(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("\nTest '{s}' failed.\n  Error: >> " ++ fmt ++ "\n\n", args);
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const TestingError = error{ AssertionError, FailureWhileTesting, TypeNotSupported };
fn catchTestingErr(err: anyerror) TestingError {
    return switch (err) {
        error.AssertionError, error.TypeNotSupported => |capError| capError,
        else => TestingError.FailureWhileTesting,
    };
}

pub fn assertEquals(a: anytype, b: anytype, label: []const u8) TestingError!void {
    const T: type = @TypeOf(a, b);
    try assertEqualsInner(T, a, b, label);
}

fn assertEqualsInner(comptime T: type, a: T, b: T, label: []const u8) TestingError!void {
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
                printerr("Expected {any} found {any}", .{ label, a, b });
                break :blk TestingError.AssertionError;
            }
        },
        .Pointer => |pointer| blk: {
            switch (pointer.size) {
                .Slice => break :blk assertSlicesInner(pointer.child, a, b, label) catch |err| return catchTestingErr(err),
                else => |size| {
                    printerr("Pointer type not suppored: {any}, Size: {any}, Child: {any}.", .{ label, T, size, pointer.child });
                    break :blk TestingError.TypeNotSupported;
                },
            }
        },
        .Array => |arrType| assertSlicesInner(arrType.child, a, b) catch |err| return catchTestingErr(err),
        else => blk: {
            printerr("Type not supported: {any}.", .{ label, T });
            break :blk TestingError.TypeNotSupported;
        },
    };
}

pub fn assertSlices(a: anytype, b: anytype, label: []const u8) TestingError!void {
    const T: type = @TypeOf(a, b);
    try assertSlicesInner(T.child, &a, &b, label);
}

fn assertSlicesInner(comptime T: type, a: []const T, b: []const T, label: []const u8) !void {
    //Todo return generic error union from this and then parse it later as TestingError, no point doing it here since this is private

    if (!std.mem.eql(T, a, b)) {
        const expected_string = try printSliceToString(T, a);
        const actual_string = try printSliceToString(T, b);
        defer allocator.free(expected_string);
        defer allocator.free(actual_string);

        var differences = std.ArrayList(Difference).init(allocator);
        defer differences.deinit();
        try getSliceDifferences(T, a, b, &differences);

        printerr("Slices not equal.\n\tExpected: {s}\n\tActual:   {s}", .{ label, expected_string, actual_string });

        var differencesToString = std.ArrayList(u8).init(allocator);
        defer differencesToString.deinit();
        try differencesToString.appendSlice("Differences found within slices.");
        for (differences.items) |*difference| try difference.outAfterList(&differencesToString);

        println("{s}", .{differencesToString.items});

        return TestingError.AssertionError;
    }
}

const Difference = struct {
    index: u8,
    expected_value: ?u8,
    actual_value: ?u8,

    fn outAfterList(self: *Difference, list: *std.ArrayList(u8)) !void {
        var expected_out = std.ArrayList(u8).init(allocator);
        defer expected_out.deinit();
        var actual_out = std.ArrayList(u8).init(allocator);
        defer actual_out.deinit();

        if (self.expected_value == null)
            try expected_out.appendSlice("{empty}")
        else
            try expected_out.append(self.expected_value.?);

        if (self.actual_value == null)
            try actual_out.appendSlice("{empty}")
        else
            try actual_out.append(self.actual_value.?);

        try std.fmt.format(list.writer(), "\n\tDifference at index: {d}, expected '{s}', got '{s}'.", .{ self.index, expected_out.items, actual_out.items });
    }
};

fn getSliceDifferences(comptime T: type, a: []const T, b: []const T, differences: *std.ArrayList(Difference)) !void {
    const maxLength = if (a.len > b.len) a.len else b.len;

    for (0..maxLength) |i| {
        const potentialDifference: Difference = Difference{ .index = @intCast(i), .expected_value = if (i < a.len) a[i] else null, .actual_value = if (i < b.len) b[i] else null };

        if (!std.meta.eql(potentialDifference.expected_value, potentialDifference.actual_value))
            try differences.append(potentialDifference);
    }
}

fn printSliceToString(comptime T: type, a: []const T) ![]const u8 {
    var strList = std.ArrayList(u8).init(allocator);
    defer strList.deinit();

    try strList.ensureTotalCapacity(a.len * 3 + 1);
    try strList.appendSlice("[ ");
    for (a) |entry|
        try std.fmt.format(strList.writer(), "{c}, ", .{entry});

    strList.replaceRangeAssumeCapacity(strList.items.len - 2, 2, &[0]u8{});
    try strList.appendSlice(" ]");

    const ret = try allocator.alloc(u8, strList.items.len);
    std.mem.copyForwards(u8, ret, strList.items);
    return ret;
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
    //try y.appendSlice("ld!");

    try assertEquals(x, y.items, "Slices test");
}
