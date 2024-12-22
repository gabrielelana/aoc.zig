const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const Move = struct { from: Reindeer, to: Reindeer, cost: usize };
const State = struct { cost: usize, reindeer: Reindeer, parent: ?*State };

const AlreadyVisited = std.HashMap(Position, void, std.hash_map.AutoContext(Position), std.hash_map.default_max_load_percentage);
const AlreadyVisitedWithPosition = std.HashMap(Reindeer, void, std.hash_map.AutoContext(Reindeer), std.hash_map.default_max_load_percentage);
const BestSpots = std.HashMap(Position, void, std.hash_map.AutoContext(Position), std.hash_map.default_max_load_percentage);
const ToVisit = std.PriorityQueue(*State, void, compareState);

fn compareState(_: void, l: *State, r: *State) std.math.Order {
    if (l.cost < r.cost) return std.math.Order.lt;
    if (l.cost == r.cost) return std.math.Order.eq;
    return std.math.Order.gt;
}

fn pathUnion(state: *State, bestSpots: *BestSpots) !void {
    var current = state;
    try bestSpots.put(current.reindeer.position, undefined);
    while (current.parent) |parent| {
        current = parent;
        try bestSpots.put(current.reindeer.position, undefined);
    }
}

pub fn part1(this: *const @This()) !?i64 {
    var maze = try Maze.parse(this.input, this.allocator);
    defer maze.deinit();

    var toVisit = ToVisit.init(this.allocator, undefined);
    defer toVisit.deinit();

    var alreadyVisited = AlreadyVisited.init(this.allocator);
    defer alreadyVisited.deinit();

    var arena = std.heap.ArenaAllocator.init(this.allocator);
    defer arena.deinit();
    const stateAllocator = arena.allocator();

    const firstState = try stateAllocator.create(State);
    firstState.cost = 0;
    firstState.reindeer = maze.reindeer;
    firstState.parent = null;
    try toVisit.add(firstState);

    // while there are a next state left to explore
    while (toVisit.count() > 0) {
        // get the lowest cost state in toVisit
        const state = toVisit.remove();

        // if the state is the end we are done (return state.cost)
        if (state.reindeer.position.x == maze.end.x and state.reindeer.position.y == maze.end.y) {
            return @intCast(state.cost);
        }

        // add the current position to the alreadyVisited list
        try alreadyVisited.put(state.reindeer.position, undefined);

        // for all the next moves as move
        const moves = try maze.possibleMovesFrom(state.reindeer, state.cost, this.allocator);
        defer this.allocator.free(moves);
        for (moves) |move| {

            // if the move is in visited then skip
            if (alreadyVisited.contains(move.to.position)) continue;

            // add the state in toVisit
            const nextState = try stateAllocator.create(State);
            nextState.cost = move.cost;
            nextState.reindeer = move.to;
            nextState.parent = state;
            try toVisit.add(nextState);
        }
    }

    return null;
}

pub fn part2(this: *const @This()) !?i64 {
    var maze = try Maze.parse(this.input, this.allocator);
    defer maze.deinit();

    var toVisit = ToVisit.init(this.allocator, undefined);
    defer toVisit.deinit();

    var alreadyVisited = AlreadyVisitedWithPosition.init(this.allocator);
    defer alreadyVisited.deinit();

    var arena = std.heap.ArenaAllocator.init(this.allocator);
    defer arena.deinit();
    const stateAllocator = arena.allocator();

    var bestSpots = BestSpots.init(this.allocator);
    defer bestSpots.deinit();

    var bestPathCost: usize = std.math.maxInt(usize);

    const firstState = try stateAllocator.create(State);
    firstState.cost = 0;
    firstState.reindeer = maze.reindeer;
    firstState.parent = null;
    try toVisit.add(firstState);

    // while there are a next state left to explore
    while (toVisit.count() > 0) {
        // get the lowest cost state in toVisit
        const state = toVisit.remove();

        // if the state is the end we are done (return state.cost)
        if (state.reindeer.position.x == maze.end.x and state.reindeer.position.y == maze.end.y) {
            const cost = state.cost;
            bestPathCost = @min(bestPathCost, cost);
            if (cost <= bestPathCost) {
                try pathUnion(state, &bestSpots);
            }
        }

        // add the current position to the alreadyVisited list
        try alreadyVisited.put(state.reindeer, undefined);

        // for all the next moves as move
        const moves = try maze.possibleMovesFrom(state.reindeer, state.cost, this.allocator);
        defer this.allocator.free(moves);
        for (moves) |move| {

            // if the move is in visited then skip
            if (alreadyVisited.contains(move.to)) continue;

            const nextState = try stateAllocator.create(State);
            nextState.cost = move.cost;
            nextState.reindeer = move.to;
            nextState.parent = state;
            try toVisit.add(nextState);
        }
    }

    return bestSpots.count();
}

const Position = struct { x: usize, y: usize };
const Direction = enum {
    north,
    east,
    south,
    west,

    fn name(self: Direction) []const u8 {
        return switch (self) {
            Direction.north => "north",
            Direction.south => "south",
            Direction.east => "east",
            Direction.west => "west",
        };
    }

    fn forward(self: Direction, position: Position) Position {
        return switch (self) {
            Direction.north => Position{
                .x = position.x,
                .y = position.y - 1,
            },
            Direction.south => Position{
                .x = position.x,
                .y = position.y + 1,
            },
            Direction.east => Position{
                .x = position.x + 1,
                .y = position.y,
            },
            Direction.west => Position{
                .x = position.x - 1,
                .y = position.y,
            },
        };
    }

    fn left(self: Direction) Direction {
        return @enumFromInt((@intFromEnum(self) +% 3));
    }

    fn right(self: Direction) Direction {
        return @enumFromInt((@intFromEnum(self) +% 1));
    }
};
const Tile = enum { empty, wall };
const Step = enum {
    forward,
    left,
    right,

    fn all() []const Step {
        return &.{ Step.forward, Step.left, Step.right };
    }
};
const Tiles = std.ArrayList(Tile);
const Reindeer = struct {
    position: Position,
    facing: Direction,
};
const Maze = struct {
    const Self = @This();

    tiles: Tiles,
    reindeer: Reindeer,
    end: Position,
    width: usize,
    height: usize,

    fn deinit(self: *Self) void {
        self.tiles.deinit();
    }

    fn parse(input: []const u8, allocator: std.mem.Allocator) !Self {
        var tiles = Tiles.init(allocator);
        errdefer tiles.deinit();
        var lines = std.mem.splitScalar(u8, input, '\n');
        var y: usize = 0;
        var reindeer: Reindeer = undefined;
        var end: Position = undefined;
        var width: usize = 0;
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            for (line, 0..) |char, x| {
                width = x + 1;
                switch (char) {
                    '#' => try tiles.append(Tile.wall),
                    '.' => try tiles.append(Tile.empty),
                    'S' => {
                        try tiles.append(Tile.empty);
                        reindeer = .{ .position = .{ .x = x, .y = y }, .facing = Direction.east };
                    },
                    'E' => {
                        try tiles.append(Tile.empty);
                        end = .{ .x = x, .y = y };
                    },
                    else => unreachable,
                }
            }
            y += 1;
        }

        return Self{
            .tiles = tiles,
            .reindeer = reindeer,
            .end = end,
            .width = width,
            .height = y,
        };
    }

    fn at(self: Self, x: usize, y: usize) ?Tile {
        if (x >= self.width or y >= self.height) return null;
        return self.tiles.items[y * self.width + x];
    }

    fn take(reindeer: Reindeer, step: Step) Reindeer {
        const facing = switch (step) {
            Step.forward => reindeer.facing,
            Step.left => reindeer.facing.left(),
            Step.right => reindeer.facing.right(),
        };
        return Reindeer{
            .facing = facing,
            .position = facing.forward(reindeer.position),
        };
    }

    fn possibleMovesFrom(self: Self, reindeer: Reindeer, costSoFar: usize, allocator: std.mem.Allocator) ![]Move {
        var moves = std.ArrayList(Move).init(allocator);
        errdefer moves.deinit();

        for (Step.all()) |step| {
            const next = take(reindeer, step);
            const tile = self.at(next.position.x, next.position.y);
            if (tile != null and tile != Tile.wall) {
                try moves.append(Move{
                    .from = reindeer,
                    .to = next,
                    .cost = costSoFar + (if (reindeer.facing != next.facing) @as(usize, 1_001) else @as(usize, 1)),
                });
            }
        }

        return moves.toOwnedSlice();
    }
};

test "it can parse input" {
    const input =
        \\###############
        \\#.......#....E#
        \\#.#.###.#.###.#
        \\#.....#.#...#.#
        \\#.###.#####.#.#
        \\#.#.#.......#.#
        \\#.#.#####.###.#
        \\#...........#.#
        \\###.#.#####.#.#
        \\#...#.....#.#.#
        \\#.#.#.###.#.#.#
        \\#.....#...#.#.#
        \\#.###.#.#.#.#.#
        \\#S..#.....#...#
        \\###############
        \\
    ;

    var maze = try Maze.parse(input, std.testing.allocator);
    defer maze.deinit();

    try std.testing.expectEqual(Tile.empty, maze.at(1, 1));
    try std.testing.expectEqual(Tile.empty, maze.at(13, 13));
    try std.testing.expectEqual(Tile.wall, maze.at(0, 0));
    try std.testing.expectEqual(Tile.wall, maze.at(14, 14));
    try std.testing.expectEqual(Tile.wall, maze.at(8, 1));
    try std.testing.expectEqual(15, maze.width);
    try std.testing.expectEqual(15, maze.height);
}

test "it should work with small example" {
    const allocator = std.testing.allocator;
    const input =
        \\###############
        \\#.......#....E#
        \\#.#.###.#.###.#
        \\#.....#.#...#.#
        \\#.###.#####.#.#
        \\#.#.#.......#.#
        \\#.#.#####.###.#
        \\#...........#.#
        \\###.#.#####.#.#
        \\#...#.....#.#.#
        \\#.#.#.###.#.#.#
        \\#.....#...#.#.#
        \\#.###.#.#.#.#.#
        \\#S..#.....#...#
        \\###############
        \\
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(7036, try problem.part1());
    try std.testing.expectEqual(45, try problem.part2());
}

test "it should work with another small example" {
    const allocator = std.testing.allocator;
    const input =
        \\#################
        \\#...#...#...#..E#
        \\#.#.#.#.#.#.#.#.#
        \\#.#.#.#...#...#.#
        \\#.#.#.#.###.#.#.#
        \\#...#.#.#.....#.#
        \\#.#.#.#.#.#####.#
        \\#.#...#.#.#.....#
        \\#.#.#####.#.###.#
        \\#.#.#.......#...#
        \\#.#.###.#####.###
        \\#.#.#...#.....#.#
        \\#.#.#.#####.###.#
        \\#.#.#.........#.#
        \\#.#.#.#########.#
        \\#S#.............#
        \\#################
        \\
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(11048, try problem.part1());
    try std.testing.expectEqual(64, try problem.part2());
}
