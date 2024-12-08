const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const State = enum { openMul, firstNum, comma, secondNum, closeMul };

fn peekLit(input: []const u8, lit: []const u8, index: u32) bool {
    var litIndex: u32 = 0;
    var inputIndex: u32 = index;
    while (inputIndex < input.len and litIndex < lit.len) {
        if (input[inputIndex] != lit[litIndex]) {
            break;
        }
        inputIndex += 1;
        litIndex += 1;
    }
    if (litIndex == lit.len) {
        return true;
    } else {
        return false;
    }
}

fn skipLit(input: []const u8, lit: []const u8, index: *u32) bool {
    if (peekLit(input, lit, index.*)) {
        index.* += @intCast(lit.len);
        return true;
    } else {
        index.* += 1;
        return false;
    }
}

fn num(input: []const u8, index: *u32, result: *u32) !bool {
    const startAt = index.*;
    var endAt = index.*;
    while (endAt < input.len and
        input[endAt] >= '0' and
        input[endAt] <= '9' and
        (endAt - startAt) < 3)
    {
        endAt += 1;
    }
    if ((endAt - startAt) > 0) {
        result.* = try std.fmt.parseInt(u32, input[startAt..endAt], 10);
        index.* = endAt;
        return true;
    } else {
        index.* += 1;
        return false;
    }
}

pub fn part1(this: *const @This()) !?i64 {
    var result: i64 = 0;
    var state: State = State.openMul;
    var firstNum: u32 = 0;
    var secondNum: u32 = 0;
    var i: u32 = 0;
    while (i < this.input.len) {
        switch (state) {
            State.openMul => {
                state = if (skipLit(this.input, "mul(", &i))
                    State.firstNum
                else
                    State.openMul;
            },
            State.closeMul => {
                if (skipLit(this.input, ")", &i)) {
                    result += firstNum * secondNum;
                }
                state = State.openMul;
            },
            State.firstNum => {
                state = if (try num(this.input, &i, &firstNum))
                    State.comma
                else
                    State.openMul;
            },
            State.secondNum => {
                state = if (try num(this.input, &i, &secondNum))
                    State.closeMul
                else
                    State.openMul;
            },
            State.comma => {
                state = if (skipLit(this.input, ",", &i))
                    State.secondNum
                else
                    State.openMul;
            },
        }
    }
    return result;
}

pub fn part2(this: *const @This()) !?i64 {
    var result: i64 = 0;
    var state: State = State.openMul;
    var firstNum: u32 = 0;
    var secondNum: u32 = 0;
    var enabled: bool = true;
    var i: u32 = 0;
    while (i < this.input.len) {
        if (enabled and peekLit(this.input, "don't()", i)) {
            _ = skipLit(this.input, "don't()", &i);
            enabled = false;
            continue;
        }
        if (!enabled and peekLit(this.input, "do()", i)) {
            _ = skipLit(this.input, "do()", &i);
            enabled = true;
            continue;
        }
        if (!enabled) {
            i += 1;
            continue;
        }
        switch (state) {
            State.openMul => {
                state = if (skipLit(this.input, "mul(", &i))
                    State.firstNum
                else
                    State.openMul;
            },
            State.closeMul => {
                if (skipLit(this.input, ")", &i)) {
                    result += firstNum * secondNum;
                }
                state = State.openMul;
            },
            State.firstNum => {
                state = if (try num(this.input, &i, &firstNum))
                    State.comma
                else
                    State.openMul;
            },
            State.secondNum => {
                state = if (try num(this.input, &i, &secondNum))
                    State.closeMul
                else
                    State.openMul;
            },
            State.comma => {
                state = if (skipLit(this.input, ",", &i))
                    State.secondNum
                else
                    State.openMul;
            },
        }
    }
    return result;
}

test "it should work on first small input" {
    const allocator = std.testing.allocator;
    const input = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))";

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(161, try problem.part1());
}

test "it should work on second small input" {
    const allocator = std.testing.allocator;
    const input = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(48, try problem.part2());
}
