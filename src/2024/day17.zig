const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const Program = []const u8;

const ADV = 0b000;
const BXL = 0b001;
const BST = 0b010;
const JNZ = 0b011;
const BXC = 0b100;
const OUT = 0b101;
const BDV = 0b110;
const CVD = 0b111;

const CPU = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    program: Program,
    ip: usize,
    a: usize,
    b: usize,
    c: usize,

    fn parse(input: []const u8, allocator: std.mem.Allocator) !CPU {
        var lines = std.mem.splitScalar(u8, input, '\n');
        var registers: [3]usize = .{ 0, 0, 0 };
        for (0..3) |i| {
            const line = lines.next().?;
            var tokens = std.mem.splitSequence(u8, line, ": ");
            _ = tokens.next().?; // skip `Register N`
            registers[i] = try std.fmt.parseInt(usize, tokens.next().?, 10);
        }
        _ = lines.next().?; // skip empty line

        const line = lines.next().?;
        var tokens = std.mem.splitSequence(u8, line, ": ");
        _ = tokens.next().?; // skip `Program`

        var program = std.ArrayList(u8).init(allocator);
        var numbers = std.mem.splitScalar(u8, tokens.next().?, ',');
        while (numbers.next()) |number| {
            try program.append(try std.fmt.parseInt(u8, number, 10));
        }
        return CPU.init(try program.toOwnedSlice(), registers[0], registers[1], registers[2], allocator);
    }

    fn init(program: Program, a: usize, b: usize, c: usize, allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
            .program = program,
            .ip = 0,
            .a = a,
            .b = b,
            .c = c,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.program);
        self.output.deinit();
    }

    inline fn combo(self: Self, operand: u8) usize {
        return switch (operand) {
            0...3 => @intCast(operand),
            4 => self.a,
            5 => self.b,
            6 => self.c,
            else => unreachable,
        };
    }

    fn reset(self: *Self, a: usize, b: usize, c: usize) void {
        self.output.clearRetainingCapacity();
        self.ip = 0;
        self.a = a;
        self.b = b;
        self.c = c;
    }

    fn run(self: *Self) !void {
        while (true) {
            if (self.ip >= self.program.len) break;
            const opcode = self.program[self.ip];
            const operand = self.program[self.ip + 1];
            switch (opcode & 0b111) {
                ADV => {
                    self.a = self.a >> @intCast(self.combo(operand));
                    self.ip += 2;
                },
                BXL => {
                    self.b = self.b ^ operand;
                    self.ip += 2;
                },
                BST => {
                    self.b = self.combo(operand) & 0b111;
                    self.ip += 2;
                },
                JNZ => {
                    self.ip = if (self.a == 0) self.ip + 2 else operand;
                },
                BXC => {
                    self.b = self.b ^ self.c;
                    self.ip += 2;
                },
                OUT => {
                    try self.output.append(@as(u8, @intCast(self.combo(operand) & 0b111)));
                    self.ip += 2;
                },
                BDV => {
                    self.b = self.a >> @intCast(self.combo(operand));
                    self.ip += 2;
                },
                CVD => {
                    self.c = self.a >> @intCast(self.combo(operand));
                    self.ip += 2;
                },
                else => unreachable,
            }
        }
    }
};

pub fn part1(this: *const @This()) !?[]u8 {
    var cpu = try CPU.parse(this.input, this.allocator);
    defer cpu.deinit();

    try cpu.run();

    var buffer = std.ArrayList(u8).init(this.allocator);
    const writer = buffer.writer();
    for (cpu.output.items) |out| {
        try std.fmt.formatIntValue(out, "d", .{}, writer);
        _ = try writer.write(",");
    }
    _ = buffer.pop();

    return @as(?[]u8, try buffer.toOwnedSlice());
}

pub fn part2(this: *const @This()) !?i64 {
    // EXPLANATION: by "disassembling" the program you will find out that
    // basically every given program is a big loop where the output is affected
    // by the last 6 bits of the register `A` and register `A` which gets
    // "consumed" three bits at time (register `A` gets shifted three bits for
    // every loop).
    //
    // Therefore at each loop we can try 2^6 values and see if they produce the
    // expected output and we need to do it backwards because at every loop we
    // shift register `A` by 3 bits but the last 6 bits counts for the output
    // therefore we need to check if the last 6 bits will produce the correct
    // output.
    //
    // Using the example provided (we expect the final output 0,3,5,4,3,0):
    // A = 0, OUT = 0
    // A = (0 << 3) | 24, OUT = 3,0
    // A = (0 << 6) | (24 << 3) | 32, OUT = 4,3,0
    // A = (0 << 9) | (24 << 6) | (32 << 3) | 40, OUT = 5,4,3,0
    // A = (0 << 12) | (24 << 9) | (32 << 6) | (40 << 3) | 24, OUT = 3,5,4,3,0
    // A = (0 << 15) | (24 << 12) | (32 << 9) | (40 << 6) | (24 << 3) | 0, OUT = 0,3,5,4,3,0
    //
    // NOTE: To improve performance, we can create a lookup table for each
    // number (m) that produces a specific output. This way, if you need a
    // particular output, you can focus only on the numbers that generate that
    // output. However, I'm currently too tired to implement this.

    var a: usize = 0;
    var cpu = try CPU.parse(this.input, this.allocator);
    defer cpu.deinit();

    const check = try this.allocator.alloc(u8, cpu.program.len);
    defer this.allocator.free(check);

    std.mem.copyForwards(u8, check, cpu.program);
    std.mem.reverse(u8, check);

    outer: for (0..cpu.program.len) |i| {
        for (0..64) |m| {
            const n = (a << 3) | m;
            cpu.reset(n, 0, 0);
            try cpu.run();
            std.mem.reverse(u8, cpu.output.items);
            if (!std.mem.eql(u8, cpu.output.items, check[0..(i + 1)])) {
                continue;
            }
            a = n;
            continue :outer;
        }
        @panic("value not found for n where n <= 64");
    }
    return @intCast(a);
}

test "can parse input" {
    const input =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;

    var cpu = try CPU.parse(input, std.testing.allocator);
    defer cpu.deinit();

    try std.testing.expectEqual(729, cpu.a);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 5, 4, 3, 0 }, cpu.program);
}

test "it should work with micro examples" {
    {
        var cpu = try CPU.init(&.{ 2, 6 }, 0, 0, 9, std.testing.allocator);
        try cpu.run();
        try std.testing.expectEqual(1, cpu.b);
    }

    {
        var cpu = try CPU.init(&.{ 5, 0, 5, 1, 5, 4 }, 10, 0, 0, std.testing.allocator);
        try cpu.run();
        const output = try cpu.output.toOwnedSlice();
        defer std.testing.allocator.free(output);
        try std.testing.expectEqualSlices(u8, &.{ 0, 1, 2 }, output);
    }

    {
        var cpu = try CPU.init(&.{ 0, 1, 5, 4, 3, 0 }, 2024, 0, 0, std.testing.allocator);
        try cpu.run();
        const output = try cpu.output.toOwnedSlice();
        defer std.testing.allocator.free(output);
        try std.testing.expectEqualSlices(u8, &.{ 4, 2, 5, 6, 7, 7, 7, 7, 3, 1, 0 }, output);
        try std.testing.expectEqual(0, cpu.a);
    }

    {
        var cpu = try CPU.init(&.{ 1, 7 }, 0, 29, 0, std.testing.allocator);
        try cpu.run();
        try std.testing.expectEqual(26, cpu.b);
    }

    {
        var cpu = try CPU.init(&.{ 4, 0 }, 0, 2024, 43690, std.testing.allocator);
        try cpu.run();
        try std.testing.expectEqual(44354, cpu.b);
    }
}

test "it should work with small input" {
    const allocator = std.testing.allocator;
    const input =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    const part1Solution = try problem.part1();
    defer std.testing.allocator.free(part1Solution.?);
    try std.testing.expectEqualSlices(u8, "4,6,3,5,6,3,5,2,1,0", part1Solution.?);
}

test "it should work with real input for part1" {
    const allocator = std.testing.allocator;
    const input =
        \\Register A: 65804993
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 2,4,1,1,7,5,1,4,0,3,4,5,5,5,3,0
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    const part1Solution = try problem.part1();
    defer std.testing.allocator.free(part1Solution.?);
    try std.testing.expectEqualSlices(u8, "5,1,4,0,5,1,0,2,6", part1Solution.?);
}

test "it should work with small input for part2" {
    const allocator = std.testing.allocator;
    const input =
        \\Register A: 2024
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,3,5,4,3,0
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(117440, problem.part2());
}
