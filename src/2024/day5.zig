const std = @import("std");
const mem = std.mem;

input: []const u8,
allocator: mem.Allocator,

const HashContext = struct {
    pub fn hash(_: @This(), s: Page) u32 {
        return @intCast(s);
    }
    pub fn eql(_: @This(), a: Page, b: Page, _: usize) bool {
        return a == b;
    }
};

const Page = u8;
const MaxPageNumber = 100;
const PageSet = std.bit_set.IntegerBitSet(MaxPageNumber);
const PageOrder = struct {
    before: PageSet,
    after: PageSet,

    fn init() PageOrder {
        return PageOrder{
            .before = PageSet.initEmpty(),
            .after = PageSet.initEmpty(),
        };
    }
};

const PageRules = std.ArrayHashMap(Page, PageOrder, HashContext, false);

const sortPages = struct {
    // A page  `l` comes before another  page `r` when given the  rules for page
    // `r`, `l` is one of the pages that must come before `r` and `l` is not one
    // of the pages that must come after `r`
    fn sort(rules: PageRules, l: Page, r: Page) bool {
        const rRules = rules.get(r).?;
        return rRules.before.isSet(l) and
            !rRules.after.isSet(l);
    }
}.sort;

const Part = enum { first, second };

pub fn run(this: *const @This(), part: Part) !?i64 {
    var result: u64 = 0;
    var lines = std.mem.splitScalar(u8, this.input, '\n');
    var rules = PageRules.init(this.allocator);
    var pages = try std.ArrayList(u8).initCapacity(this.allocator, 32);

    // processing rules
    while (lines.next()) |line| {
        if (line.len == 0) break;
        var tokens = std.mem.splitScalar(u8, line, '|');
        // X|Y
        const pageBefore = try std.fmt.parseInt(u8, tokens.next().?, 10);
        const pageAfter = try std.fmt.parseInt(u8, tokens.next().?, 10);
        // add Y to the set of pages that must come after X
        const pageBeforeRules = try rules.getOrPutValue(pageBefore, PageOrder.init());
        pageBeforeRules.value_ptr.*.after.set(pageAfter);
        // add X to the set of pages that must come before Y
        const pageAfterRules = try rules.getOrPutValue(pageAfter, PageOrder.init());
        pageAfterRules.value_ptr.*.before.set(pageBefore);
    }

    // processing updates
    while (lines.next()) |line| {
        if (line.len == 0) break;
        var before = PageSet.initEmpty();
        var after = PageSet.initEmpty();

        // populate a list of pages (needed after to get the middle one)
        // populate the list of pages that comes after
        var tokens = std.mem.splitScalar(u8, line, ',');
        while (tokens.next()) |token| {
            const page = try std.fmt.parseInt(u8, token, 10);
            after.set(page);
            try pages.append(page);
        }

        var inOrder = true;
        // for every page `page`
        for (pages.items) |page| {
            // the list is in order when in accordance with the rules of `page`
            const pageRules = rules.get(page);
            if (pageRules == null) continue;
            after.unset(page);
            // none of the pages before `page` in the list is one of the pages that must come after `page` and
            // none of the pages after `page` in the list is one of the pages that must come before `page`
            if (pageRules.?.after.intersectWith(before).count() > 0 or
                pageRules.?.before.intersectWith(after).count() > 0)
            {
                inOrder = false;
                break;
            }
            before.set(page);
        }
        switch (part) {
            Part.first => {
                if (inOrder) {
                    result += pages.items[(pages.items.len / 2)];
                }
            },
            Part.second => {
                if (!inOrder) {
                    std.mem.sort(u8, pages.items, rules, sortPages);
                    result += pages.items[(pages.items.len / 2)];
                }
            },
        }
        pages.clearRetainingCapacity();
    }

    rules.clearAndFree();
    pages.clearAndFree();

    return @intCast(result);
}

pub fn part1(this: *const @This()) !?i64 {
    return run(this, Part.first);
}

pub fn part2(this: *const @This()) !?i64 {
    return run(this, Part.second);
}

test "it should do nothing" {
    const allocator = std.testing.allocator;
    const input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;

    const problem: @This() = .{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(143, try problem.part1());
    try std.testing.expectEqual(123, try problem.part2());
}
