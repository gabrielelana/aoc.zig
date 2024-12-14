const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const UniquePoints = std.HashMap(Point, void, std.hash_map.AutoContext(Point), std.hash_map.default_max_load_percentage);

pub fn part1(this: *const @This()) !?i64 {
    var antennas, const width, const height = try parse(this.input, this.allocator);
    defer {
        var keys = antennas.keyIterator();
        while (keys.next()) |key| {
            antennas.get(key.*).?.deinit();
        }
        antennas.deinit();
    }

    var result = UniquePoints.init(this.allocator);
    defer result.deinit();

    var keys = antennas.keyIterator();
    while (keys.next()) |key| {
        const antennasWithSameFrequency = antennas.get(key.*).?.items;
        const pairsOfAntennas = try pairs(Point, antennasWithSameFrequency, this.allocator);
        defer this.allocator.free(pairsOfAntennas);
        for (pairsOfAntennas) |pairOfAntennas| {
            const pairOfAntinodes = antinodes(pairOfAntennas[0], pairOfAntennas[1]);
            for (pairOfAntinodes) |antinode| {
                if (antinode[0] >= 0 and antinode[0] < width and antinode[1] >= 0 and antinode[1] < height) {
                    try result.put(antinode, undefined);
                }
            }
        }
    }
    return @intCast(result.count());
}

pub fn part2(this: *const @This()) !?i64 {
    var antennas, const width, const height = try parse(this.input, this.allocator);
    defer {
        var keys = antennas.keyIterator();
        while (keys.next()) |key| {
            antennas.get(key.*).?.deinit();
        }
        antennas.deinit();
    }

    var result = UniquePoints.init(this.allocator);
    defer result.deinit();

    var keys = antennas.keyIterator();
    while (keys.next()) |key| {
        const antennasWithSameFrequency = antennas.get(key.*).?.items;
        const pairsOfAntennas = try pairs(Point, antennasWithSameFrequency, this.allocator);
        defer this.allocator.free(pairsOfAntennas);
        for (pairsOfAntennas) |pairOfAntennas| {
            const pairOfAntinodes = try antinodesInLine(pairOfAntennas[0], pairOfAntennas[1], width, height, this.allocator);
            defer pairOfAntinodes.deinit();
            for (pairOfAntinodes.items) |antinode| {
                if (antinode[0] >= 0 and antinode[0] < width and antinode[1] >= 0 and antinode[1] < height) {
                    try result.put(antinode, undefined);
                }
            }
        }
    }
    return @intCast(result.count());
}

const Antennas = std.HashMap(u8, std.ArrayList(Point), std.hash_map.AutoContext(u8), std.hash_map.default_max_load_percentage);

fn parse(input: []const u8, allocator: std.mem.Allocator) !struct { Antennas, u8, u8 } {
    var antennas = Antennas.init(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    var width: u8 = 0;
    var height: u8 = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var i: u8 = 0;
        while (i < line.len) : (i += 1) {
            if (line[i] == '.') continue;
            var points = antennas.get(line[i]);
            if (points == null) {
                points = std.ArrayList(Point).init(allocator);
            }
            try points.?.append(.{ @intCast(i), @intCast(height) });
            try antennas.put(line[i], points.?);
        }
        height += 1;
        width = @intCast(line.len);
    }
    return .{ antennas, width, height };
}

test "can parse input" {
    const allocator = std.testing.allocator;
    const input: []const u8 =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;

    var expected = Antennas.init(allocator);
    defer expected.deinit();
    var os = std.ArrayList(Point).init(allocator);
    try os.appendSlice(&.{ .{ 8, 1 }, .{ 5, 2 }, .{ 7, 3 }, .{ 4, 4 } });
    defer os.deinit();
    try expected.put('0', os);
    var as = std.ArrayList(Point).init(allocator);
    try as.appendSlice(&.{ .{ 6, 5 }, .{ 8, 8 }, .{ 9, 9 } });
    try expected.put('A', as);
    defer as.deinit();

    var actual, const width, const height = try parse(input, allocator);
    defer actual.deinit();
    defer actual.get('0').?.deinit();
    defer actual.get('A').?.deinit();

    try std.testing.expectEqual(12, width);
    try std.testing.expectEqual(12, height);

    try std.testing.expectEqual(expected.count(), actual.count());
    var keys = expected.keyIterator();
    while (keys.next()) |key| {
        try std.testing.expectEqualSlices(Point, expected.get(key.*).?.items, actual.get(key.*).?.items);
    }
}

fn antinodesInLine(firstAntenna: Point, secondAntenna: Point, width: u8, height: u8, allocator: std.mem.Allocator) !std.ArrayList(Point) {
    var result = std.ArrayList(Point).init(allocator);
    try result.append(firstAntenna);
    try result.append(secondAntenna);
    const diff = firstAntenna - secondAntenna;
    {
        var antinode = firstAntenna;
        while (true) {
            antinode = antinode + diff;
            if (antinode[0] < 0 or antinode[0] >= width or antinode[1] < 0 or antinode[1] >= height) break;
            try result.append(antinode);
        }
    }
    {
        var antinode = secondAntenna;
        while (true) {
            antinode = antinode - diff;
            if (antinode[0] < 0 or antinode[0] >= width or antinode[1] < 0 or antinode[1] >= height) break;
            try result.append(antinode);
        }
    }
    return result;
}

test "antinodes in line given a pair of antennas" {
    // ..........
    // ...#...... (3,1)
    // ..........
    // ....a..... (4,3)
    // ..........
    // .....a.... (5,5)
    // ..........
    // ......#... (6,7)
    // ..........
    // .......#.. (7,9)

    const a1: Point = .{ 4, 3 };
    const a2: Point = .{ 5, 5 };
    const width: u8 = 10;
    const height: u8 = 10;
    const given = try antinodesInLine(a1, a2, width, height, std.testing.allocator);
    defer given.deinit();
    const expected: []const Point = &.{ .{ 4, 3 }, .{ 5, 5 }, .{ 3, 1 }, .{ 6, 7 }, .{ 7, 9 } };
    try std.testing.expectEqualDeep(expected, given.items);
}

const Point = @Vector(2, i8);

fn antinodes(firstAntenna: Point, secondAntenna: Point) [2]Point {
    const diff = firstAntenna - secondAntenna;
    return .{ firstAntenna + diff, secondAntenna - diff };
}

test "antinodes given a pair of antennas" {
    // ..........
    // ...#...... (3,1)
    // ..........
    // ....a..... (4,3)
    // ..........
    // .....a.... (5,5)
    // ..........
    // ......#... (6,7)
    // ..........
    // ..........

    const a1: Point = .{ 4, 3 };
    const a2: Point = .{ 5, 5 };
    const expected: [2]Point = .{ .{ 3, 1 }, .{ 6, 7 } };
    try std.testing.expectEqual(expected, antinodes(a1, a2));
}

fn pairs(comptime T: type, slice: []const T, allocator: std.mem.Allocator) ![]const [2]T {
    const n = slice.len;
    var result = try allocator.alloc([2]T, n * (n - 1) / 2);
    var i: usize = 0;
    var k: usize = 0;
    while (i < slice.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < slice.len) : ({
            j += 1;
            k += 1;
        }) {
            result[k] = .{ slice[i], slice[j] };
        }
    }
    return result;
}

test "set of unordered pairs from slice" {
    {
        const allocator = std.testing.allocator;
        const input: []const u8 = &.{ 0, 1, 2 };
        const expected: []const [2]u8 = &.{ .{ 0, 1 }, .{ 0, 2 }, .{ 1, 2 } };
        const actual = try pairs(u8, input, allocator);
        defer allocator.free(actual);

        try std.testing.expectEqualDeep(expected, actual);
    }
    {
        const allocator = std.testing.allocator;
        const input: []const u8 = &.{ 0, 1, 2, 3 };
        const expected: []const [2]u8 = &.{ .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 }, .{ 1, 2 }, .{ 1, 3 }, .{ 2, 3 } };
        const actual = try pairs(u8, input, allocator);
        defer allocator.free(actual);

        try std.testing.expectEqualDeep(expected, actual);
    }
}

test "it should work for small example" {
    const allocator = std.testing.allocator;
    const input: []const u8 =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(14, try problem.part1());
    try std.testing.expectEqual(34, try problem.part2());
}
