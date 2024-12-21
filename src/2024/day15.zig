const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const Point = @Vector(2, usize);
const Element = enum { wall, robot, box };
const Direction = enum { up, down, left, right };
const WarehouseMap = std.HashMap(Point, Element, std.hash_map.AutoContext(Point), std.hash_map.default_max_load_percentage);

const Warehouse = struct {
    const Self = @This();

    elements: WarehouseMap,
    width: usize,
    height: usize,
    robot: Point,

    fn deinit(self: *Self) void {
        self.elements.deinit();
    }

    fn parse(input: []const u8, allocator: std.mem.Allocator) !Self {
        var elements = WarehouseMap.init(allocator);
        var robot: Point = undefined;
        errdefer elements.deinit();
        var lines = std.mem.splitScalar(u8, input, '\n');
        var y: usize = 0;
        var width: usize = 0;
        var height: usize = 0;
        while (lines.next()) |line| : (y += 1) {
            if (line.len == 0) continue;
            height = y;
            for (line, 0..) |char, x| {
                width = x;
                switch (char) {
                    '#' => try elements.put(.{ x, y }, Element.wall),
                    'O' => try elements.put(.{ x, y }, Element.box),
                    '@' => {
                        try elements.put(.{ x, y }, Element.robot);
                        robot = .{ x, y };
                    },
                    else => undefined,
                }
            }
        }
        return Self{
            .elements = elements,
            .robot = robot,
            .width = width + 1,
            .height = height + 1,
        };
    }

    fn toWide(self: Self, allocator: std.mem.Allocator) !WideWarehouse {
        var wideElements = WarehouseMap.init(allocator);
        errdefer wideElements.deinit();

        var entries = self.elements.iterator();
        while (entries.next()) |entry| {
            const point = entry.key_ptr.*;
            try wideElements.put(.{ point[0] * 2, point[1] }, entry.value_ptr.*);
        }

        return WideWarehouse{
            .width = self.width * 2,
            .height = self.height,
            .elements = wideElements,
            .robot = .{ self.robot[0] * 2, self.robot[1] },
        };
    }

    fn draw(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, self.height * (self.width + 1));
        errdefer buffer.deinit();
        var x: usize = 0;
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            while (x < self.width) : (x += 1) {
                const element = self.elements.get(.{ x, y });
                try buffer.append(if (element != null) switch (element.?) {
                    Element.wall => '#',
                    Element.box => 'O',
                    Element.robot => '@',
                } else '.');
            }
            try buffer.append('\n');
            x = 0;
        }
        return buffer.toOwnedSlice();
    }

    fn moveElement(self: *Self, direction: Direction, position: Point) !?Point {
        const element = self.elements.get(position);
        const nextPosition = switch (direction) {
            Direction.left => .{ position[0] - 1, position[1] },
            Direction.right => .{ position[0] + 1, position[1] },
            Direction.up => .{ position[0], position[1] - 1 },
            Direction.down => .{ position[0], position[1] + 1 },
        };
        const nextElement = self.elements.get(nextPosition);
        if (nextElement == null) {
            _ = self.elements.remove(position);
            try self.elements.put(nextPosition, element.?);
            return nextPosition;
        }
        switch (nextElement.?) {
            Element.wall => {
                return null;
            },
            Element.box => {
                const movedAt = try self.moveElement(direction, nextPosition);
                if (movedAt == null) return null;
                _ = self.elements.remove(position);
                try self.elements.put(nextPosition, element.?);
                return nextPosition;
            },
            Element.robot => {
                unreachable;
            },
        }
        unreachable;
    }

    fn moveRobot(self: *Self, direction: Direction) !?Point {
        const nextPosition = try self.moveElement(direction, self.robot);
        if (nextPosition != null) self.robot = nextPosition.?;
        return nextPosition;
    }

    fn gpsElement(position: Point) usize {
        return 100 * position[1] + position[0];
    }

    fn gps(self: Self) usize {
        var result: usize = 0;
        var entries = self.elements.iterator();
        while (entries.next()) |entry| {
            result += switch (entry.value_ptr.*) {
                Element.box => gpsElement(entry.key_ptr.*),
                else => 0,
            };
        }
        return result;
    }
};

test "can parse the warehouse" {
    const input =
        \\########
        \\#..O.O.#
        \\##@.O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
    ;

    var actual = try Warehouse.parse(input, std.testing.allocator);
    defer actual.deinit();
    try std.testing.expectEqual(8, actual.width);
    try std.testing.expectEqual(8, actual.height);
    try std.testing.expectEqual(Element.wall, actual.elements.get(.{ 0, 0 }));
    try std.testing.expectEqual(Element.wall, actual.elements.get(.{ 0, 0 }));
    try std.testing.expectEqual(Element.wall, actual.elements.get(.{ 1, 2 }));
    try std.testing.expectEqual(Element.wall, actual.elements.get(.{ 7, 7 }));
    try std.testing.expectEqual(Element.robot, actual.elements.get(.{ 2, 2 }));
    try std.testing.expectEqual(.{ 2, 2 }, actual.robot);
    try std.testing.expectEqual(Element.box, actual.elements.get(.{ 3, 1 }));
    try std.testing.expectEqual(Element.box, actual.elements.get(.{ 4, 5 }));
}

test "can display the warehouse" {
    const expected =
        \\########
        \\#..O.O.#
        \\##@.O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
        \\
    ;

    var warehouse = try Warehouse.parse(expected, std.testing.allocator);
    defer warehouse.deinit();
    const actual = try warehouse.draw(std.testing.allocator);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "move robot against a wall should stay still" {
    const before =
        \\#.#@..#
        \\
    ;
    const expectedAfter =
        \\#.#@..#
        \\
    ;
    var warehouse = try Warehouse.parse(before, std.testing.allocator);
    defer warehouse.deinit();
    const movedAt = try warehouse.moveRobot(Direction.left);
    const after = try warehouse.draw(std.testing.allocator);
    defer std.testing.allocator.free(after);

    try std.testing.expect(movedAt == null);
    try std.testing.expectEqualSlices(u8, expectedAfter, after);
}

test "move robot to an empty tile should move there" {
    const before =
        \\#.#@..#
        \\
    ;
    const expectedAfter =
        \\#.#.@.#
        \\
    ;
    var warehouse = try Warehouse.parse(before, std.testing.allocator);
    defer warehouse.deinit();
    const movedAt = try warehouse.moveRobot(Direction.right);
    const after = try warehouse.draw(std.testing.allocator);
    defer std.testing.allocator.free(after);

    try std.testing.expect(movedAt != null);
    try std.testing.expectEqualSlices(u8, expectedAfter, after);
}

test "move robot against a box able to move should move with the box" {
    const before =
        \\#.#@O.#
        \\
    ;
    const expectedAfter =
        \\#.#.@O#
        \\
    ;
    var warehouse = try Warehouse.parse(before, std.testing.allocator);
    defer warehouse.deinit();
    const movedAt = try warehouse.moveRobot(Direction.right);
    const after = try warehouse.draw(std.testing.allocator);
    defer std.testing.allocator.free(after);

    try std.testing.expect(movedAt != null);
    try std.testing.expectEqualSlices(u8, expectedAfter, after);
}

test "can calculate gps of a warehouse" {
    const input =
        \\########
        \\#....OO#
        \\##.....#
        \\#.....O#
        \\#.#O@..#
        \\#...O..#
        \\#...O..#
        \\########
        \\
    ;
    var warehouse = try Warehouse.parse(input, std.testing.allocator);
    defer warehouse.deinit();
    try std.testing.expectEqual(2028, warehouse.gps());
}

test "a warehouse can be widened" {
    const input =
        \\##########
        \\#..O..O.O#
        \\#......O.#
        \\#.OO..O.O#
        \\#..O@..O.#
        \\#O#..O...#
        \\#O..O..O.#
        \\#.OO.O.OO#
        \\#....O...#
        \\##########
        \\
    ;

    const expected =
        \\####################
        \\##....[]....[]..[]##
        \\##............[]..##
        \\##..[][]....[]..[]##
        \\##....[]@.....[]..##
        \\##[]##....[]......##
        \\##[]....[]....[]..##
        \\##..[][]..[]..[][]##
        \\##........[]......##
        \\####################
        \\
    ;

    var warehouse = try Warehouse.parse(input, std.testing.allocator);
    defer warehouse.deinit();
    var wide = try warehouse.toWide(std.testing.allocator);
    defer wide.deinit();
    const picture = try wide.draw(std.testing.allocator);
    defer std.testing.allocator.free(picture);
    try std.testing.expectEqualSlices(u8, expected, picture);
}

test "it should work for small input" {
    const allocator = std.testing.allocator;
    const input =
        \\##########
        \\#..O..O.O#
        \\#......O.#
        \\#.OO..O.O#
        \\#..O@..O.#
        \\#O#..O...#
        \\#O..O..O.#
        \\#.OO.O.OO#
        \\#....O...#
        \\##########
        \\
        \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
        \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
        \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
        \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
        \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
        \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
        \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
        \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
        \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
        \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
        \\
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(10092, try problem.part1());
    try std.testing.expectEqual(9021, try problem.part2());
}

pub fn part1(this: *const @This()) !?i64 {
    var sections = std.mem.splitSequence(u8, this.input, "\n\n");
    var warehouse = try Warehouse.parse(sections.next().?, this.allocator);
    defer warehouse.deinit();

    var moves = std.ArrayList(Direction).init(this.allocator);
    defer moves.deinit();

    for (sections.next().?) |char| {
        if (char == '\n') continue;
        try moves.append(switch (char) {
            '<' => Direction.left,
            '>' => Direction.right,
            '^' => Direction.up,
            'v' => Direction.down,
            else => unreachable,
        });
    }

    for (moves.items) |direction| _ = try warehouse.moveRobot(direction);

    return @intCast(warehouse.gps());
}

const WideWarehouse = struct {
    const Self = @This();

    elements: WarehouseMap,
    width: usize,
    height: usize,
    robot: Point,

    fn deinit(self: *Self) void {
        self.elements.deinit();
    }

    fn parse(input: []const u8, allocator: std.mem.Allocator) !Self {
        var elements = WarehouseMap.init(allocator);
        var robot: Point = undefined;
        errdefer elements.deinit();
        var lines = std.mem.splitScalar(u8, input, '\n');
        var y: usize = 0;
        var width: usize = 0;
        var height: usize = 0;
        while (lines.next()) |line| : (y += 1) {
            if (line.len == 0) continue;
            height = y;
            var x: usize = 0;
            while (x < line.len - 1) {
                width = x;
                if (line[x] == '.') {
                    x += 1;
                    continue;
                }
                if (line[x] == '@') {
                    try elements.put(.{ x, y }, Element.robot);
                    robot = .{ x, y };
                    x += 1;
                    continue;
                }
                if (line[x] == '#' and line[x + 1] == '#') {
                    try elements.put(.{ x, y }, Element.wall);
                    x += 2;
                    continue;
                }
                if (line[x] == '[' and line[x + 1] == ']') {
                    try elements.put(.{ x, y }, Element.box);
                    x += 2;
                    continue;
                }
                unreachable;
            }
        }
        return Self{
            .elements = elements,
            .robot = robot,
            .width = width + 1,
            .height = height + 1,
        };
    }

    fn draw(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, self.height * (self.width + 1));
        errdefer buffer.deinit();
        var x: usize = 0;
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            while (x < self.width) {
                const element = self.elements.get(.{ x, y });
                const picture = if (element != null) switch (element.?) {
                    Element.wall => "##",
                    Element.box => "[]",
                    Element.robot => "@",
                } else ".";
                try buffer.appendSlice(picture);
                x += picture.len;
            }
            try buffer.append('\n');
            x = 0;
        }
        return buffer.toOwnedSlice();
    }

    fn moveElement(self: *Self, direction: Direction, position: Point, dryRun: bool) !?Point {
        const element = self.elements.get(position);

        const nextPosition = switch (direction) {
            Direction.left => .{ position[0] - 1, position[1] },
            Direction.right => .{ position[0] + 1, position[1] },
            Direction.up => .{ position[0], position[1] - 1 },
            Direction.down => .{ position[0], position[1] + 1 },
        };

        // Vertically a box can collide in three ways
        //
        // 1. [] 2. []  3.  []
        //    []     []    []

        // Vertically a robot can collide in two ways
        //
        // 1. [] 2. []
        //    @      @
        //
        // They can combine, if they do, all of the colliding elements must be
        // able to move for the element to be able to move

        const positionsToMove: []const Point = switch (direction) {
            Direction.left => &.{.{ position[0] - 2, position[1] }},
            Direction.right => switch (element.?) {
                Element.robot => &.{.{ position[0] + 1, position[1] }},
                else => &.{.{ position[0] + 2, position[1] }},
            },
            Direction.up => switch (element.?) {
                Element.robot => &.{ .{ position[0], position[1] - 1 }, .{ position[0] - 1, position[1] - 1 } },
                else => &.{ .{ position[0], position[1] - 1 }, .{ position[0] - 1, position[1] - 1 }, .{ position[0] + 1, position[1] - 1 } },
            },
            Direction.down => switch (element.?) {
                Element.robot => &.{ .{ position[0], position[1] + 1 }, .{ position[0] - 1, position[1] + 1 } },
                else => &.{ .{ position[0], position[1] + 1 }, .{ position[0] - 1, position[1] + 1 }, .{ position[0] + 1, position[1] + 1 } },
            },
        };

        var canMove = true;
        for (positionsToMove) |positionToMove| {
            const nextElement = self.elements.get(positionToMove);
            if (nextElement == null) continue;
            switch (nextElement.?) {
                Element.wall => {
                    canMove = false;
                    break;
                },
                Element.box => {
                    const movedAt = try self.moveElement(direction, positionToMove, true);
                    if (movedAt == null) {
                        canMove = false;
                        break;
                    }
                },
                Element.robot => {
                    unreachable;
                },
            }
        }

        if (canMove and !dryRun) {
            for (positionsToMove) |positionToMove| {
                const nextElement = self.elements.get(positionToMove);
                if (nextElement == null) continue;
                switch (nextElement.?) {
                    Element.wall => {
                        unreachable;
                    },
                    Element.box => {
                        _ = try self.moveElement(direction, positionToMove, false);
                    },
                    Element.robot => {
                        unreachable;
                    },
                }
            }
        }

        if (!canMove) {
            return null;
        }

        if (!dryRun) {
            _ = self.elements.remove(position);
            try self.elements.put(nextPosition, element.?);
        }
        return nextPosition;
    }

    fn moveRobot(self: *Self, direction: Direction) !?Point {
        const nextPosition = try self.moveElement(direction, self.robot, false);
        if (nextPosition != null) self.robot = nextPosition.?;
        return nextPosition;
    }

    fn gpsElement(position: Point) usize {
        return 100 * position[1] + position[0];
    }

    fn gps(self: Self) usize {
        var result: usize = 0;
        var entries = self.elements.iterator();
        while (entries.next()) |entry| {
            result += switch (entry.value_ptr.*) {
                Element.box => gpsElement(entry.key_ptr.*),
                else => 0,
            };
        }
        return result;
    }
};

test "spot the bug in wide warehouse" {
    const TestCase = struct {
        // before, moves, after
        []const u8,
        []const Direction,
        []const u8,
    };

    const test_cases: []const TestCase = &.{
        // move more than one block
        .{
            \\##############
            \\##......##..##
            \\##..........##
            \\##...[][]@..##
            \\##....[]....##
            \\##..........##
            \\##############
            \\
            ,
            &.{Direction.left},
            \\##############
            \\##......##..##
            \\##..........##
            \\##..[][]@...##
            \\##....[]....##
            \\##..........##
            \\##############
            \\
        },
        // when one block is stuck, everything stay still
        .{
            \\##############
            \\##......##..##
            \\##..........##
            \\##...[][]...##
            \\##....[]....##
            \\##.....@....##
            \\##############
            \\
            ,
            &.{ Direction.up, Direction.up },
            \\##############
            \\##......##..##
            \\##...[][]...##
            \\##....[]....##
            \\##.....@....##
            \\##..........##
            \\##############
            \\
        },
        .{
            \\##############
            \\##......##..##
            \\##..........##
            \\##...[].....##
            \\##....[]....##
            \\##.....@....##
            \\##############
            \\
            ,
            &.{ Direction.up, Direction.up },
            \\##############
            \\##...[].##..##
            \\##....[]....##
            \\##.....@....##
            \\##..........##
            \\##..........##
            \\##############
            \\
        },
        .{
            \\##############
            \\##......##..##
            \\##..........##
            \\##...[].....##
            \\##....[]....##
            \\##....@.....##
            \\##############
            \\
            ,
            &.{ Direction.up, Direction.up },
            \\##############
            \\##...[].##..##
            \\##....[]....##
            \\##....@.....##
            \\##..........##
            \\##..........##
            \\##############
            \\
        },
        .{
            \\##############
            \\##......##..##
            \\##...@......##
            \\##...[].....##
            \\##....[]....##
            \\##..........##
            \\##############
            \\
            ,
            &.{ Direction.down, Direction.down },
            \\##############
            \\##......##..##
            \\##..........##
            \\##...@......##
            \\##...[].....##
            \\##....[]....##
            \\##############
            \\
        },
        .{
            \\##############
            \\##......##..##
            \\##....@.....##
            \\##...[].....##
            \\##....[]....##
            \\##..........##
            \\##############
            \\
            ,
            &.{ Direction.down, Direction.down },
            \\##############
            \\##......##..##
            \\##..........##
            \\##....@.....##
            \\##...[].....##
            \\##....[]....##
            \\##############
            \\
        },
        .{
            \\##############
            \\##......##..##
            \\##..[][][]..##
            \\##...[][]...##
            \\##....[]....##
            \\##.....@....##
            \\##############
            \\
            ,
            &.{Direction.up},
            \\##############
            \\##......##..##
            \\##..[][][]..##
            \\##...[][]...##
            \\##....[]....##
            \\##.....@....##
            \\##############
            \\
        },
        .{
            \\##############
            \\##......##..##
            \\##..[][]....##
            \\##...[][]...##
            \\##....[]....##
            \\##.....@....##
            \\##############
            \\
            ,
            &.{Direction.up},
            \\##############
            \\##..[][]##..##
            \\##...[][]...##
            \\##....[]....##
            \\##.....@....##
            \\##..........##
            \\##############
            \\
        },
        .{
            \\##############
            \\##......##..##
            \\##..[][]....##
            \\##...[][]...##
            \\##....[]....##
            \\##........@.##
            \\##############
            \\
            ,
            &.{ Direction.right, Direction.right },
            \\##############
            \\##......##..##
            \\##..[][]....##
            \\##...[][]...##
            \\##....[]....##
            \\##.........@##
            \\##############
            \\
        },
        .{
            \\##############
            \\##......##..##
            \\##..[][]....##
            \\##..@[][]...##
            \\##....[]....##
            \\##..........##
            \\##############
            \\
            ,
            &.{ Direction.right, Direction.right },
            \\##############
            \\##......##..##
            \\##..[][]....##
            \\##....@[][].##
            \\##....[]....##
            \\##..........##
            \\##############
            \\
        },
    };

    for (test_cases) |test_case| {
        var warehouse = try WideWarehouse.parse(test_case[0], std.testing.allocator);
        defer warehouse.deinit();

        for (test_case[1]) |direction| _ = try warehouse.moveRobot(direction);

        const actual = try warehouse.draw(std.testing.allocator);
        defer std.testing.allocator.free(actual);

        try std.testing.expectEqualSlices(u8, test_case[2], actual);
    }
}

test "can move in a wide warehouse" {
    const input =
        \\#######
        \\#...#.#
        \\#.....#
        \\#..OO@#
        \\#..O..#
        \\#.....#
        \\#######
        \\
    ;

    // move left
    const afterMove1 =
        \\##############
        \\##......##..##
        \\##..........##
        \\##...[][]@..##
        \\##....[]....##
        \\##..........##
        \\##############
        \\
    ;

    var warehouse = try Warehouse.parse(input, std.testing.allocator);
    defer warehouse.deinit();

    var wide = try warehouse.toWide(std.testing.allocator);
    defer wide.deinit();

    _ = try wide.moveRobot(Direction.left);
    {
        const picture = try wide.draw(std.testing.allocator);
        defer std.testing.allocator.free(picture);
        try std.testing.expectEqualSlices(u8, afterMove1, picture);
    }

    // move down
    // move down
    const afterMove3 =
        \\##############
        \\##......##..##
        \\##..........##
        \\##...[][]...##
        \\##....[]....##
        \\##.......@..##
        \\##############
        \\
    ;

    _ = try wide.moveRobot(Direction.down);
    _ = try wide.moveRobot(Direction.down);
    {
        const picture = try wide.draw(std.testing.allocator);
        defer std.testing.allocator.free(picture);
        try std.testing.expectEqualSlices(u8, afterMove3, picture);
    }

    // move left
    // move left
    const afterMove5 =
        \\##############
        \\##......##..##
        \\##..........##
        \\##...[][]...##
        \\##....[]....##
        \\##.....@....##
        \\##############
        \\
    ;

    _ = try wide.moveRobot(Direction.left);
    _ = try wide.moveRobot(Direction.left);
    {
        const picture = try wide.draw(std.testing.allocator);
        defer std.testing.allocator.free(picture);
        try std.testing.expectEqualSlices(u8, afterMove5, picture);
    }

    // move up
    // move up
    const afterMove7 =
        \\##############
        \\##......##..##
        \\##...[][]...##
        \\##....[]....##
        \\##.....@....##
        \\##..........##
        \\##############
        \\
    ;

    _ = try wide.moveRobot(Direction.up);
    _ = try wide.moveRobot(Direction.up);
    {
        const picture = try wide.draw(std.testing.allocator);
        defer std.testing.allocator.free(picture);
        try std.testing.expectEqualSlices(u8, afterMove7, picture);
    }

    // move left
    // move left
    const afterMove9 =
        \\##############
        \\##......##..##
        \\##...[][]...##
        \\##....[]....##
        \\##...@......##
        \\##..........##
        \\##############
        \\
    ;
    _ = try wide.moveRobot(Direction.left);
    _ = try wide.moveRobot(Direction.left);
    {
        const picture = try wide.draw(std.testing.allocator);
        defer std.testing.allocator.free(picture);
        try std.testing.expectEqualSlices(u8, afterMove9, picture);
    }

    // move up
    // move up
    const afterMove11 =
        \\##############
        \\##...[].##..##
        \\##...@.[]...##
        \\##....[]....##
        \\##..........##
        \\##..........##
        \\##############
        \\
    ;
    _ = try wide.moveRobot(Direction.up);
    _ = try wide.moveRobot(Direction.up);
    {
        const picture = try wide.draw(std.testing.allocator);
        defer std.testing.allocator.free(picture);
        try std.testing.expectEqualSlices(u8, afterMove11, picture);
    }
}

pub fn part2(this: *const @This()) !?i64 {
    var sections = std.mem.splitSequence(u8, this.input, "\n\n");
    var warehouse = try Warehouse.parse(sections.next().?, this.allocator);
    defer warehouse.deinit();
    var wide = try warehouse.toWide(this.allocator);
    defer wide.deinit();

    var moves = std.ArrayList(Direction).init(this.allocator);
    defer moves.deinit();

    for (sections.next().?) |char| {
        if (char == '\n') continue;
        try moves.append(switch (char) {
            '<' => Direction.left,
            '>' => Direction.right,
            '^' => Direction.up,
            'v' => Direction.down,
            else => unreachable,
        });
    }

    for (moves.items) |direction| _ = try wide.moveRobot(direction);

    return @intCast(wide.gps());
}

test "it should work for a small input in wide mode" {
    const input =
        \\##########
        \\#..O..O.O#
        \\#......O.#
        \\#.OO..O.O#
        \\#..O@..O.#
        \\#O#..O...#
        \\#O..O..O.#
        \\#.OO.O.OO#
        \\#....O...#
        \\##########
        \\
        \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
        \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
        \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
        \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
        \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
        \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
        \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
        \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
        \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
        \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
        \\
    ;

    var sections = std.mem.splitSequence(u8, input, "\n\n");
    var warehouse = try Warehouse.parse(sections.next().?, std.testing.allocator);
    defer warehouse.deinit();
    var wide = try warehouse.toWide(std.testing.allocator);
    defer wide.deinit();

    var moves = std.ArrayList(Direction).init(std.testing.allocator);
    defer moves.deinit();

    for (sections.next().?) |char| {
        if (char == '\n') continue;
        try moves.append(switch (char) {
            '<' => Direction.left,
            '>' => Direction.right,
            '^' => Direction.up,
            'v' => Direction.down,
            else => unreachable,
        });
    }

    for (moves.items) |direction| _ = try wide.moveRobot(direction);

    const expected =
        \\####################
        \\##[].......[].[][]##
        \\##[]...........[].##
        \\##[]........[][][]##
        \\##[]......[]....[]##
        \\##..##......[]....##
        \\##..[]............##
        \\##..@......[].[][]##
        \\##......[][]..[]..##
        \\####################
        \\
    ;

    const picture = try wide.draw(std.testing.allocator);
    defer std.testing.allocator.free(picture);
    try std.testing.expectEqualSlices(u8, expected, picture);
}
