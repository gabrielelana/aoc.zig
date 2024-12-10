const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const needle = "XMAS";

const Direction = struct {
    dx: i8,
    dy: i8,
};

const Position = struct {
    const Self = @This();

    x: usize,
    y: usize,

    fn apply(self: Self, d: Direction) ?Self {
        const x = @as(isize, @intCast(self.x)) + d.dx;
        const y = @as(isize, @intCast(self.y)) + d.dx;
        if (x < 0 or y < 0) return null;
        return Position{
            .x = @as(usize, @intCast(x)),
            .y = @as(usize, @intCast(y)),
        };
    }
};

fn combineDirections(l: Direction, r: Direction) Direction {
    return Direction{ .dx = l.dx + r.dx, .dy = l.dy + r.dy };
}

const Directions = .{
    .up = @as(Direction, .{ .dx = 0, .dy = -1 }),
    .down = @as(Direction, .{ .dx = 0, .dy = 1 }),
    .left = @as(Direction, .{ .dx = -1, .dy = 0 }),
    .right = @as(Direction, .{ .dx = 1, .dy = 0 }),
};

const WordWall = struct {
    const Self = @This();

    input: []const u8,
    limits: Position,

    fn init(input: []const u8) Self {
        var lines = std.mem.splitScalar(u8, input, '\n');
        const firstLine = lines.next();
        const countColumns = firstLine.?.len + 1;
        return Self{
            .input = input,
            .limits = .{
                .x = countColumns,
                .y = @truncate((input.len + 1) / countColumns),
            },
        };
    }

    fn charAt(self: Self, p: ?Position) ?u8 {
        if (p == null) return null;
        const at = (p.?.y * self.limits.x) + p.?.x;
        if (at >= self.input.len) return null;
        return self.input[at];
    }

    fn hasWordAtDirection(self: Self, word: []const u8, p: Position, d: Direction) bool {
        var i: usize = 0;
        var currentPosition: Position = p;
        while (i < word.len) : (i += 1) {
            if (self.charAt(currentPosition) != word[i]) break;
            const x = @as(isize, @intCast(currentPosition.x)) + d.dx;
            const y = @as(isize, @intCast(currentPosition.y)) + d.dy;
            if (x >= 0 and y >= 0) {
                currentPosition = Position{ .x = @as(usize, @intCast(x)), .y = @as(usize, @intCast(y)) };
            }
        }
        return i == needle.len;
    }

    fn countWordsAt(self: Self, word: []const u8, p: Position) u8 {
        var result: u8 = 0;
        if (self.hasWordAtDirection(word, p, Directions.up)) result += 1;
        if (self.hasWordAtDirection(word, p, Directions.down)) result += 1;
        if (self.hasWordAtDirection(word, p, Directions.left)) result += 1;
        if (self.hasWordAtDirection(word, p, Directions.right)) result += 1;
        if (self.hasWordAtDirection(word, p, combineDirections(Directions.up, Directions.right))) result += 1;
        if (self.hasWordAtDirection(word, p, combineDirections(Directions.up, Directions.left))) result += 1;
        if (self.hasWordAtDirection(word, p, combineDirections(Directions.down, Directions.right))) result += 1;
        if (self.hasWordAtDirection(word, p, combineDirections(Directions.down, Directions.left))) result += 1;
        return result;
    }

    fn countWords(self: Self, word: []const u8) usize {
        var result: usize = 0;
        var x: usize = 0;
        var y: usize = 0;
        while (y < self.limits.y) : (y += 1) {
            while (x < self.limits.x) : (x += 1) {
                result += self.countWordsAt(word, .{ .x = x, .y = y });
            }
            x = 0;
        }
        return result;
    }
};

pub fn part1(this: *const @This()) !?i64 {
    return @intCast(WordWall.init(this.input).countWords("XMAS"));
}

pub fn part2(this: *const @This()) !?i64 {
    const ww = WordWall.init(this.input);
    var result: usize = 0;
    var x: usize = 0;
    var y: usize = 0;
    while (y < ww.limits.y) : (y += 1) {
        while (x < ww.limits.x) : (x += 1) {
            const at = Position{ .x = x, .y = y };
            if (ww.charAt(at) == 'A') {
                if ((ww.charAt(at.apply(combineDirections(Directions.up, Directions.left))) == 'M' and
                    ww.charAt(at.apply(combineDirections(Directions.down, Directions.right))) == 'S') or
                    (ww.charAt(at.apply(combineDirections(Directions.up, Directions.left))) == 'S' and
                    ww.charAt(at.apply(combineDirections(Directions.down, Directions.right))) == 'M') or
                    (ww.charAt(at.apply(combineDirections(Directions.up, Directions.right))) == 'M' and
                    ww.charAt(at.apply(combineDirections(Directions.down, Directions.left))) == 'S') or
                    (ww.charAt(at.apply(combineDirections(Directions.up, Directions.right))) == 'S' and
                    ww.charAt(at.apply(combineDirections(Directions.down, Directions.left))) == 'M'))
                {
                    result += 1;
                }
            }
        }
        x = 0;
    }
    return @intCast(result);
}

test "it should work with small examples for part 1" {
    const allocator = std.testing.allocator;
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(18, try problem.part1());
}

test "it should work with small examples for part 2" {
    const allocator = std.testing.allocator;
    const input =
        \\.M.S......
        \\..A..MSMS.
        \\.M.S.MAA..
        \\..A.ASMSM.
        \\.M.S.M....
        \\..........
        \\S.S.S.S.S.
        \\.A.A.A.A..
        \\M.M.M.M.M.
        \\..........
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(9, try problem.part2());
}
