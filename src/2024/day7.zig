const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

inline fn concat(x: usize, y: usize) usize {
    const digits: usize = std.math.log10(if (y == 0) 1 else y) + 1;
    return (x * std.math.pow(usize, 10, digits)) + y;
}

fn canSumOrMultiplyUpTo(numbers: []const usize, total: usize, partial: ?usize) bool {
    if (partial != null and partial.? > total) return false;
    if (numbers.len == 0) return partial == total;
    if (partial == null) {
        return canSumOrMultiplyUpTo(numbers[1..], total, numbers[0]);
    }
    return canSumOrMultiplyUpTo(numbers[1..], total, partial.? * numbers[0]) or
        canSumOrMultiplyUpTo(numbers[1..], total, partial.? + numbers[0]);
}

fn canSumOrMultiplyOrConcatUpTo(numbers: []const usize, total: usize, partial: ?usize) bool {
    if (partial != null and partial.? > total) return false;
    if (numbers.len == 0) return partial == total;
    if (partial == null) {
        return canSumOrMultiplyOrConcatUpTo(numbers[1..], total, numbers[0]);
    }
    const n = concat(partial.?, numbers[0]);
    if (n <= total and canSumOrMultiplyOrConcatUpTo(numbers[1..], total, n)) {
        return true;
    }
    return canSumOrMultiplyOrConcatUpTo(numbers[1..], total, partial.? * numbers[0]) or
        canSumOrMultiplyOrConcatUpTo(numbers[1..], total, partial.? + numbers[0]);
}

pub fn solve(this: *const @This(), f: fn ([]const usize, usize, ?usize) bool) !?i64 {
    var result: usize = 0;
    var numbers = try this.allocator.alloc(usize, 32);
    defer this.allocator.free(numbers);
    var lines = std.mem.splitScalar(u8, this.input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.splitAny(u8, line, ": ");
        const total = try std.fmt.parseInt(usize, tokens.next().?, 10);
        _ = tokens.next();
        var i: usize = 0;
        while (tokens.next()) |token| : (i += 1) {
            numbers[i] = try std.fmt.parseInt(usize, token, 10);
        }
        if (f(numbers[0..i], total, null)) {
            result += total;
        }
    }
    return @intCast(result);
}

pub fn part1(this: *const @This()) !?i64 {
    return solve(this, canSumOrMultiplyUpTo);
}

pub fn part2(this: *const @This()) !?i64 {
    return solve(this, canSumOrMultiplyOrConcatUpTo);
}

test "it should work with small example" {
    const allocator = std.testing.allocator;
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(3749, try problem.part1());
    try std.testing.expectEqual(11387, try problem.part2());
}

test "canSumOrMultiplyUpTo" {
    const numbers1 = [_]usize{ 19, 10 };
    try std.testing.expect(canSumOrMultiplyUpTo(&numbers1, 190, null));

    const numbers2 = [_]usize{ 81, 40, 27 };
    try std.testing.expect(canSumOrMultiplyUpTo(&numbers2, 3267, null));

    const numbers3 = [_]usize{ 17, 5 };
    try std.testing.expect(!canSumOrMultiplyUpTo(&numbers3, 83, null));

    const numbers4 = [_]usize{ 9, 7, 18, 13 };
    try std.testing.expect(!canSumOrMultiplyUpTo(&numbers4, 21037, null));

    const numbers5 = [_]usize{ 11, 6, 16, 20 };
    try std.testing.expect(canSumOrMultiplyUpTo(&numbers5, 292, null));
}

test "canSumOrMultiplyOrConcatUpTo" {
    const numbers1 = [_]usize{ 15, 6 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers1, 156, null));

    const numbers2 = [_]usize{ 6, 8, 6, 15 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers2, 7290, null));

    const numbers3 = [_]usize{ 1, 12, 7 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers3, 127, null));

    const numbers31 = [_]usize{ 0, 12, 7 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers31, 127, null));

    const numbers4 = [_]usize{ 1, 99, 2, 1 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers4, 992, null));

    const numbers41 = [_]usize{ 0, 99, 2, 1 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers41, 992, null));

    const numbers42 = [_]usize{ 0, 99, 2, 0 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers42, 992, null));

    const numbers43 = [_]usize{ 1, 99, 2, 0 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers43, 992, null));

    const numbers5 = [_]usize{ 1, 7, 99, 1 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers5, 799, null));

    const numbers6 = [_]usize{ 1, 7, 17, 1 };
    try std.testing.expect(canSumOrMultiplyOrConcatUpTo(&numbers6, 717, null));
}

test "concat" {
    try std.testing.expectEqual(992, concat(99, 2));
    try std.testing.expectEqual(992, concat(9, 92));
    try std.testing.expectEqual(799, concat(7, 99));
    try std.testing.expectEqual(717, concat(7, 17));
}
