const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

pub fn part1(this: *const @This()) !?usize {
    var garden = try parse(this.input, this.allocator);
    defer garden.map.deinit();

    var visited = CoordinateSet.init(this.allocator);
    defer visited.deinit();

    return @as(?usize, try floodFill(.{ 0, 0 }, garden, &visited, Part.one, this.allocator));
}

pub fn part2(this: *const @This()) !?usize {
    var garden = try parse(this.input, this.allocator);
    defer garden.map.deinit();

    var visited = CoordinateSet.init(this.allocator);
    defer visited.deinit();

    return @as(?usize, try floodFill(.{ 0, 0 }, garden, &visited, Part.two, this.allocator));
}

const Coordinates = @Vector(2, u8);
const Plot = union(enum) {
    inside: Coordinates,
    outside: void,

    fn isDifferentThan(self: Plot, l: u8, g: Garden) bool {
        return switch (self) {
            .inside => |c| g.map.get(c).? != l,
            .outside => true,
        };
    }

    fn isSameAs(self: Plot, l: u8, g: Garden) bool {
        return switch (self) {
            .inside => |c| g.map.get(c).? == l,
            .outside => false,
        };
    }
};

const CoordinateSet = std.HashMap(Coordinates, void, std.hash_map.AutoContext(Coordinates), std.hash_map.default_max_load_percentage);
const Map = std.HashMap(Coordinates, u8, std.hash_map.AutoContext(Coordinates), std.hash_map.default_max_load_percentage);
const Garden = struct {
    map: Map,
    width: u8,
    height: u8,
};

// The number of sides is equal to the number of corners.
//
// To recognize a corner you need to recognize the following two parterns. The
// patterns can present in all of the four positions, each rotated by 90
// degrees.
//
// The first pattern, the "external corner" is
//
// .Y
// XA
//
// `A` is the plot considered, `X` and `Y` must be both different than `A`, `.`
// can be whatever. A plot outside of the garden is condidered "different" than
// `A`
//
// In the following garden
//
// BBB
// BAB
// BBB
//
// The `A` plot has 4 corners
//
// .B.  .B.  ...  ...
// BA.  .AB  .AB  BA.
// ...  ...  .B.  .B.
//
// The second pattern, the "internal corner" is
//
// AX
// XY
//
// `A` is the plot considered, both `X` must be both equal to `A`, `Y` must be
// different than `A`.
//
// In the following garden
//
// AAA
// AAA
// AAX
//
// The `A` plot in the center has 1 corner
//
// The assumpiton here is that the region is made of the same letter/plantation
fn corners(region: CoordinateSet, g: Garden, allocator: std.mem.Allocator) !usize {
    var result: usize = 0;
    var plotFrame = std.ArrayList(Plot).init(allocator);
    defer plotFrame.deinit();

    // For every plot of the region
    var it = region.keyIterator();
    while (it.next()) |plotCoordinates| {
        const plotLetter = g.map.get(plotCoordinates.*).?;
        // Get all the plots in the frame of the considered plot
        try frame(plotCoordinates.*, g.width, g.height, &plotFrame);

        // We need to consider, to check the two patterns, three plot at times,
        // starting with the north/west corner (frame[0] = sx, frame[1] = sx +
        // up, frame[2] = up)
        for (0..4) |n| {
            const c1 = plotFrame.items[n * 2];
            const c2 = plotFrame.items[(n * 2) + 1];
            const c3 = plotFrame.items[((n * 2) + 2) % plotFrame.items.len];

            // Check pattern 1
            const isExternalCorner: bool = c1.isDifferentThan(plotLetter, g) and c3.isDifferentThan(plotLetter, g);
            if (isExternalCorner) {
                result += 1;
                continue;
            }

            // Check pattern 2
            const isInternalCorner: bool = c1.isSameAs(plotLetter, g) and c3.isSameAs(plotLetter, g) and c2.isDifferentThan(plotLetter, g);

            if (isInternalCorner) {
                result += 1;
            }
        }

        plotFrame.clearRetainingCapacity();
    }

    return result;
}

fn frame(x: Coordinates, width: u8, height: u8, result: *std.ArrayList(Plot)) !void {
    try result.append(if (x[0] > 0) Plot{ .inside = .{ x[0] - 1, x[1] } } else Plot{ .outside = undefined }); // sx
    try result.append(if (x[0] > 0 and x[1] > 0) Plot{ .inside = .{ x[0] - 1, x[1] - 1 } } else Plot{ .outside = undefined }); // up+sx
    try result.append(if (x[1] > 0) Plot{ .inside = .{ x[0], x[1] - 1 } } else Plot{ .outside = undefined }); // up
    try result.append(if (x[0] < (width - 1) and x[1] > 0) Plot{ .inside = .{ x[0] + 1, x[1] - 1 } } else Plot{ .outside = undefined }); // up+dx
    try result.append(if (x[0] < (width - 1)) Plot{ .inside = .{ x[0] + 1, x[1] } } else Plot{ .outside = undefined }); // dx
    try result.append(if (x[0] < (width - 1) and x[1] < (height - 1)) Plot{ .inside = .{ x[0] + 1, x[1] + 1 } } else Plot{ .outside = undefined }); // dx+down
    try result.append(if (x[1] < (height - 1)) Plot{ .inside = .{ x[0], x[1] + 1 } } else Plot{ .outside = undefined }); // down
    try result.append(if (x[0] > 0 and x[1] < (height - 1)) Plot{ .inside = .{ x[0] - 1, x[1] + 1 } } else Plot{ .outside = undefined }); // down+sx
}

test "it can count external corners" {
    const input =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    var garden = try parse(input, std.testing.allocator);
    defer garden.map.deinit();

    var regionA = CoordinateSet.init(std.testing.allocator);
    defer regionA.deinit();

    try regionA.put(.{ 0, 0 }, undefined);
    try regionA.put(.{ 1, 0 }, undefined);
    try regionA.put(.{ 2, 0 }, undefined);
    try regionA.put(.{ 3, 0 }, undefined);

    try std.testing.expectEqual(4, try corners(regionA, garden, std.testing.allocator));

    var regionB = CoordinateSet.init(std.testing.allocator);
    defer regionB.deinit();

    try regionB.put(.{ 0, 1 }, undefined);
    try regionB.put(.{ 0, 2 }, undefined);
    try regionB.put(.{ 1, 1 }, undefined);
    try regionB.put(.{ 1, 2 }, undefined);

    try std.testing.expectEqual(4, try corners(regionB, garden, std.testing.allocator));

    var regionC = CoordinateSet.init(std.testing.allocator);
    defer regionC.deinit();

    try regionC.put(.{ 2, 1 }, undefined);
    try regionC.put(.{ 2, 2 }, undefined);
    try regionC.put(.{ 3, 2 }, undefined);
    try regionC.put(.{ 3, 3 }, undefined);

    try std.testing.expectEqual(8, try corners(regionC, garden, std.testing.allocator));
}

test "it can count internal corners" {
    const input =
        \\AAA
        \\ABB
        \\AAA
    ;

    var garden = try parse(input, std.testing.allocator);
    defer garden.map.deinit();

    var regionA = CoordinateSet.init(std.testing.allocator);
    defer regionA.deinit();

    try regionA.put(.{ 0, 0 }, undefined);
    try regionA.put(.{ 1, 0 }, undefined);
    try regionA.put(.{ 2, 0 }, undefined);
    try regionA.put(.{ 0, 1 }, undefined);
    try regionA.put(.{ 0, 2 }, undefined);
    try regionA.put(.{ 1, 2 }, undefined);
    try regionA.put(.{ 2, 2 }, undefined);

    try std.testing.expectEqual(8, try corners(regionA, garden, std.testing.allocator));
}

fn neighbours(x: Coordinates, width: u8, height: u8, result: *std.ArrayList(Plot)) !void {
    try result.append(if (x[0] > 0) Plot{ .inside = .{ x[0] - 1, x[1] } } else Plot{ .outside = undefined }); // sx
    try result.append(if (x[0] < (width - 1)) Plot{ .inside = .{ x[0] + 1, x[1] } } else Plot{ .outside = undefined }); // dx
    try result.append(if (x[1] > 0) Plot{ .inside = .{ x[0], x[1] - 1 } } else Plot{ .outside = undefined }); // up
    try result.append(if (x[1] < (height - 1)) Plot{ .inside = .{ x[0], x[1] + 1 } } else Plot{ .outside = undefined }); // down
}

test neighbours {
    var coordinates = std.ArrayList(Plot).init(std.testing.allocator);
    defer coordinates.deinit();

    try neighbours(.{ 0, 0 }, 10, 10, &coordinates);
    try std.testing.expectEqualSlices(Plot, &.{
        Plot{ .outside = undefined },
        Plot{ .inside = .{ 1, 0 } },
        Plot{ .outside = undefined },
        Plot{ .inside = .{ 0, 1 } },
    }, coordinates.items);
    coordinates.clearRetainingCapacity();

    try neighbours(.{ 9, 9 }, 10, 10, &coordinates);
    try std.testing.expectEqualSlices(Plot, &.{
        Plot{ .inside = .{ 8, 9 } },
        Plot{ .outside = undefined },
        Plot{ .inside = .{ 9, 8 } },
        Plot{ .outside = undefined },
    }, coordinates.items);
    coordinates.clearRetainingCapacity();

    try neighbours(.{ 1, 1 }, 10, 10, &coordinates);
    try std.testing.expectEqualSlices(Plot, &.{
        Plot{ .inside = .{ 0, 1 } },
        Plot{ .inside = .{ 2, 1 } },
        Plot{ .inside = .{ 1, 0 } },
        Plot{ .inside = .{ 1, 2 } },
    }, coordinates.items);
    coordinates.clearRetainingCapacity();

    try neighbours(.{ 0, 5 }, 10, 10, &coordinates);
    try std.testing.expectEqualSlices(Plot, &.{
        Plot{ .outside = undefined },
        Plot{ .inside = .{ 1, 5 } },
        Plot{ .inside = .{ 0, 4 } },
        Plot{ .inside = .{ 0, 6 } },
    }, coordinates.items);
    coordinates.clearRetainingCapacity();

    try neighbours(.{ 5, 0 }, 10, 10, &coordinates);
    try std.testing.expectEqualSlices(Plot, &.{
        Plot{ .inside = .{ 4, 0 } },
        Plot{ .inside = .{ 6, 0 } },
        Plot{ .outside = undefined },
        Plot{ .inside = .{ 5, 1 } },
    }, coordinates.items);
    coordinates.clearRetainingCapacity();
}

const Part = enum { one, two };

fn floodFill(coordinates: Coordinates, garden: Garden, visited: *CoordinateSet, part: Part, allocator: std.mem.Allocator) !usize {
    const letter = garden.map.get(coordinates).?;

    try visited.put(coordinates, undefined);

    var toVisit = std.ArrayList(Plot).init(allocator);
    defer toVisit.deinit();

    var thisLot = CoordinateSet.init(allocator);
    defer thisLot.deinit();
    try thisLot.put(coordinates, undefined);

    var otherLots = std.ArrayList(Coordinates).init(allocator);
    defer otherLots.deinit();

    var area: usize = 1;
    var perimeter: usize = 0;
    var result: usize = 0;

    try neighbours(coordinates, garden.width, garden.height, &toVisit);
    while (toVisit.popOrNull()) |plot| {
        switch (plot) {
            .outside => {
                // outside will count to increase the perimeter of the lot
                perimeter += 1;
            },
            .inside => |c| {
                const l = garden.map.get(c).?;
                if (letter == l) {
                    try thisLot.put(c, undefined);
                    if (visited.contains(c)) continue;
                    // we are in the same lot, the area will increase
                    area += 1;
                    if (!visited.contains(c)) {
                        try visited.put(c, undefined);
                        try neighbours(c, garden.width, garden.height, &toVisit);
                    }
                } else {
                    // we crossed to another lot, the perimiter will increase
                    perimeter += 1;
                    if (!visited.contains(c)) {
                        try otherLots.append(c);
                    }
                }
            },
        }
    }

    for (otherLots.items) |c| {
        if (visited.contains(c)) continue;
        result += try floodFill(c, garden, visited, part, allocator);
    }

    const perimeterOrEdges = switch (part) {
        Part.one => perimeter,
        Part.two => try corners(thisLot, garden, allocator),
    };

    return result + (area * perimeterOrEdges);
}

fn parse(input: []const u8, allocator: std.mem.Allocator) !Garden {
    var map = Map.init(allocator);
    errdefer map.deinit();

    var lines = std.mem.splitScalar(u8, input, '\n');
    var width: usize = 0;
    var y: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        width = @max(width, line.len);

        for (line, 0..) |letter, x| try map.put(.{ @intCast(x), @intCast(y) }, letter);
        y += 1;
    }

    return Garden{
        .width = @intCast(width),
        .height = @intCast(y),
        .map = map,
    };
}

test parse {
    const input =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    var garden = try parse(input, std.testing.allocator);
    defer garden.map.deinit();

    try std.testing.expectEqual(4, garden.width);
    try std.testing.expectEqual(4, garden.height);
    try std.testing.expectEqual('A', garden.map.get(.{ 0, 0 }).?);
    try std.testing.expectEqual('C', garden.map.get(.{ 3, 3 }).?);
}

test "it shall work with the smallest example" {
    const input =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    var garden = try parse(input, std.testing.allocator);
    defer garden.map.deinit();

    var visited = CoordinateSet.init(std.testing.allocator);
    defer visited.deinit();

    try std.testing.expectEqual(140, floodFill(.{ 0, 0 }, garden, &visited, Part.one, std.testing.allocator));
}

test "it shall work with the another small example" {
    const input =
        \\OOOOO
        \\OXOXO
        \\OOOOO
        \\OXOXO
        \\OOOOO
    ;

    var garden = try parse(input, std.testing.allocator);
    defer garden.map.deinit();

    var visited = CoordinateSet.init(std.testing.allocator);
    defer visited.deinit();

    try std.testing.expectEqual(772, floodFill(.{ 0, 0 }, garden, &visited, Part.one, std.testing.allocator));
}

test "it should work for small inputdo nothing" {
    const allocator = std.testing.allocator;
    const input =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(1930, try problem.part1());
    try std.testing.expectEqual(1206, try problem.part2());
}
