const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const Lists = struct {
    const Self = @This();

    left: []u32,
    right: []u32,
    allocator: mem.Allocator,

    fn init(allocator: mem.Allocator, left: []u32, right: []u32) Self {
        return Self{
            .left = left,
            .right = right,
            .allocator = allocator,
        };
    }

    fn fromInput(allocator: mem.Allocator, input: []const u8) !Self {
        var lines = std.mem.splitScalar(u8, input, '\n');
        var left = std.ArrayList(u32).init(allocator);
        defer left.deinit();
        var right = std.ArrayList(u32).init(allocator);
        defer right.deinit();
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var tokens = std.mem.splitSequence(u8, line, "   ");
            if (tokens.next()) |token| {
                try left.append(try std.fmt.parseInt(u32, token, 10));
            }
            if (tokens.next()) |token| {
                try right.append(try std.fmt.parseInt(u32, token, 10));
            }
        }

        const leftSlice = try left.toOwnedSlice();
        const rightSlice = try right.toOwnedSlice();
        std.mem.sort(u32, leftSlice, {}, comptime std.sort.asc(u32));
        std.mem.sort(u32, rightSlice, {}, comptime std.sort.asc(u32));
        return Self.init(allocator, leftSlice, rightSlice);
    }

    fn deinit(self: Self) void {
        self.allocator.free(self.left);
        self.allocator.free(self.right);
    }
};

pub fn part1(this: *const @This()) !?i64 {
    var result: u32 = 0;
    const lists = try Lists.fromInput(this.allocator, this.input);
    defer lists.deinit();

    var i: usize = 0;
    while (i < lists.left.len and i < lists.right.len) : (i += 1) {
        result += @truncate(@abs(@as(i64, lists.left[i]) - @as(i64, lists.right[i])));
    }
    return result;
}

pub fn part2(this: *const @This()) !?i64 {
    var result: u32 = 0;
    const lists = try Lists.fromInput(this.allocator, this.input);
    defer lists.deinit();

    var i: usize = 0;
    var j: usize = 0;
    var count: u32 = 0;
    while (i < lists.left.len) : (i += 1) {
        while (j < lists.right.len) : (j += 1) {
            if (lists.left[i] < lists.right[j]) break;
            if (lists.left[i] == lists.right[j]) count += 1;
        }
        result += lists.left[i] * count;
        count = 0;
        j = 0;
    }
    return result;
}

test "it should work with first small example" {
    const allocator = std.testing.allocator;
    const input =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(11, try problem.part1());
    try std.testing.expectEqual(31, try problem.part2());
}
