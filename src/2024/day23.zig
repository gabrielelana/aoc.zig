const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

pub fn part1(this: *const @This()) !?usize {
    var g = try Network.parse(this.input, this.allocator);
    defer g.deinit();

    var cliques = try g.cliques3(this.allocator);
    defer cliques.deinit();

    var result: usize = 0;
    var it = cliques.keyIterator();
    while (it.next()) |clique| {
        if (clique.*[0][0] == 't' or
            clique.*[1][0] == 't' or
            clique.*[2][0] == 't') result += 1;
    }

    return result;
}

pub fn part2(this: *const @This()) !?[]u8 {
    var g = try Network.parse(this.input, this.allocator);
    defer g.deinit();

    var clique = try g.largestClique(this.allocator);
    defer clique.deinit();

    var result: ?[]u8 = null;
    result = try formatClique(clique, this.allocator);

    return result;
}

fn formatClique(clique: ComputerSet, allocator: std.mem.Allocator) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    var writer = buffer.writer();
    errdefer buffer.deinit();

    const sorter = try allocator.alloc(Computer, clique.count());
    defer allocator.free(sorter);

    {
        var it = clique.keyIterator();
        var i: usize = 0;
        while (it.next()) |v| : (i += 1) {
            sorter[i] = v.*;
        }
        std.mem.sort(Computer, sorter, {}, asc);
    }

    for (sorter, 0..) |e, i| {
        try writer.print("{c}{c}", .{ e[0], e[1] });
        if (i < sorter.len - 1) {
            try writer.print(",", .{});
        }
    }

    return buffer.toOwnedSlice();
}

const Computer = [2]u8;
const ComputerSet = std.HashMap(Computer, void, std.hash_map.AutoContext(Computer), std.hash_map.default_max_load_percentage);
const AdjacentSet = std.HashMap(Computer, ComputerSet, std.hash_map.AutoContext(Computer), std.hash_map.default_max_load_percentage);

const Clique3 = [3]Computer;
const Clique3Set = std.HashMap(Clique3, void, std.hash_map.AutoContext(Clique3), std.hash_map.default_max_load_percentage);

const Network = struct {
    const Self = @This();

    g: AdjacentSet,

    fn parse(input: []const u8, allocator: std.mem.Allocator) !Self {
        var g = AdjacentSet.init(allocator);
        var lines = std.mem.splitScalar(u8, input, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var vn1: [2]u8 = undefined;
            std.mem.copyForwards(u8, &vn1, line[0..2]);
            var vn2: [2]u8 = undefined;
            std.mem.copyForwards(u8, &vn2, line[3..5]);

            const v1 = try g.getOrPut(vn1);
            if (!v1.found_existing) {
                v1.value_ptr.* = ComputerSet.init(allocator);
            }
            try v1.value_ptr.*.put(vn2, undefined);

            const v2 = try g.getOrPut(vn2);
            if (!v2.found_existing) {
                v2.value_ptr.* = ComputerSet.init(allocator);
            }
            try v2.value_ptr.*.put(vn1, undefined);
        }
        return Self{ .g = g };
    }

    fn contains(self: Self, computer: Computer) bool {
        return self.g.contains(computer);
    }

    fn areAdjacent(self: Self, v1: Computer, v2: Computer) bool {
        const v = self.g.get(v1);
        if (v == null) return false;
        return v.?.contains(v2);
    }

    fn cliques3(self: Self, allocator: std.mem.Allocator) !Clique3Set {
        var result = Clique3Set.init(allocator);
        errdefer result.deinit();

        var visited = ComputerSet.init(allocator);
        defer visited.deinit();

        var toVisit = self.g.keyIterator();

        while (toVisit.next()) |n| {
            // if the vertex is already visited, then skip
            if (visited.contains(n.*)) continue;
            try visited.put(n.*, undefined);

            // for every vertex v in the adjacent set
            const adjacentSet = self.g.get(n.*).?;
            var adjacents = adjacentSet.keyIterator();
            while (adjacents.next()) |adjacent| {
                // get its the adjacent set and itersect them
                const adjacentOfAdjacentSet = self.g.get(adjacent.*).?;
                // intersect the two adjacent sets
                var it = intersect(adjacentSet, adjacentOfAdjacentSet);
                while (it.next()) |v| {
                    // every vertex of the intersection will form a clique with
                    // the other two vertex
                    var clique: Clique3 = .{ n.*, adjacent.*, v.* };
                    std.mem.sort([2]u8, &clique, {}, asc);
                    try result.put(clique, undefined);
                }
            }
        }
        return result;
    }

    fn isClique(self: Self, vertices: *ComputerSet, allocator: std.mem.Allocator) !bool {
        var list = std.ArrayList(Computer).init(allocator);
        defer list.deinit();

        var it = vertices.keyIterator();
        while (it.next()) |v| try list.append(v.*);

        // if every vertex must have an edge with every other vertex
        for (0..list.items.len) |i| {
            const v1 = list.items[i];
            for ((i + 1)..list.items.len) |j| {
                const v2 = list.items[j];
                if (!self.g.get(v1).?.contains(v2)) {
                    return false;
                }
            }
        }
        return true;
    }

    fn growCliqueStartingFrom(self: Self, clique: *ComputerSet, candidates: *ComputerSet, allocator: std.mem.Allocator) !void {
        var list = std.ArrayList(Computer).init(allocator);
        defer list.deinit();
        var it = candidates.keyIterator();
        while (it.next()) |v| try list.append(v.*);

        // for every vertex `v` in the list of candidates
        for (list.items) |v| {
            // if already in the click then skip
            if (clique.contains(v)) continue;
            try clique.put(v, undefined);
            if (try self.isClique(clique, allocator)) {
                // if adding `v` to the clique it's still a clique then remove
                // `v` from candidates and see if the clique with `v` can grow
                // larger than the largest found so far
                _ = candidates.remove(v);
                try self.growCliqueStartingFrom(clique, candidates, allocator);
                // put back the candidate in the pool
                try candidates.put(v, undefined);
            } else {
                _ = clique.remove(v);
            }
        }
    }

    fn largestClique(self: Self, allocator: std.mem.Allocator) !ComputerSet {
        var result = ComputerSet.init(allocator);
        errdefer result.deinit();

        var candidates = ComputerSet.init(allocator);
        defer candidates.deinit();

        var visited = ComputerSet.init(allocator);
        defer visited.deinit();

        var toVisit = self.g.keyIterator();

        while (toVisit.next()) |r| {
            if (visited.contains(r.*)) continue;
            try visited.put(r.*, undefined);

            var clique = ComputerSet.init(allocator);
            errdefer clique.deinit();
            try clique.put(r.*, undefined);

            var it = self.g.get(r.*).?.keyIterator();
            while (it.next()) |v| try candidates.put(v.*, undefined);
            try self.growCliqueStartingFrom(&clique, &candidates, allocator);
            candidates.clearRetainingCapacity();

            if (clique.count() > result.count()) {
                result.deinit();
                result = clique;
            } else {
                clique.deinit();
            }
        }

        return result;
    }

    fn deinit(self: *Self) void {
        var it = self.g.valueIterator();
        while (it.next()) |s| s.deinit();
        self.g.deinit();
    }
};

fn asc(_: void, a: Computer, b: Computer) bool {
    return if (a[0] == b[0]) a[1] < b[1] else a[0] < b[0];
}

const Iterator = struct {
    const Self = @This();

    _l: ComputerSet.KeyIterator,
    _r: ComputerSet.KeyIterator,
    _indexL: usize,
    _indexR: usize,

    fn next(self: *Self) ?*Computer {
        while (self._indexL < self._l.len) {
            if (!self._l.metadata[self._indexL].isUsed()) {
                self._indexL += 1;
                self._indexR = 0;
                continue;
            }
            const eL = self._l.items[self._indexL];
            while (self._indexR < self._r.len) {
                if (!self._r.metadata[self._indexR].isUsed()) {
                    self._indexR += 1;
                    continue;
                }
                const eR = self._r.items[self._indexR];
                self._indexR += 1;
                if (eL[0] == eR[0] and eL[1] == eR[1]) {
                    return &self._l.items[self._indexL];
                }
            }
            self._indexR = 0;
            self._indexL += 1;
        }
        return null;
    }
};

fn intersect(l: ComputerSet, r: ComputerSet) Iterator {
    return Iterator{
        ._l = l.keyIterator(),
        ._r = r.keyIterator(),
        ._indexL = 0,
        ._indexR = 0,
    };
}

test intersect {
    var l = ComputerSet.init(std.testing.allocator);
    defer l.deinit();
    var r = ComputerSet.init(std.testing.allocator);
    defer r.deinit();

    try l.put(.{ 'a', 'b' }, undefined);
    try l.put(.{ 'a', 'd' }, undefined);
    try l.put(.{ 'a', 'c' }, undefined);
    try r.put(.{ 'a', 'b' }, undefined);
    try r.put(.{ 'b', 'b' }, undefined);
    try r.put(.{ 'a', 'c' }, undefined);

    var intersection = ComputerSet.init(std.testing.allocator);
    defer intersection.deinit();

    var it = intersect(l, r);
    while (it.next()) |n| try intersection.put(n.*, undefined);

    try std.testing.expectEqual(2, intersection.count());
    try std.testing.expect(intersection.contains(.{ 'a', 'c' }));
    try std.testing.expect(intersection.contains(.{ 'a', 'b' }));
}

test "can parse input" {
    const input =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;

    var g = try Network.parse(input, std.testing.allocator);
    defer g.deinit();

    try std.testing.expect(g.contains(.{ 't', 'd' }));
    try std.testing.expect(g.areAdjacent(.{ 't', 'd' }, .{ 'y', 'n' }));
    try std.testing.expect(g.areAdjacent(.{ 'y', 'n' }, .{ 't', 'd' }));
}

test "cliques of three nodes" {
    const input =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;

    var g = try Network.parse(input, std.testing.allocator);
    defer g.deinit();

    var cliques = try g.cliques3(std.testing.allocator);
    defer cliques.deinit();

    try std.testing.expectEqual(12, cliques.count());
}

test "Network.isClique" {
    const input =
        \\aa-bb
        \\aa-cc
        \\bb-cc
        \\cc-dd
        \\aa-ee
    ;

    var g = try Network.parse(input, std.testing.allocator);
    defer g.deinit();

    var vertices = ComputerSet.init(std.testing.allocator);
    defer vertices.deinit();
    try vertices.put(.{ 'a', 'a' }, undefined);
    try vertices.put(.{ 'b', 'b' }, undefined);
    try vertices.put(.{ 'c', 'c' }, undefined);

    try std.testing.expect(try g.isClique(&vertices, std.testing.allocator));

    try vertices.put(.{ 'e', 'e' }, undefined);
    try std.testing.expect(!try g.isClique(&vertices, std.testing.allocator));
}

test "Network.largestCliqueStartingFrom" {
    const input =
        \\de-cg
        \\ka-co
        \\tb-ka
        \\ta-co
        \\de-co
        \\ta-ka
        \\de-ta
        \\ka-de
        \\kh-ta
        \\co-tc
    ;

    var g = try Network.parse(input, std.testing.allocator);
    defer g.deinit();

    var clique = ComputerSet.init(std.testing.allocator);
    defer clique.deinit();
    try clique.put(.{ 'd', 'e' }, undefined);

    var candidates = try g.g.get(.{ 'd', 'e' }).?.cloneWithAllocator(std.testing.allocator);
    defer candidates.deinit();

    try g.growCliqueStartingFrom(&clique, &candidates, std.testing.allocator);

    try std.testing.expectEqual(4, clique.count());
}

test "Network.largestClique" {
    const input =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;

    var g = try Network.parse(input, std.testing.allocator);
    defer g.deinit();

    var result = try g.largestClique(std.testing.allocator);
    defer result.deinit();

    try std.testing.expectEqual(4, result.count());

    const formatted = try formatClique(result, std.testing.allocator);
    defer std.testing.allocator.free(formatted);
    try std.testing.expectEqualSlices(u8, "co,de,ka,ta", formatted);
}

test "it should work with small input" {
    const allocator = std.testing.allocator;
    const input =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    const result2 = try problem.part2();
    defer allocator.free(result2.?);

    try std.testing.expectEqual(7, try problem.part1());
    try std.testing.expectEqualSlices(u8, "co,de,ka,ta", result2.?);
}
