const std = @import("std");
const testing = std.testing;
const aoc = @import("../aoc.zig");

const Node = struct {
    path_counts: [4]i64,

    pub fn init() Node {
        return .{ .path_counts = .{0} ** 4 };
    }

    pub fn combine(self: Node, other: Node) Node {
        var combined_path_counts: [4]i64 = undefined;
        combined_path_counts[0] = self.path_counts[0] + other.path_counts[0];
        combined_path_counts[1] = self.path_counts[1] + other.path_counts[1];
        combined_path_counts[2] = self.path_counts[2] + other.path_counts[2];
        combined_path_counts[3] = self.path_counts[3] + other.path_counts[3];
        return Node{ .path_counts = combined_path_counts };
    }

    pub fn sawDac(self: *Node) void {
        std.debug.assert(self.path_counts[2] == 0);
        std.debug.assert(self.path_counts[3] == 0);
        if (self.path_counts[1] > 0) {
            self.path_counts[3] = self.path_counts[1];
        } else {
            self.path_counts[2] = self.path_counts[0];
            self.path_counts[0] = 0;
        }
    }

    pub fn sawFft(self: *Node) void {
        std.debug.assert(self.path_counts[1] == 0);
        std.debug.assert(self.path_counts[3] == 0);
        if (self.path_counts[2] > 0) {
            self.path_counts[3] = self.path_counts[2];
        } else {
            self.path_counts[1] = self.path_counts[0];
            self.path_counts[0] = 0;
        }
    }

    pub fn inc(self: *Node, hit_dac: bool, hit_fft: bool) void {
        const index: u2 = (@as(u2, @intFromBool(hit_dac)) << 1) + @as(u2, @intFromBool(hit_fft));
        self.path_counts[index] += 1;
    }
};

const Memoizer = struct {
    table: std.StringHashMap(Node),

    pub fn init(allocator: std.mem.Allocator) !Memoizer {
        var init_node = Node.init();
        init_node.inc(false, false);
        var table = std.StringHashMap(Node).init(allocator);
        try table.put("out", init_node);
        return .{ .table = table };
    }

    pub fn deinit(self: Memoizer) void {
        self.table.deinit();
    }

    pub fn get(self: Memoizer, key: []const u8) ?Node {
        return self.table.get(key);
    }

    pub fn register(self: *Memoizer, key: []const u8, node: Node) !void {
        std.debug.assert(self.get(key) == null);
        try self.table.put(key, node);
    }
};

pub fn solve(puzzle: *aoc.Puzzle(2025, 11)) !void {
    var it = puzzle.lines();
    var adj_list = std.StringHashMap([][]const u8).init(puzzle.allocator);
    defer {
        var adj_it = adj_list.valueIterator();
        while (adj_it.next()) |v| {
            puzzle.allocator.free(v.*);
        }
        adj_list.deinit();
    }
    while (it.next()) |l| {
        try addVertex(puzzle.allocator, &adj_list, l);
    }
    puzzle.part_one = dfs(adj_list, "you");

    var mem: Memoizer = try Memoizer.init(puzzle.allocator);
    const result = try dfs2(adj_list, &mem, "svr");
    puzzle.part_two = result.path_counts[3];
}

fn addVertex(allocator: std.mem.Allocator, adj_list: *std.StringHashMap([][]const u8), line: aoc.Line) !void {
    var iterator = line.tokenize(": ", .any);
    var edges: std.ArrayList([]const u8) = .empty;
    errdefer edges.deinit(allocator);
    const key = iterator.nextLine().?;
    while (iterator.nextLine()) |s| {
        try edges.append(allocator, s.raw);
    }
    try adj_list.put(key.raw, try edges.toOwnedSlice(allocator));
}

fn dfs(adj_list: std.StringHashMap([][]const u8), current: []const u8) i64 {
    if (std.mem.eql(u8, current, "out")) {
        return 1;
    }
    var sum: i64 = 0;

    const neighbors = adj_list.get(current);
    if (neighbors == null)
        return 0;
    for (neighbors.?) |s| {
        sum += dfs(adj_list, s);
    }
    return sum;
}

fn dfs2(adj_list: std.StringHashMap([][]const u8), mem: *Memoizer, current: []const u8) !Node {
    const computed = mem.get(current);
    if (computed != null) {
        return computed.?;
    }
    std.debug.assert(!std.mem.eql(u8, current, "out"));
    var result = Node.init();
    const neighbors = adj_list.get(current);
    if (neighbors == null)
        return Node.init();
    for (neighbors.?) |s| {
        result = result.combine(try dfs2(adj_list, mem, s));
    }
    if (std.mem.eql(u8, current, "dac")) {
        result.sawDac();
    } else if (std.mem.eql(u8, current, "fft")) {
        result.sawFft();
    }
    try mem.register(current, result);
    return result;
}

test "test_input_part_one" {
    const input =
        \\aaa: you hhh
        \\you: bbb ccc
        \\bbb: ddd eee
        \\ccc: ddd eee fff
        \\ddd: ggg
        \\eee: out
        \\fff: out
        \\ggg: out
        \\hhh: ccc fff iii
        \\iii: out
    ;

    var puzzle = aoc.Puzzle(2025, 11){ .allocator = testing.allocator, .raw_input = input };
    try solve(&puzzle);
    try testing.expectEqual(5, puzzle.part_one);
}

test "test_input_part_two" {
    const input =
        \\svr: aaa bbb
        \\aaa: fft
        \\fft: ccc
        \\bbb: tty
        \\tty: ccc
        \\ccc: ddd eee
        \\ddd: hub
        \\hub: fff
        \\eee: dac
        \\dac: fff
        \\fff: ggg hhh
        \\ggg: out
        \\hhh: out
    ;

    var puzzle = aoc.Puzzle(2025, 11){ .allocator = testing.allocator, .raw_input = input };
    try solve(&puzzle);
    try testing.expectEqual(2, puzzle.part_two);
}
