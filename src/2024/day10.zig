const std = @import("std");
const mem = std.mem;

// NOTE: not pretty, not proud, I don't feel like to improve it 🤷

fn Grid(comptime T: type) type {
    return struct {
        const Self = @This();

        width: usize,
        height: usize,
        items: []T,
        _allocator: std.mem.Allocator,

        fn init(list: *std.ArrayList(T), width: usize, height: usize) !Self {
            return Self{ .width = width, .height = height, .items = try list.*.toOwnedSlice(), ._allocator = list.allocator };
        }

        fn deinit(self: *Self) void {
            self._allocator.free(self.items);
        }

        inline fn get(self: *Self, x: isize, y: isize) ?T {
            if (x < 0 or y < 0 or x >= self.width or y >= self.height) return null;
            const index = @as(usize, @intCast(y * @as(isize, @intCast(self.width)) + x));
            return self.items[index];
        }
    };
}

const Point = @Vector(2, isize);

const Points = std.ArrayList(Point);
const UniquePoints = std.HashMap(Point, void, std.hash_map.AutoContext(Point), std.hash_map.default_max_load_percentage);

const directions: []const Point = &.{
    .{ 1, 0 },
    .{ 0, 1 },
    .{ -1, 0 },
    .{ 0, -1 },
};

input: []const u8,
allocator: mem.Allocator,

fn parse(input: []const u8, allocator: std.mem.Allocator) !Grid(u8) {
    var lines = std.mem.splitScalar(u8, input, '\n');
    const width: usize = lines.peek().?.len;
    const height: usize = @divTrunc(input.len, width + 1);
    var buffer = std.ArrayList(u8).init(allocator);
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        for (line) |char| {
            try buffer.append(char - '0');
        }
    }
    return Grid(u8).init(&buffer, width, height);
}

pub fn part1(this: *const @This()) !?i64 {
    var grid = try parse(this.input, this.allocator);
    defer grid.deinit();

    // start from the trailheads
    var trailheads = Points.init(this.allocator);
    defer trailheads.deinit();
    var x: isize = 0;
    var y: isize = 0;
    while (x < grid.width) : (x += 1) {
        while (y < grid.height) : (y += 1) {
            if (grid.get(x, y).? == 0) {
                try trailheads.append(.{ x, y });
            }
        }
        y = 0;
    }

    var result: usize = 0;
    while (trailheads.popOrNull()) |trailhead| {
        var peaks = UniquePoints.init(this.allocator);
        defer peaks.deinit();

        var points = Points.init(this.allocator);
        defer points.deinit();

        try points.append(trailhead);

        while (points.popOrNull()) |currentPoint| {
            const currentHeight = grid.get(currentPoint[0], currentPoint[1]).?;
            for (directions) |direction| {
                const nextPoint = currentPoint + direction;
                if (grid.get(nextPoint[0], nextPoint[1])) |nextHeight| {
                    if ((@as(i8, @intCast(nextHeight)) - @as(i8, @intCast(currentHeight))) == 1) {
                        if (nextHeight == 9) {
                            try peaks.put(nextPoint, undefined);
                        } else {
                            try points.append(nextPoint);
                        }
                    }
                }
            }
        }

        result += peaks.count();
    }

    return @intCast(result);
}

pub fn part2(this: *const @This()) !?i64 {
    var grid = try parse(this.input, this.allocator);
    defer grid.deinit();

    // start from the trailheads
    var trailheads = Points.init(this.allocator);
    defer trailheads.deinit();
    var x: isize = 0;
    var y: isize = 0;
    while (x < grid.width) : (x += 1) {
        while (y < grid.height) : (y += 1) {
            if (grid.get(x, y).? == 0) {
                try trailheads.append(.{ x, y });
            }
        }
        y = 0;
    }

    var result: usize = 0;
    while (trailheads.popOrNull()) |trailhead| {
        var points = Points.init(this.allocator);
        defer points.deinit();

        try points.append(trailhead);

        while (points.popOrNull()) |currentPoint| {
            const currentHeight = grid.get(currentPoint[0], currentPoint[1]).?;
            for (directions) |direction| {
                const nextPoint = currentPoint + direction;
                if (grid.get(nextPoint[0], nextPoint[1])) |nextHeight| {
                    if ((@as(i8, @intCast(nextHeight)) - @as(i8, @intCast(currentHeight))) == 1) {
                        if (nextHeight == 9) {
                            result += 1;
                        } else {
                            try points.append(nextPoint);
                        }
                    }
                }
            }
        }
    }

    return @intCast(result);
}

test "it should work wih small examples" {
    const allocator = std.testing.allocator;
    const input =
        \\0123
        \\1234
        \\8765
        \\9876
        \\
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(1, try problem.part1());
    try std.testing.expectEqual(16, try problem.part2());
}

test "it should work wih more examples" {
    const allocator = std.testing.allocator;
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
        \\
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(36, try problem.part1());
}

test "it should work wih another examples" {
    const allocator = std.testing.allocator;
    const input =
        \\@@90@@9
        \\@@@1@98
        \\@@@2@@7
        \\6543456
        \\765@987
        \\876@@@@
        \\987@@@@
        \\
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(13, try problem.part2());
}
