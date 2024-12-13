const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const Position = struct {
    const Self = @This();

    x: usize,
    y: usize,

    fn contained(self: Self, width: usize, heigh: usize) bool {
        return self.x > 0 and self.y > 0 and self.x < width and self.y < heigh;
    }

    fn stepWith(self: Self, direction: Direction) Self {
        return switch (direction) {
            Direction.up => Position{ .x = self.x, .y = self.y - 1 },
            Direction.down => Position{ .x = self.x, .y = self.y + 1 },
            Direction.right => Position{ .x = self.x + 1, .y = self.y },
            Direction.left => Position{ .x = self.x - 1, .y = self.y },
        };
    }
};

const Direction = enum {
    up,
    right,
    down,
    left,

    fn turnRight(self: Direction) Direction {
        return @enumFromInt((@intFromEnum(self) +% 1));
    }

    fn opposite(self: Direction) Direction {
        return @enumFromInt((@intFromEnum(self) +% 2));
    }
};

const Guard = struct {
    const Self = @This();

    position: Position,
    direction: Direction,

    fn stepForward(self: *Self) void {
        self.position = self.position.stepWith(self.direction);
    }

    fn stepBackward(self: *Self) void {
        self.position = self.position.stepWith(self.direction.opposite());
    }

    fn turn(self: *Self) void {
        self.direction = self.direction.turnRight();
    }

    fn goAt(self: *Self, position: Position) void {
        self.position = position;
    }
};

const PositionContext = std.hash_map.AutoContext(Position);
const Positions = std.HashMap(Position, void, PositionContext, std.hash_map.default_max_load_percentage);

const HistoryContext = std.hash_map.AutoContext(Guard);
const History = std.HashMap(Guard, void, HistoryContext, std.hash_map.default_max_load_percentage);

const Grid = struct {
    const Self = @This();

    guard: Guard,
    width: usize,
    heigh: usize,
    obstacles: Positions,
    allocator: std.mem.Allocator,

    fn clone(self: Self) !Self {
        return Self{
            .guard = self.guard,
            .width = self.width,
            .heigh = self.heigh,
            .obstacles = try self.obstacles.clone(),
            .allocator = self.allocator,
        };
    }

    fn init(input: []const u8, allocator: std.mem.Allocator) !Self {
        var i: usize = 0;
        var x: usize = 0;
        var y: usize = 0;
        var width: usize = 0;
        var heigh: usize = 0;
        var obstructions: Positions = Positions.init(allocator);
        var guard: ?Guard = null;
        while (i < input.len) : (i += 1) {
            switch (input[i]) {
                '\n' => {
                    y += 1;
                    x = 0;
                    continue;
                },
                '#' => {
                    try obstructions.put(Position{ .x = x, .y = y }, undefined);
                },
                '^' => {
                    guard = Guard{ .position = Position{ .x = x, .y = y }, .direction = Direction.up };
                },
                else => {},
            }
            heigh = @max(y, heigh);
            width = @max(x, width);
            x += 1;
        }
        heigh = y;
        return Grid{ .guard = guard.?, .width = width + 1, .heigh = heigh + 1, .obstacles = obstructions, .allocator = allocator };
    }

    fn deinit(self: *Self) void {
        self.obstacles.deinit();
    }

    fn walk(self: *Self) !usize {
        var visited: Positions = Positions.init(self.allocator);
        defer visited.deinit();

        try visited.put(self.guard.position, undefined);
        while (true) {
            self.guard.stepForward();
            if (self.obstacles.contains(self.guard.position)) {
                self.guard.stepBackward();
                self.guard.turn();
                continue;
            }
            if (!self.guard.position.contained(self.width, self.heigh)) {
                break;
            }
            try visited.put(self.guard.position, undefined);
        }
        return visited.count();
    }

    // NOTE: history must contain the current position of the guard
    fn hasLoop(self: Self, historySoFar: History, withObstacle: Position) !bool {
        var grid = try self.clone();
        defer grid.deinit();
        var history = try historySoFar.clone();
        defer history.deinit();

        // add additional obstacle to the grid obstacles
        try grid.obstacles.put(withObstacle, undefined);

        while (true) {
            grid.guard.stepForward();
            if (grid.obstacles.contains(grid.guard.position)) {
                grid.guard.stepBackward();
                grid.guard.turn();
            }
            if (!grid.guard.position.contained(grid.width, grid.heigh)) {
                break;
            }
            if (history.contains(grid.guard)) {
                return true;
            }
            try history.put(grid.guard, undefined);
        }
        return false;
    }

    fn countPossibleLoops(self: *Self) !usize {
        var additionalObstacles: Positions = Positions.init(self.allocator);
        defer additionalObstacles.deinit();
        var visited: Positions = Positions.init(self.allocator);
        defer visited.deinit();
        var history: History = History.init(self.allocator);
        defer history.deinit();

        try visited.put(self.guard.position, undefined);
        try history.put(self.guard, undefined);
        while (true) {
            // Check if an obstacle in front of the guard will cause a loop
            const inFrontOf = self.guard.position.stepWith(self.guard.direction);
            if (!visited.contains(inFrontOf) and
                !additionalObstacles.contains(inFrontOf) and
                try self.hasLoop(history, inFrontOf))
            {
                try additionalObstacles.put(inFrontOf, undefined);
            }

            self.guard.stepForward();
            if (self.obstacles.contains(self.guard.position)) {
                self.guard.stepBackward();
                self.guard.turn();
            }
            if (!self.guard.position.contained(self.width, self.heigh)) {
                break;
            }
            try visited.put(self.guard.position, undefined);
            try history.put(self.guard, undefined);
        }
        return additionalObstacles.count();
    }
};

pub fn part1(this: *const @This()) !?i64 {
    var grid = try Grid.init(this.input, this.allocator);
    defer grid.deinit();
    const steps = try grid.walk();
    return @intCast(steps);
}

pub fn part2(this: *const @This()) !?i64 {
    var grid = try Grid.init(this.input, this.allocator);
    defer grid.deinit();
    const result = try grid.countPossibleLoops();
    return @intCast(result);
}

test "it should do nothing" {
    const allocator = std.testing.allocator;
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(41, try problem.part1());
    try std.testing.expectEqual(6, try problem.part2());
}
