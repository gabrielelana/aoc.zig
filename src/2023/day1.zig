const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

pub fn part1(this: *const @This()) !?i64 {
    var result: u32 = 0;
    var splits = std.mem.splitScalar(u8, this.input, '\n');
    while (splits.next()) |line| {
        var first: ?u8 = null;
        var last: ?u8 = null;
        for (line) |char| {
            switch (char) {
                '0'...'9' => {
                    const n = char - '0';
                    if (first == null) {
                        first = n;
                    }
                    last = n;
                },
                else => {},
            }
        }
        result += (first orelse 0) * 10 + (last orelse 0);
        first = null;
        last = null;
    }
    return result;
}

pub fn part2(this: *const @This()) !?i64 {
    const TokenWithIndex = struct { token: []const u8, index: u8 };
    var numbers: [10]TokenWithIndex = .{
        TokenWithIndex{ .token = "zero", .index = 0 },
        TokenWithIndex{ .token = "one", .index = 0 },
        TokenWithIndex{ .token = "two", .index = 0 },
        TokenWithIndex{ .token = "three", .index = 0 },
        TokenWithIndex{ .token = "four", .index = 0 },
        TokenWithIndex{ .token = "five", .index = 0 },
        TokenWithIndex{ .token = "six", .index = 0 },
        TokenWithIndex{ .token = "seven", .index = 0 },
        TokenWithIndex{ .token = "eight", .index = 0 },
        TokenWithIndex{ .token = "nine", .index = 0 },
    };
    var result: u32 = 0;
    var splits = std.mem.splitScalar(u8, this.input, '\n');
    while (splits.next()) |line| {
        var first: ?u8 = null;
        var last: ?u8 = null;
        for (line) |char| {
            switch (char) {
                '0'...'9' => {
                    const n = char - '0';
                    if (first == null) {
                        first = n;
                    }
                    last = n;
                },
                else => {
                    var i: u8 = 0;
                    while (i < numbers.len) : (i += 1) {
                        var number = &numbers[i];
                        if (number.index >= number.token.len) continue;
                        if (number.token[number.index] == char) {
                            number.index += 1;
                        } else {
                            number.index = 0;
                        }
                        if (number.index == number.token.len) {
                            if (first == null) {
                                first = i;
                            }
                            last = i;
                        }
                    }
                },
            }
        }
        result += (first orelse 0) * 10 + (last orelse 0);
        first = null;
        last = null;
        for (&numbers) |*number| number.index = 0;
    }
    return result;
}

test "it should work with simple input for part1" {
    const allocator = std.testing.allocator;
    const input =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(142, try problem.part1());
}

test "it should work with simple input for part2" {
    const allocator = std.testing.allocator;
    const input =
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteen
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(281, try problem.part2());
}
