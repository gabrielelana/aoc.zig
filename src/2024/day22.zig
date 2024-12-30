const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

// To mix a value into the secret number, calculate the bitwise XOR of the given
// value and the secret number. Then, the secret number becomes the result of
// that operation. (If the secret number is 42 and you were to mix 15 into the
// secret number, the secret number would become 37.)
fn mix(secret: usize, n: usize) usize {
    return secret ^ n;
}

test mix {
    try std.testing.expectEqual(37, mix(42, 15));
}

// To prune the secret number, calculate the value of the secret number modulo
// 16777216. Then, the secret number becomes the result of that operation. (If
// the secret number is 100000000 and you were to prune the secret number, the
// secret number would become 16113920.)
fn prune(secret: usize) usize {
    return @mod(secret, 16777216);
}

test prune {
    try std.testing.expectEqual(16113920, prune(100000000));
}

fn next(secret: usize) usize {
    // Calculate the result of multiplying the secret number by 64. Then, mix
    // this result into the secret number. Finally, prune the secret number.
    const n1 = prune(mix(secret, secret * 64));

    // Calculate the result of dividing the secret number by 32. Round the result
    // down to the nearest integer. Then, mix this result into the secret number.
    // Finally, prune the secret number.
    const n2 = prune(mix(n1, @divFloor(n1, 32)));

    // Calculate the result of multiplying the secret number by 2048. Then, mix this
    // result into the secret number. Finally, prune the secret number.
    const n3 = prune(mix(n2, n2 * 2048));

    return n3;
}

test next {
    try std.testing.expectEqual(15887950, next(123));
    try std.testing.expectEqual(16495136, next(15887950));
    try std.testing.expectEqual(527345, next(16495136));
    try std.testing.expectEqual(704524, next(527345));
    try std.testing.expectEqual(1553684, next(704524));
    try std.testing.expectEqual(12683156, next(1553684));
    try std.testing.expectEqual(11100544, next(12683156));
    try std.testing.expectEqual(12249484, next(11100544));
    try std.testing.expectEqual(7753432, next(12249484));
    try std.testing.expectEqual(5908254, next(7753432));
}

fn nextNth(secret: usize, nth: usize) usize {
    var result = secret;
    for (0..nth) |_| {
        result = next(result);
    }
    return result;
}

test nextNth {
    try std.testing.expectEqual(8685429, nextNth(1, 2000));
    try std.testing.expectEqual(4700978, nextNth(10, 2000));
    try std.testing.expectEqual(15273692, nextNth(100, 2000));
    try std.testing.expectEqual(8667524, nextNth(2024, 2000));
}

pub fn part1(this: *const @This()) !?i64 {
    const iterations = 2000;
    var lines = std.mem.splitScalar(u8, this.input, '\n');
    var result: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const secret = try std.fmt.parseInt(usize, line, 10);
        result += nextNth(secret, iterations);
    }
    return @intCast(result);
}

// Since the difference between single digit prices can be only between -9 and
// 9, to represent a single difference we need to represent 19 values, to do
// that only need 5 bits (2^5 = 32), therefore to represent a sequence of four
// differences we will need 20 bits, an `u20` will do.
//
// But, a sequence can only be used if completely filled, anche since `0` is a
// valid number we will use another bit as a marker to mark if a value has been
// filled or not, at the end we will need 24 bits, aka an `u24` will be our hash
// for the four prices difference sequence.
const Sequence = struct {
    const Self = @This();
    const MARKER = 0b100000;
    const FILLED = MARKER | MARKER << 6 | MARKER << 12 | MARKER << 18;

    value: u24,

    fn empty() Self {
        return Self{
            .value = 0,
        };
    }

    fn append(self: *Self, n: u5) void {
        self.value = (self.value << 6) | n | MARKER;
    }

    fn valueAt(self: Self, comptime position: u24) u5 {
        comptime {
            if (position > 3) {
                @compileError("`position` value must be between 0 and 3");
            }
        }
        const shift: u24 = 6 * position;
        return @intCast((self.value & (0b011111 << shift)) >> shift);
    }

    fn isFilled(self: Self) bool {
        return (self.value & FILLED) == FILLED;
    }
};

test Sequence {
    var s = Sequence.empty();
    try std.testing.expect(!s.isFilled());

    s.append(1);
    try std.testing.expectEqual(1, s.valueAt(0));
    try std.testing.expect(!s.isFilled());

    s.append(2);
    try std.testing.expectEqual(2, s.valueAt(0));
    try std.testing.expectEqual(1, s.valueAt(1));
    try std.testing.expect(!s.isFilled());

    s.append(3);
    try std.testing.expectEqual(3, s.valueAt(0));
    try std.testing.expectEqual(2, s.valueAt(1));
    try std.testing.expectEqual(1, s.valueAt(2));
    try std.testing.expect(!s.isFilled());

    s.append(4);
    try std.testing.expectEqual(4, s.valueAt(0));
    try std.testing.expectEqual(3, s.valueAt(1));
    try std.testing.expectEqual(2, s.valueAt(2));
    try std.testing.expectEqual(1, s.valueAt(3));
    try std.testing.expect(s.isFilled());

    s.append(5);
    try std.testing.expectEqual(5, s.valueAt(0));
    try std.testing.expectEqual(4, s.valueAt(1));
    try std.testing.expectEqual(3, s.valueAt(2));
    try std.testing.expectEqual(2, s.valueAt(3));
    try std.testing.expect(s.isFilled());
}

fn hash(n1: usize, n2: usize, sequence: *Sequence) usize {
    const p1: u5 = @intCast(@mod(n1, 10));
    const p2: u5 = @intCast(@mod(n2, 10));
    sequence.append(p2 + 9 - p1);
    return n2;
}

test hash {
    var s = Sequence.empty();
    var secret: usize = 123;

    secret = hash(secret, 15887950, &s);
    // 1588795(0) - 12(3) = -3
    try std.testing.expectEqual(-3 + 9, s.valueAt(0));

    secret = hash(secret, 16495136, &s);
    // 16495136(6) - 1588795(0) = 6
    try std.testing.expectEqual(6 + 9, s.valueAt(0));

    secret = hash(secret, 527345, &s);
    // 52734(5) - 16495136(6) = -1
    try std.testing.expectEqual(-1 + 9, s.valueAt(0));

    secret = hash(secret, 704524, &s);
    // 6495136(4) - 52734(5) = -1
    try std.testing.expectEqual(-1 + 9, s.valueAt(0));

    try std.testing.expect(s.isFilled());
}

const SequenceSet = std.HashMap(Sequence, void, std.hash_map.AutoContext(Sequence), std.hash_map.default_max_load_percentage);
const SequenceMax = std.HashMap(Sequence, usize, std.hash_map.AutoContext(Sequence), std.hash_map.default_max_load_percentage);

pub fn part2(this: *const @This()) !?i64 {
    const iterations = 2000;
    var lines = std.mem.splitScalar(u8, this.input, '\n');
    var result: usize = 0;

    // Keep the map between a sequence and the sum of the buyer's prices for
    // that sequence, the max accumulated value at the end is the result;
    var sequenceToSum = SequenceMax.init(this.allocator);
    defer sequenceToSum.deinit();

    // For every buyer we keep track of the sequences already seen, so that we
    // will only consider a sequence if seen for the first time
    var alreadySeen = SequenceSet.init(this.allocator);
    defer alreadySeen.deinit();

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // For every buyer we start from scratch with the seen sequences
        alreadySeen.clearRetainingCapacity();

        // Start with the initial secret and an empty sequence
        var secret = try std.fmt.parseInt(usize, line, 10);
        var sequence = Sequence.empty();

        for (0..iterations) |_| {
            secret = hash(secret, next(secret), &sequence);
            if (alreadySeen.contains(sequence)) continue;
            if (sequence.isFilled()) {
                try alreadySeen.put(sequence, undefined);
                const entry = try sequenceToSum.getOrPut(sequence);
                if (!entry.found_existing) {
                    entry.value_ptr.* = 0;
                }
                entry.value_ptr.* += @mod(secret, 10);
                result = @max(entry.value_ptr.*, result);
            }
        }
    }

    return @intCast(result);
}

test "it should work with a small example for part1" {
    const allocator = std.testing.allocator;
    const input =
        \\1
        \\10
        \\100
        \\2024
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(37327623, try problem.part1());
}

test "it should work with a small example for part2" {
    const allocator = std.testing.allocator;
    const input =
        \\1
        \\2
        \\3
        \\2024
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(23, try problem.part2());
}
