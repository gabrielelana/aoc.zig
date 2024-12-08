const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const SafetyCheck = union(enum) { safe: void, unsafe: u8 };

fn isSafe(report: []const u8, skipAt: ?u8) !SafetyCheck {
    var lastLevel: ?i16 = null;
    var lastDiff: ?i32 = null;
    var count: u8 = 0;
    var levels = std.mem.splitScalar(u8, report, ' ');
    while (levels.next()) |levelAsString| : (count += 1) {
        if (skipAt != null and skipAt.? == count) continue;
        const level = try std.fmt.parseInt(i16, levelAsString, 10);
        if (lastLevel == null) {
            lastLevel = level;
            continue;
        }
        const diff: i32 = lastLevel.? - level;
        if (lastDiff != null) {
            if ((diff < 0 and lastDiff.? > 0) or (diff > 0 and lastDiff.? < 0)) {
                return SafetyCheck{ .unsafe = count };
            }
        }
        if (@abs(diff) < 1 or @abs(diff) > 3) {
            return SafetyCheck{ .unsafe = count };
        }
        lastLevel = level;
        lastDiff = diff;
    }
    return SafetyCheck{ .safe = undefined };
}

pub fn part1(this: *const @This()) !?i64 {
    var reports = std.mem.splitScalar(u8, this.input, '\n');
    var countSafeReports: i64 = 0;
    while (reports.next()) |line| {
        if (line.len == 0) continue;
        switch (try isSafe(line, null)) {
            .safe => countSafeReports += 1,
            .unsafe => undefined,
        }
    }
    return countSafeReports;
}

pub fn part2(this: *const @This()) !?i64 {
    var reports = std.mem.splitScalar(u8, this.input, '\n');
    var countSafeReports: i64 = 0;
    while (reports.next()) |line| {
        if (line.len == 0) continue;
        var skipAt: ?u8 = null;
        while (true) {
            switch (try isSafe(line, skipAt)) {
                .safe => {
                    countSafeReports += 1;
                    break;
                },
                .unsafe => {
                    skipAt = if (skipAt == null) 0 else skipAt.? + 1;
                    if (skipAt.? > 7) break;
                },
            }
        }
    }
    return countSafeReports;
}

// TODO: can I run the test with the actual input???
// test "it should work" {
//     const allocator = std.testing.allocator;

//     const problem: @This() = .{
//         TODO: why I cannot do something like this?
//         .input = @import("input"),
//         .allocator = allocator,
//     };

//     try std.testing.expectEqual(534, try problem.part1());
//     try std.testing.expectEqual(null, try problem.part2());
// }

test "it should work with small example" {
    const allocator = std.testing.allocator;
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(2, try problem.part1());
    try std.testing.expectEqual(4, try problem.part2());
}
