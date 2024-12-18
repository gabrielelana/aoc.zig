const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

fn safetyFactor(robots: []const Robot, middleX: usize, middleY: usize) usize {
    var upperLeftQuadrant: usize = 0;
    var upperRightQuadrant: usize = 0;
    var lowerLeftQuadrant: usize = 0;
    var lowerRightQuadrant: usize = 0;
    for (robots) |robot| {
        if (robot.position[0] < middleX and robot.position[1] < middleY) {
            upperLeftQuadrant += 1;
        }
        if (robot.position[0] > middleX and robot.position[1] < middleY) {
            upperRightQuadrant += 1;
        }
        if (robot.position[0] < middleX and robot.position[1] > middleY) {
            lowerLeftQuadrant += 1;
        }
        if (robot.position[0] > middleX and robot.position[1] > middleY) {
            lowerRightQuadrant += 1;
        }
    }
    return upperLeftQuadrant * upperRightQuadrant * lowerLeftQuadrant * lowerRightQuadrant;
}

pub fn part1(this: *const @This()) !?i64 {
    var robots = std.ArrayList(Robot).init(this.allocator);
    defer robots.deinit();

    var lines = std.mem.splitScalar(u8, this.input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try robots.append(try Robot.parse(line));
    }

    const width: usize = if (this.input.len > 400) 101 else 11;
    const height: usize = if (this.input.len > 400) 103 else 7;
    const seconds = 100;

    var ticks: usize = 0;
    while (ticks < seconds) : (ticks += 1) {
        for (robots.items) |*robot| robot.tick(width, height);
    }

    const middleX = @divExact(width - 1, 2);
    const middleY = @divExact(height - 1, 2);
    return @intCast(safetyFactor(robots.items, middleX, middleY));
}

pub fn part2(this: *const @This()) !?i64 {
    var robots = std.ArrayList(Robot).init(this.allocator);
    defer robots.deinit();

    var lines = std.mem.splitScalar(u8, this.input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try robots.append(try Robot.parse(line));
    }

    const width: usize = 101;
    const height: usize = 103;
    const period: usize = width * height;

    var ticks: usize = 0;
    // const picture: []u8 = try this.allocator.alloc(u8, width * height);
    // defer this.allocator.free(picture);
    const middleX = @divExact(width - 1, 2);
    const middleY = @divExact(height - 1, 2);
    var minSf: usize = safetyFactor(robots.items, middleX, middleY);
    var result: usize = 0;
    while (ticks < period) : (ticks += 1) {
        for (robots.items) |*robot| robot.tick(width, height);
        const sf = safetyFactor(robots.items, middleX, middleY);
        if (sf < minSf) {
            // for (picture) |*pixel| pixel.* = ' ';
            // try display(picture, robots.items, ticks, width, height);
            minSf = sf;
            result = ticks + 1;
        }
    }

    return @intCast(result);
}

fn display(picture: []u8, robots: []const Robot, iteration: usize, width: usize, height: usize) !void {
    for (robots) |*robot| {
        picture[@as(usize, @intCast(robot.position[1] * @as(isize, @intCast(width)) + robot.position[0]))] = '*';
    }

    const out = std.io.getStdOut().writer();
    var buffer = std.io.bufferedWriter(out);
    var bufferedOut = buffer.writer();
    try bufferedOut.print("\x1B[2J", .{});
    try bufferedOut.print("iteration: {d}\n", .{iteration});

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            try bufferedOut.print("{c}", .{picture[y * width + x]});
        }
        try bufferedOut.print("\n", .{});
    }

    try buffer.flush();
    const stdin = std.io.getStdIn().reader();
    _ = try stdin.readByte();
}

const Position = @Vector(2, isize);
const Velocity = @Vector(2, isize);
const Robot = struct {
    const Self = @This();

    position: Position,
    velocity: Velocity,

    // p=0,4 v=3,-3
    fn parse(input: []const u8) !Self {
        var tokens = std.mem.splitAny(u8, input, "=, ");
        _ = tokens.next(); // discard `p`
        const px = try std.fmt.parseInt(isize, tokens.next().?, 10);
        const py = try std.fmt.parseInt(isize, tokens.next().?, 10);
        _ = tokens.next(); // discard `v`
        const vx = try std.fmt.parseInt(isize, tokens.next().?, 10);
        const vy = try std.fmt.parseInt(isize, tokens.next().?, 10);
        return Self{
            .position = .{ px, py },
            .velocity = .{ vx, vy },
        };
    }

    fn tick(robot: *Self, width: usize, height: usize) void {
        const limits: @Vector(2, isize) = .{ @intCast(width), @intCast(height) };
        robot.position = @rem(robot.position + robot.velocity, limits);
        if (robot.position[0] < 0) robot.position[0] += @intCast(width);
        if (robot.position[1] < 0) robot.position[1] += @intCast(height);
    }
};

test "should parse a robot" {
    const actual = try Robot.parse("p=0,4 v=3,-3");

    const expected = Robot{ .position = Position{ 0, 4 }, .velocity = Velocity{ 3, -3 } };

    try std.testing.expectEqual(expected, actual);
}

test "a robot should move in a grid wrapping around the limits" {
    const width = 11;
    const height = 7;
    var robot = Robot{ .position = Position{ 2, 4 }, .velocity = Velocity{ 2, -3 } };
    robot.tick(width, height);
    try std.testing.expectEqual(Position{ 4, 1 }, robot.position);
    robot.tick(width, height);
    try std.testing.expectEqual(Position{ 6, 5 }, robot.position);
    robot.tick(width, height);
    try std.testing.expectEqual(Position{ 8, 2 }, robot.position);
    robot.tick(width, height);
    try std.testing.expectEqual(Position{ 10, 6 }, robot.position);
    robot.tick(width, height);
    try std.testing.expectEqual(Position{ 1, 3 }, robot.position);
}

test "it should do nothing" {
    const allocator = std.testing.allocator;
    const input =
        \\p=0,4 v=3,-3
        \\p=6,3 v=-1,-3
        \\p=10,3 v=-1,2
        \\p=2,0 v=2,-1
        \\p=0,0 v=1,3
        \\p=3,0 v=-2,-2
        \\p=7,6 v=-1,-3
        \\p=3,0 v=-1,-2
        \\p=9,3 v=2,3
        \\p=7,3 v=-1,2
        \\p=2,4 v=2,-3
        \\p=9,5 v=-3,-3
        \\
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(12, try problem.part1());
    // try std.testing.expectEqual(null, try problem.part2());
}
