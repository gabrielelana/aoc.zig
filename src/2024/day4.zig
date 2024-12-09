const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const needle = "XMAS";

// TODO: how to improve
// - Create a type WordWall
// - With function charAT
// - With function wordAtWithDirection
// - Union Direction with .{dx, dy}
// - With function wordAt in every direction
// - With function crossWordAt

fn countWordsAtWithDirection(input: []const u8, nColumns: usize, x: isize, y: isize, dx: isize, dy: isize) bool {
    var i: usize = 0;
    while (i < needle.len) : (i += 1) {
        var ddx: isize = 0;
        var ddy: isize = 0;
        if (dx != 0) {
            ddx = if (dx > 0) @as(isize, @intCast(i)) else -@as(isize, @intCast(i));
        }
        if (dy != 0) {
            ddy = if (dy > 0) @as(isize, @intCast(i)) else -@as(isize, @intCast(i));
        }
        const at = (y + ddy) * @as(isize, @intCast(nColumns)) + x + ddx;
        if (at < 0 or at >= input.len) break;
        if (input[@as(usize, @intCast(at))] != needle[i]) break;
    }
    return i == needle.len;
}

fn countWordsAt(input: []const u8, nColumns: usize, x: isize, y: isize) usize {
    var nFound: usize = 0;
    if (countWordsAtWithDirection(input, nColumns, x, y, 1, 0)) nFound += 1;
    if (countWordsAtWithDirection(input, nColumns, x, y, -1, 0)) nFound += 1;
    if (countWordsAtWithDirection(input, nColumns, x, y, 0, -1)) nFound += 1;
    if (countWordsAtWithDirection(input, nColumns, x, y, 0, 1)) nFound += 1;
    if (countWordsAtWithDirection(input, nColumns, x, y, 1, -1)) nFound += 1;
    if (countWordsAtWithDirection(input, nColumns, x, y, -1, 1)) nFound += 1;
    if (countWordsAtWithDirection(input, nColumns, x, y, -1, -1)) nFound += 1;
    if (countWordsAtWithDirection(input, nColumns, x, y, 1, 1)) nFound += 1;
    return nFound;
}

fn countWords(input: []const u8, nLines: usize, nColumns: usize) usize {
    var result: usize = 0;
    var x: isize = 0;
    var y: isize = 0;
    while (y < nLines) : (y += 1) {
        while (x < nColumns) : (x += 1) {
            const n = countWordsAt(input, nColumns, x, y);
            result += n;
        }
        x = 0;
    }
    return result;
}

pub fn part1(this: *const @This()) !?i64 {
    var lines = std.mem.splitScalar(u8, this.input, '\n');
    const firstLine = lines.next();
    const nColumns: usize = firstLine.?.len + 1;
    const nLines: usize = @truncate((this.input.len + 1) / nColumns);
    return @intCast(countWords(this.input, nLines, nColumns));
}

fn checkCharAt(input: []const u8, nColumns: usize, x: isize, y: isize, char: u8) bool {
    const at = y * @as(isize, @intCast(nColumns)) + x;
    if (at < 0 or at >= input.len) return false;
    if (input[@as(usize, @intCast(at))] != char) return false;
    return true;
}

fn checkXAt(input: []const u8, nColumns: usize, x: isize, y: isize) bool {
    return checkCharAt(input, nColumns, x, y, 'A') and
        ((checkCharAt(input, nColumns, x - 1, y - 1, 'M') and
        checkCharAt(input, nColumns, x + 1, y + 1, 'S')) or
        (checkCharAt(input, nColumns, x - 1, y - 1, 'S') and
        checkCharAt(input, nColumns, x + 1, y + 1, 'M'))) and
        ((checkCharAt(input, nColumns, x + 1, y - 1, 'M') and
        checkCharAt(input, nColumns, x - 1, y + 1, 'S')) or
        (checkCharAt(input, nColumns, x + 1, y - 1, 'S') and
        checkCharAt(input, nColumns, x - 1, y + 1, 'M')));
}

pub fn part2(this: *const @This()) !?i64 {
    var lines = std.mem.splitScalar(u8, this.input, '\n');
    const firstLine = lines.next();
    const nColumns: usize = firstLine.?.len + 1;
    const nLines: usize = @truncate((this.input.len + 1) / nColumns);
    var result: usize = 0;
    var x: isize = 0;
    var y: isize = 0;
    while (y < nLines) : (y += 1) {
        while (x < nColumns) : (x += 1) {
            if (checkXAt(this.input, nColumns, x, y)) {
                result += 1;
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

test "it should recognize XMAS in all cases" {
    var input: []const u8 = "";

    input = "XMAS";
    try std.testing.expectEqual(1, countWords(input, 1, input.len + 1));

    input = ".XMA";
    try std.testing.expectEqual(0, countWords(input, 1, input.len + 1));

    input = "SAMX";
    try std.testing.expectEqual(1, countWords(input, 1, input.len + 1));

    input = "XMASAMX";
    try std.testing.expectEqual(2, countWords(input, 1, input.len + 1));

    input =
        \\XMAS
        \\....
    ;
    try std.testing.expectEqual(1, countWords(input, 2, 5));

    input =
        \\.XMA
        \\S...
    ;
    try std.testing.expectEqual(0, countWords(input, 2, 5));

    input =
        \\....
        \\XMAS
    ;
    try std.testing.expectEqual(1, countWords(input, 2, 5));

    input =
        \\X...
        \\M...
        \\A...
        \\S...
    ;
    try std.testing.expectEqual(1, countWords(input, 4, 5));

    input =
        \\...X
        \\...M
        \\...A
        \\...S
    ;
    try std.testing.expectEqual(1, countWords(input, 4, 5));
}
