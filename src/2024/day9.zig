const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

pub fn part1(this: *const @This()) !?i64 {
    var disk = try parse(this.input, this.allocator);
    defer disk.deinit();
    defrag(disk.items);
    return @intCast(checksum(disk.items));
}

// TODO: too slow, needs improvement
//
// One priority queue with file clusters sorted by index, lowest first
// One priority queue with free clusters sorted by index, highest first
// List of file clusters as result
//
// Pick the first file cluster, search for first free cluster capable enough,
// the index of the free cluster must be < than the index of the file cluster.

// If not found, the file cluster stays there therefore put in the result list
// as it is.
//
// If found, take out the free cluster, change the starting index of the file
// cluster with the starting index of the free cluster, add it to the result
// list, put back the remaining free space if any.
//
// Continue until there's no file clusters in the priority queue.

pub fn part2(this: *const @This()) !?i64 {
    var disk = try parse(this.input, this.allocator);
    defer disk.deinit();
    defragWithoutSplit(disk.items);
    return @intCast(checksum(disk.items));
}

fn parse(input: []const u8, allocator: std.mem.Allocator) !Disk {
    var disk = Disk.init(allocator);
    var i: usize = 0;
    var fileId: u32 = 0;
    var blockIsFile: bool = true;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') continue;
        const n = try std.fmt.parseInt(u32, input[i..(i + 1)], 10);
        var j: usize = 0;
        if (blockIsFile) {
            while (j < n) : (j += 1) try disk.append(Block{ .file = fileId });
            fileId += 1;
        } else {
            while (j < n) : (j += 1) try disk.append(Block{ .empty = undefined });
        }
        blockIsFile = !blockIsFile;
    }
    return disk;
}

test parse {
    const expected: []const Block = &.{
        Block{ .file = 0 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 2 },
        Block{ .file = 2 },
        Block{ .file = 2 },
        Block{ .file = 2 },
        Block{ .file = 2 },
    };

    const actual = try parse("12345", std.testing.allocator);
    defer actual.deinit();
    try std.testing.expectEqualSlices(Block, expected, actual.items);
}

const Block = union(enum) { file: u32, empty: void };

const Disk = std.ArrayList(Block);

const Cluster = struct { usize, usize };

fn rightmostClusterOfFileBlocksBefore(disk: []Block, before: usize) Cluster {
    var j = before;
    while (j > 0 and @as(Block, disk[j]) == Block.empty) j -= 1;
    std.debug.assert(@as(Block, disk[j]) == Block.file);
    const endsAt = j;
    const fileId = disk[j].file;
    while (j > 0 and @as(Block, disk[j]) == Block.file and disk[j].file == fileId) j -= 1;
    const startsAt = j + 1;
    return .{ startsAt, endsAt };
}

fn leftmostClusterOfEmptyBlocksBetween(disk: []Block, from: usize, to: usize, neededCapacity: usize) ?Cluster {
    var i = from;
    while (i < to) {
        while (i < to and @as(Block, disk[i]) == Block.file) i += 1;
        if (i >= to) return null;
        std.debug.assert(@as(Block, disk[i]) == Block.empty);
        const startsAt = i;
        while (i < to and @as(Block, disk[i]) == Block.empty) i += 1;
        const endsAt = i - 1;
        const currentCapacity = endsAt - startsAt + 1;
        if (currentCapacity >= neededCapacity) {
            return .{ startsAt, endsAt };
        }
    }
    return null;
}

fn swapClusterOfBlocks(disk: []Block, left: usize, right: usize, len: usize) void {
    var k: usize = 0;
    var i = left;
    var j = right;
    while (k < len) : (k += 1) {
        const swap = disk[j];
        disk[j] = disk[i];
        disk[i] = swap;
        i += 1;
        j -= 1;
    }
}

fn defragWithoutSplit(disk: []Block) void {
    var i: usize = 0;
    var j: usize = disk.len - 1;
    while (i < j) {
        const fileStartAt, const fileEndAt = rightmostClusterOfFileBlocksBefore(disk, j);
        if (fileStartAt <= i) break;
        const fileClusterCapacity = fileEndAt - fileStartAt + 1;
        const emptyCluster = leftmostClusterOfEmptyBlocksBetween(disk, i, fileStartAt, fileClusterCapacity);
        if (emptyCluster != null) {
            swapClusterOfBlocks(disk, emptyCluster.?[0], fileEndAt, fileClusterCapacity);
        }
        j = fileStartAt - 1;
        i = 0;
    }
}

test defragWithoutSplit {
    var disk = [_]Block{
        Block{ .file = 0 },
        Block{ .file = 0 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 2 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .empty = undefined },
        Block{ .file = 4 },
        Block{ .file = 4 },
        Block{ .empty = undefined },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .empty = undefined },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .empty = undefined },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .empty = undefined },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 9 },
        Block{ .file = 9 },
    };

    try std.testing.expectEqualDeep(.{ 40, 41 }, rightmostClusterOfFileBlocksBefore(&disk, 41));
    try std.testing.expectEqualDeep(.{ 36, 39 }, rightmostClusterOfFileBlocksBefore(&disk, 39));
    try std.testing.expectEqualDeep(.{ 32, 34 }, rightmostClusterOfFileBlocksBefore(&disk, 35));

    try std.testing.expectEqualDeep(.{ 2, 4 }, leftmostClusterOfEmptyBlocksBetween(&disk, 0, 30, 3));
    try std.testing.expectEqualDeep(.{ 8, 10 }, leftmostClusterOfEmptyBlocksBetween(&disk, 5, 30, 3));
    try std.testing.expectEqualDeep(null, leftmostClusterOfEmptyBlocksBetween(&disk, 30, 41, 3));
    try std.testing.expectEqualDeep(null, leftmostClusterOfEmptyBlocksBetween(&disk, 0, 41, 5));

    const expected: []const Block = &.{
        Block{ .file = 0 },
        Block{ .file = 0 },
        Block{ .file = 9 },
        Block{ .file = 9 },
        Block{ .file = 2 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .empty = undefined },
        Block{ .file = 4 },
        Block{ .file = 4 },
        Block{ .empty = undefined },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .empty = undefined },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
    };

    defragWithoutSplit(&disk);
    try std.testing.expectEqualSlices(Block, expected, &disk);
}

fn defrag(disk: []Block) void {
    var i: usize = 0;
    var j: usize = disk.len - 1;
    while (i < j) {
        while (@as(Block, disk[i]) == Block.file and i < j) i += 1;
        while (@as(Block, disk[j]) == Block.empty and i < j) j -= 1;
        if (i < j) {
            std.debug.assert(@as(Block, disk[i]) == Block.empty);
            std.debug.assert(@as(Block, disk[j]) == Block.file);
            const swap = disk[j];
            disk[j] = disk[i];
            disk[i] = swap;
        }
    }
}

test defrag {
    var disk = [_]Block{
        Block{ .file = 0 },
        Block{ .file = 0 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 2 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .empty = undefined },
        Block{ .file = 4 },
        Block{ .file = 4 },
        Block{ .empty = undefined },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .empty = undefined },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .empty = undefined },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .empty = undefined },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 9 },
        Block{ .file = 9 },
    };

    const expected: []const Block = &.{
        Block{ .file = 0 },
        Block{ .file = 0 },
        Block{ .file = 9 },
        Block{ .file = 9 },
        Block{ .file = 8 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 2 },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .file = 6 },
        Block{ .file = 4 },
        Block{ .file = 4 },
        Block{ .file = 6 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
    };

    defrag(&disk);
    try std.testing.expectEqualSlices(Block, expected, &disk);
}

fn checksum(disk: []const Block) usize {
    var result: usize = 0;
    var i: usize = 0;
    while (i < disk.len) : (i += 1) {
        switch (disk[i]) {
            .file => |id| {
                result += id * i;
            },
            .empty => {
                // break;
            },
        }
    }
    return result;
}

test checksum {
    const disk: []const Block = &.{
        Block{ .file = 0 },
        Block{ .file = 0 },
        Block{ .file = 9 },
        Block{ .file = 9 },
        Block{ .file = 8 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 1 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 8 },
        Block{ .file = 2 },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .file = 7 },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .file = 3 },
        Block{ .file = 6 },
        Block{ .file = 4 },
        Block{ .file = 4 },
        Block{ .file = 6 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 5 },
        Block{ .file = 6 },
        Block{ .file = 6 },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
        Block{ .empty = undefined },
    };
    try std.testing.expectEqual(1928, checksum(disk));
}

test "it should work with small example" {
    const allocator = std.testing.allocator;
    const input = "2333133121414131402";

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(1928, try problem.part1());
    try std.testing.expectEqual(2858, try problem.part2());
}

test "it sholud work with additional small examples" {
    const allocator = std.testing.allocator;
    const input = "1313165";

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(169, try problem.part2());
}
