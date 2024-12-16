const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

// Consider it a system of equations

// Button A: X+a1, Y+a2
// Button B: X+b1, Y+b2
// Prize: X=c1, Y=c2

// a1x + b1y = c1 -> a1x + b1y - c1 = 0
// a2x + b2y = c2 -> a2x + b2y - c2 = 0

// x will be how many times we should press button A
// y will be how many times we should press button B

// x = (b1c2-b2c1)/(a1b2-a2b1)
// y = (c1a2-c2a1)/(a1b2-a2b1)

const Equation = struct { a: isize, b: isize, c: isize };
const System = struct { Equation, Equation };
const Solution = struct { x: isize, y: isize };

// Button A: X+a1, Y+a2
fn parseButton(line: []const u8) !struct { isize, isize } {
    var tokens: std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar) = undefined;
    tokens = std.mem.splitScalar(u8, line, ':');
    _ = tokens.next();
    tokens = std.mem.splitScalar(u8, tokens.next().?, ',');
    const xPart = tokens.next().?; // X+n
    const yPart = tokens.next().?; // Y+n
    tokens = std.mem.splitScalar(u8, xPart, '+');
    _ = tokens.next();
    const x = try std.fmt.parseInt(isize, tokens.next().?, 10);
    tokens = std.mem.splitScalar(u8, yPart, '+');
    _ = tokens.next();
    const y = try std.fmt.parseInt(isize, tokens.next().?, 10);
    return .{ x, y };
}

// Prize: X=c1, Y=c2
fn parsePrize(line: []const u8) !struct { isize, isize } {
    var tokens: std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar) = undefined;
    tokens = std.mem.splitScalar(u8, line, ':');
    _ = tokens.next();
    tokens = std.mem.splitScalar(u8, tokens.next().?, ',');
    const xPart = tokens.next().?; // X+n
    const yPart = tokens.next().?; // Y+n
    tokens = std.mem.splitScalar(u8, xPart, '=');
    _ = tokens.next();
    const x = try std.fmt.parseInt(isize, tokens.next().?, 10);
    tokens = std.mem.splitScalar(u8, yPart, '=');
    _ = tokens.next();
    const y = try std.fmt.parseInt(isize, tokens.next().?, 10);
    return .{ x, y };
}

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]System {
    var systems = std.ArrayList(System).init(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.peek() != null) {
        const ax, const ay = try parseButton(lines.next().?);
        const bx, const by = try parseButton(lines.next().?);
        const px, const py = try parsePrize(lines.next().?);
        _ = lines.next().?; // newline after block
        try systems.append(System{
            Equation{ .a = ax, .b = bx, .c = px },
            Equation{ .a = ay, .b = by, .c = py },
        });
    }
    return systems.toOwnedSlice();
}

fn solve(a1: isize, b1: isize, c1: isize, a2: isize, b2: isize, c2: isize) ?Solution {
    const x = @as(f64, @floatFromInt(b1 * c2 - b2 * c1)) / @as(f64, @floatFromInt(a1 * b2 - a2 * b1));
    const y = @as(f64, @floatFromInt(c1 * a2 - c2 * a1)) / @as(f64, @floatFromInt(a1 * b2 - a2 * b1));
    if (@trunc(x) == x and @trunc(y) == y) {
        return Solution{ .x = @as(isize, @intFromFloat(x)), .y = @as(isize, @intFromFloat(y)) };
    }
    return null;
}

pub fn part1(this: *const @This()) !?i64 {
    const systems = try parse(this.input, this.allocator);
    defer this.allocator.free(systems);

    var result: isize = 0;
    for (systems) |system| {
        const eq1, const eq2 = system;
        const solution = solve(eq1.a, eq1.b, -eq1.c, eq2.a, eq2.b, -eq2.c);
        if (solution != null) {
            result += solution.?.x * 3 + solution.?.y;
        }
    }
    return @intCast(result);
}

pub fn part2(this: *const @This()) !?i64 {
    const systems = try parse(this.input, this.allocator);
    defer this.allocator.free(systems);

    const delta = 10000000000000;
    var result: isize = 0;
    for (systems) |system| {
        const eq1, const eq2 = system;
        const solution = solve(eq1.a, eq1.b, -(eq1.c + delta), eq2.a, eq2.b, -(eq2.c + delta));
        if (solution != null) {
            result += solution.?.x * 3 + solution.?.y;
        }
    }
    return @intCast(result);
}

test "it should solve a system of equation" {
    // Button A: X+94, Y+34
    // Button B: X+22, Y+67
    // Prize: X=8400, Y=5400
    try std.testing.expectEqual(Solution{ .x = 80, .y = 40 }, solve(94, 22, -8400, 34, 67, -5400));
    // Button A: X+26, Y+66
    // Button B: X+67, Y+21
    // Prize: X=12748, Y=12176
    try std.testing.expectEqual(null, solve(26, 67, -12748, 66, 21, -12176));
    // Button A: X+17, Y+86
    // Button B: X+84, Y+37
    // Prize: X=7870, Y=6450
    try std.testing.expectEqual(Solution{ .x = 38, .y = 86 }, solve(17, 84, -7870, 86, 37, -6450));
    // Button A: X+69, Y+23
    // Button B: X+27, Y+71
    // Prize: X=18641, Y=10279
    try std.testing.expectEqual(null, solve(69, 27, -18641, 23, 71, -10279));
}

test "it should parse input" {
    const input =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
    ;
    const actual = try parse(input, std.testing.allocator);
    defer std.testing.allocator.free(actual);

    const expected = System{
        Equation{ .a = 94, .b = 22, .c = 8400 },
        Equation{ .a = 34, .b = 67, .c = 5400 },
    };

    try std.testing.expectEqual(1, actual.len);
    try std.testing.expectEqual(expected, actual[0]);
}

test "it should work with small examples" {
    const allocator = std.testing.allocator;
    const input =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
        \\
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(480, try problem.part1());
    try std.testing.expectEqual(875318608908, try problem.part2());
}
