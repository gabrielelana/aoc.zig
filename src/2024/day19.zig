const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const Segment = struct { usize, usize };
const Memento = std.HashMap(Segment, usize, std.hash_map.AutoContext(Segment), std.hash_map.default_max_load_percentage);

const TrieNode = struct {
    const Self = @This();

    children: [26]?*TrieNode,
    endsWord: bool,

    fn create(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(TrieNode);
        self.endsWord = false;
        self.children = .{null} ** 26;
        return self;
    }

    fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        for (self.children) |child| if (child != null) child.?.destroy(allocator);
        allocator.destroy(self);
    }

    fn add(self: *Self, word: []const u8, allocator: std.mem.Allocator) !void {
        if (word.len == 0) return;
        const index = word[0] - 'a';
        std.debug.assert(index < 26);
        var child = if (self.children[index] == null) try Self.create(allocator) else self.children[index].?;
        try child.add(word[1..], allocator);
        child.endsWord = child.endsWord or word.len == 1;
        self.children[index] = child;
    }

    fn contains(self: Self, word: []const u8) bool {
        if (word.len == 0) return self.endsWord;
        const index = word[0] - 'a';
        std.debug.assert(index < 26);
        const child = self.children[index];
        if (child == null) return false;
        return child.?.contains(word[1..]);
    }

    // It took me a long time to figure this out but it simpler that it seems:
    // we have a recursive function, which is going to be called many times, the
    // only values that varies in the input are the `from` and `to` parameters,
    // therefore we can create a map between the pair (Segment) `.{from, to}`
    // and the result of the function... that's it, simple, logic 🤦
    fn countWordsCombinations(self: Self, input: []const u8, from: usize, to: usize, head: *TrieNode, memento: *Memento) !usize {
        if (memento.contains(.{ from, to })) {
            return memento.get(.{ from, to }).?;
        }

        // If we reached the end of the input and this node is the end of a
        // word, then we found a valid combination
        if (to > input.len) {
            return if (self.endsWord) 1 else 0;
        }

        const char = input[to - 1] - 'a';
        std.debug.assert(char < 26);
        const child = self.children[char];

        // No child means that the input slice (from, to) is not a valid word,
        // therefore from this route we stop the search for a word combination
        if (child == null) {
            return 0;
        }

        if (child.?.endsWord) {
            // This character is a valid word termination, but we cannot assume
            // that a possible longer word will not produce a result, therefore
            // we need to split our search

            // We keep going for a longer word
            const keepGoing = try child.?.countWordsCombinations(input, from, to + 1, head, memento);
            try memento.put(.{ from, to + 1 }, keepGoing);

            // We consider the current found word good and we start over with
            // the next character in input
            const startOver = try head.countWordsCombinations(input, to, to + 1, head, memento);
            try memento.put(.{ to, to + 1 }, startOver);
            return keepGoing + startOver;
        }

        // The current character is not the end character of a word, therefore
        // the only thing we can do is to keep going adding the next character
        // in input
        const keepGoing = try child.?.countWordsCombinations(input, from, to + 1, head, memento);
        try memento.put(.{ from, to + 1 }, keepGoing);
        return keepGoing;
    }
};

const Trie = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    head: *TrieNode,

    fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .head = try TrieNode.create(allocator),
        };
    }

    fn add(self: *Self, word: []const u8) !void {
        return self.head.add(word, self.allocator);
    }

    fn contains(self: Self, word: []const u8) bool {
        return self.head.contains(word);
    }

    fn countWordsCombinations(self: Self, input: []const u8) !usize {
        var memento = Memento.init(self.allocator);
        defer memento.deinit();
        return self.head.countWordsCombinations(input, 0, 1, self.head, &memento);
    }

    fn isMadeOfWords(self: Self, input: []const u8) !bool {
        return try self.countWordsCombinations(input) > 0;
    }

    fn deinit(self: Self) void {
        self.head.destroy(self.allocator);
    }
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !struct { Trie, [][]const u8 } {
    var patterns = std.ArrayList([]const u8).init(allocator);
    errdefer patterns.deinit();

    var trie = try Trie.init(allocator);
    errdefer trie.deinit();

    var lines = std.mem.splitScalar(u8, input, '\n');

    const header = lines.next().?;
    var towels = std.mem.splitSequence(u8, header, ", ");
    while (towels.next()) |towel| try trie.add(towel);

    while (lines.next()) |line| if (line.len > 0) try patterns.append(line);

    return .{ trie, try patterns.toOwnedSlice() };
}

pub fn part1(this: *const @This()) !?i64 {
    var trie, const patterns = try parse(this.input, this.allocator);
    defer {
        trie.deinit();
        this.allocator.free(patterns);
    }

    var result: usize = 0;
    for (patterns) |pattern| {
        if (try trie.countWordsCombinations(pattern) > 0) result += 1;
    }

    return @intCast(result);
}

pub fn part2(this: *const @This()) !?i64 {
    var trie, const patterns = try parse(this.input, this.allocator);
    defer {
        trie.deinit();
        this.allocator.free(patterns);
    }

    var result: usize = 0;
    for (patterns) |pattern| {
        result += try trie.countWordsCombinations(pattern);
    }

    return @intCast(result);
}

test "can work with a Trie" {
    var trie = try Trie.init(std.testing.allocator);
    defer trie.deinit();
    try trie.add("abc");
    try std.testing.expect(!trie.contains("ab"));
    try std.testing.expect(!trie.contains("abcd"));
    try std.testing.expect(trie.contains("abc"));
}

test "Trie.canParse" {
    var trie = try Trie.init(std.testing.allocator);
    defer trie.deinit();
    try trie.add("abc");
    try trie.add("ab");
    try trie.add("cd");
    try trie.add("de");
    try std.testing.expect(trie.contains("abc"));
    try std.testing.expect(trie.contains("de"));
    try std.testing.expect(try trie.countWordsCombinations("abcde") > 0);
    try std.testing.expect(try trie.countWordsCombinations("abcdde") > 0);
    try std.testing.expect(try trie.countWordsCombinations("abcabcc") == 0);
}

test "can parse input" {
    const input =
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    ;

    var trie, const patterns = try parse(input, std.testing.allocator);
    defer {
        trie.deinit();
        std.testing.allocator.free(patterns);
    }

    try std.testing.expectEqual(8, patterns.len);
    try std.testing.expect(trie.contains("bwu"));
}

test "it should work with small example" {
    const allocator = std.testing.allocator;
    const input =
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(6, try problem.part1());
    try std.testing.expectEqual(16, try problem.part2());
}
