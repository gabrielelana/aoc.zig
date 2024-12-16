const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const Numbers = std.ArrayList(usize);
const Evolution = struct { n: usize, blinks: usize };
const Cache = std.HashMap(Evolution, usize, std.hash_map.AutoContext(Evolution), std.hash_map.default_max_load_percentage);

pub fn part1(this: *const @This()) !?i64 {
    return @intCast(try solve(25, this.input, this.allocator));
}

pub fn part2(this: *const @This()) !?i64 {
    return @intCast(try solve(75, this.input, this.allocator));
}

fn solve(blinks: usize, input: []const u8, allocator: std.mem.Allocator) !usize {
    const numbers = try parse(input, allocator);
    defer allocator.free(numbers);

    var cache = Cache.init(allocator);
    defer cache.deinit();

    return @intCast(try evolveAll(numbers, blinks, &cache));
}

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]const usize {
    var numbers = Numbers.init(allocator);
    var tokens = std.mem.splitAny(u8, input, " \n");
    while (tokens.next()) |token| {
        if (token.len == 0) continue;
        try numbers.append(try std.fmt.parseInt(usize, token, 10));
    }
    return numbers.toOwnedSlice();
}

fn evolveAll(ns: []const usize, blinks: usize, cache: *Cache) !usize {
    var result: usize = 0;
    for (ns) |n| {
        result += try evolve(n, blinks, cache);
    }
    return @intCast(result);
}

fn evolve(n: usize, blinks: usize, cache: *Cache) !usize {
    // if blinks todo reached the end we are finished
    if (blinks == 0) return 1;
    const evolution = Evolution{ .n = n, .blinks = blinks };
    // check if result is already in cache
    if (cache.get(evolution)) |count| return count;
    // first evolution case
    if (n == 0) {
        const count = try evolve(1, blinks - 1, cache);
        try cache.put(evolution, count);
        return count;
    }
    // second evolution case
    {
        var buffer: [64:0]u8 = .{0} ** 64;
        const written = try std.fmt.bufPrint(&buffer, "{d}", .{n});
        if ((written.len % 2) == 0) {
            const half = @divExact(written.len, 2);
            const left = try std.fmt.parseInt(usize, written[0..half], 10);
            const right = try std.fmt.parseInt(usize, written[half..], 10);
            const count = try evolve(left, blinks - 1, cache) + try evolve(right, blinks - 1, cache);
            try cache.put(evolution, count);
            return count;
        }
    }
    // third evolution case
    {
        const count = try evolve(n * 2024, blinks - 1, cache);
        try cache.put(evolution, count);
        return count;
    }
}

test "it should evolve with cache" {
    var cache = Cache.init(std.testing.allocator);
    defer cache.deinit();

    try std.testing.expectEqual(2, evolve(99, 1, &cache));
    try std.testing.expectEqual(1, evolve(0, 1, &cache));
    try std.testing.expectEqual(1, evolve(1, 1, &cache));

    try std.testing.expectEqual(2, evolve(99, 2, &cache));
    try std.testing.expectEqual(2, evolve(99, 3, &cache));
    try std.testing.expectEqual(4, evolve(99, 4, &cache));
}

test "it should work for small example" {
    const allocator = std.testing.allocator;
    const input = "125 17";

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(55312, try problem.part1());
}
