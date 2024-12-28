const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const Point = @Vector(2, u8);
const PointSet = std.HashMap(Point, *Node, std.hash_map.AutoContext(Point), std.hash_map.default_max_load_percentage);

const Node = struct {
    point: Point,
    cost: usize,
    parent: ?*Node,
};

fn compareNodes(_: void, a: *Node, b: *Node) std.math.Order {
    if (a.cost < b.cost) return std.math.Order.lt;
    if (a.cost > b.cost) return std.math.Order.gt;
    return std.math.Order.eq;
}

const ToVisit = std.PriorityQueue(*Node, void, compareNodes);

fn pathLength(node: *Node) usize {
    var result: usize = 0;
    var current = node;
    while (current.parent != null) {
        result += 1;
        current = current.parent.?;
    }
    return result;
}

fn neighborsOf(point: Point, obstacles: PointSet, width: u8, height: u8, allocator: std.mem.Allocator) ![]Point {
    var points = std.ArrayList(Point).init(allocator);
    inline for (0..4) |i| {
        const next: ?Point = switch (i) {
            0 => if (point[0] + 1 < width) .{ point[0] + 1, point[1] } else null,
            1 => if (point[0] >= 1) .{ point[0] - 1, point[1] } else null,
            2 => if (point[1] + 1 < height) .{ point[0], point[1] + 1 } else null,
            3 => if (point[1] >= 1) .{ point[0], point[1] - 1 } else null,
            else => unreachable,
        };
        // We cannot use corrupted memory block, aka certain nodes to form the path,
        // we will skip this nodes when we are enumerating the neighbors
        if (next != null and !obstacles.contains(next.?)) {
            try points.append(next.?);
        }
    }
    return points.toOwnedSlice();
}

fn distanceBetween(from: Point, to: Point) usize {
    return @abs(@as(isize, from[0]) - @as(isize, to[0])) + @abs(@as(isize, from[1]) - @as(isize, to[1]));
}

fn solve(allocator: std.mem.Allocator, endPoint: Point, corrupted: PointSet) !?usize {
    // Every node will be kept in the same memory location, the following data
    // structure will keep only the pointer of a node, this is cool because we
    // don't need to create multiple copies of the same node and we can easily
    // free the memory of the arena at the end.
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nodeAllocator = arena.allocator();

    // Node to visit, sorted by the cost, lowest cost first, cost is the
    // distance between the current node and the target (endPoint), so that
    // nodes with the hipotetically shortest path will be checked first.
    var toVisit = ToVisit.init(allocator, undefined);
    defer toVisit.deinit();

    // We need a reverse index (Point -> *Node) because we need to check if need
    // to add a neighbor to the node to visit, but we already have one in the
    // same position it's better not to add both but to keep only the one with
    // lower cost, we could use `toVisit` but it will be a linear search.
    var nodeIndex = PointSet.init(allocator);
    defer nodeIndex.deinit();

    // We don't want to visit nodes already visisted
    var alreadyVisited = PointSet.init(allocator);
    defer alreadyVisited.deinit();

    // We start from the upper/left corner
    const start = try nodeAllocator.create(Node);
    start.point = .{ 0, 0 };
    start.cost = 0;
    start.parent = null;

    try toVisit.add(start);
    try nodeIndex.put(start.point, start);

    // For every node to visit, starting from the one with lowest cost
    while (toVisit.count() > 0) {
        // Remove from the list, unfortunately we need to keep both data
        // structure consistent, can be a bug source
        const node = toVisit.remove();
        _ = nodeIndex.remove(node.point);

        // If the we reached the end, then we are done
        if (node.point[0] == endPoint[0] and node.point[1] == endPoint[1]) {
            return @intCast(pathLength(node));
        }

        // Put into the already visited
        try alreadyVisited.put(node.point, undefined);

        // For each valid neighbor
        const neighbors: []Point = try neighborsOf(node.point, corrupted, endPoint[0] + 1, endPoint[1] + 1, allocator);
        defer allocator.free(neighbors);
        for (neighbors) |neighbor| {
            // Skip if already visited
            if (alreadyVisited.contains(neighbor)) continue;

            // Calculate the cost of neighbor
            const neighborCost = node.cost + distanceBetween(neighbor, endPoint);

            if (nodeIndex.contains(neighbor)) {
                // We already need to visit this neighbor, need to evaluate if
                // this neighbor is better then the one we already have to visit
                const needToVisit = nodeIndex.get(neighbor).?;
                if (neighborCost < needToVisit.cost) {
                    // This neighbor has a lower cost, therefore we replace the
                    // older with this (NOTE: since we are sharing pointers, we
                    // only need to change its values)
                    needToVisit.cost = neighborCost;
                    needToVisit.parent = node;
                }
            } else {
                // Add the new neighbor to the nodes to visit
                const next = try nodeAllocator.create(Node);
                next.point = neighbor;
                next.cost = neighborCost;
                next.parent = node;

                try toVisit.add(next);
                try nodeIndex.put(neighbor, next);
            }
        }
    }

    return null;
}

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]Point {
    var points = std.ArrayList(Point).init(allocator);
    errdefer points.deinit();

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(u8, tokens.next().?, 10);
        const y = try std.fmt.parseInt(u8, tokens.next().?, 10);
        try points.append(.{ x, y });
    }

    return points.toOwnedSlice();
}

fn searchBlock(allocator: std.mem.Allocator, endPoint: Point, startAt: usize, points: []Point) !?Point {
    var corrupted = PointSet.init(allocator);
    defer corrupted.deinit();
    for (points[0..startAt]) |point| try corrupted.put(point, undefined);

    // Use dichotomic to find a point where the end point is not reachable
    // anymore but at the point before it was
    var from = startAt;
    var to = points.len;
    while (from < to) {
        const middle = @divFloor(to - from, 2) + from;
        // NOTE: can be improved, but now it's fast enough
        for (points[startAt..]) |point| _ = corrupted.remove(point);
        for (points[startAt..middle]) |point| try corrupted.put(point, undefined);
        const resultForMiddle = try solve(allocator, endPoint, corrupted);
        if (resultForMiddle != null) {
            try corrupted.put(points[middle], undefined);
            const resultForNext = try solve(allocator, endPoint, corrupted);
            if (resultForNext == null) {
                // found it
                return points[middle];
            }
            from = middle + 1;
            continue;
        } else {
            to = middle;
        }
    }

    return null;
}

pub fn part1(this: *const @This()) !?usize {
    const endPoint: Point = .{ 70, 70 };
    const bytesLimit: usize = 1024;

    const corruptedPoints = try parse(this.input, this.allocator);
    defer this.allocator.free(corruptedPoints);

    var corrupted = PointSet.init(this.allocator);
    defer corrupted.deinit();
    for (corruptedPoints[0..bytesLimit]) |point| try corrupted.put(point, undefined);

    return try solve(this.allocator, endPoint, corrupted);
}

var searchResult: [10]u8 = undefined;
pub fn part2(this: *const @This()) !?[]const u8 {
    const endPoint: Point = .{ 70, 70 };
    const bytesLimitStartAt: usize = 1024;

    const corruptedPoints = try parse(this.input, this.allocator);
    defer this.allocator.free(corruptedPoints);

    const point = try searchBlock(this.allocator, endPoint, bytesLimitStartAt, corruptedPoints);
    if (point == null) return null;

    return try std.fmt.bufPrint(&searchResult, "{d},{d}", .{ point.?[0], point.?[1] });
}

test "it should do nothing" {
    const allocator = std.testing.allocator;
    const input =
        \\5,4
        \\4,2
        \\4,5
        \\3,0
        \\2,1
        \\6,3
        \\2,4
        \\1,5
        \\0,6
        \\3,3
        \\2,6
        \\5,1
        \\1,2
        \\5,5
        \\2,5
        \\6,5
        \\1,4
        \\0,4
        \\6,4
        \\1,1
        \\6,1
        \\1,0
        \\0,5
        \\1,6
        \\2,0
    ;

    const corruptedPoints = try parse(input, allocator);
    defer allocator.free(corruptedPoints);

    var corrupted = PointSet.init(allocator);
    defer corrupted.deinit();
    for (corruptedPoints[0..12]) |point| try corrupted.put(point, undefined);

    try std.testing.expectEqual(22, try solve(allocator, .{ 6, 6 }, corrupted));
    try std.testing.expectEqual(.{ 6, 1 }, (try searchBlock(allocator, .{ 6, 6 }, 12, corruptedPoints)).?);
}
