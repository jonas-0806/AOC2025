const std = @import("std");
const clipboard = @import("clipboard");

/// Requires an .aoc_session file at cwd with the session-cookie extracted (128 chars)
pub fn Puzzle(comptime year: u32, comptime day: u32) type {
    return struct {
        const Self = @This();

        part_one: i64 = 0,
        part_two: i64 = 0,

        allocator: std.mem.Allocator,
        raw_input: []const u8,

        /// Caches the puzzle_input in .aoc_cache
        pub fn init(allocator: std.mem.Allocator) !Self {
            const input = try getInput(allocator, year, day);
            return .{ .allocator = allocator, .raw_input = input };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.raw_input);
        }

        pub fn dump(self: Self) void {
            std.debug.print("{s}\n", .{self.trimmedInput()});
        }

        /// Copies the last non-zero part-solution to clipboard
        pub fn print(self: Self, ms: u64) !void {
            const bold_green = "\x1b[1;34m";
            const bold_red = "\x1b[1;31m";
            const reset = "\x1b[0m";
            var msbuf: [100]u8 = undefined;
            const ms_txt = try std.fmt.bufPrint(&msbuf, "{s}{d:0>3}{s}", .{
                if (ms > 50) bold_red else "", ms, reset
            });
            var buf: [1024]u8 = undefined;
            var text: []u8 = undefined;
            if (self.part_two > 0) {
                text = try std.fmt.bufPrint(&buf, "{d}", .{self.part_two});
                std.debug.print(
                    "[{d}/{d:0>2}.zig ({s} ms)]: one={d} two={s}{d}{s}\n",
                    .{ year, day, ms_txt, self.part_one, bold_green, self.part_two, reset },
                );
            } else {
                text = try std.fmt.bufPrint(&buf, "{d}", .{self.part_one});
                std.debug.print(
                    "[{d}/{d:0>2}.zig ({s} ms)]: one={s}{d}{s} two={d}\n",
                    .{ year, day, ms_txt, bold_green, self.part_one, reset, self.part_two },
                );
            }
            try clipboard.write(text);
        }

        pub fn trimmedInput(self: Self) []const u8 {
            return std.mem.trim(u8, self.raw_input, &std.ascii.whitespace);
        }

        pub fn line(self: Self) Line {
            return .{ .raw = self.trimmedInput() };
        }

        pub fn lines(self: Self) LineIterator {
            return LineIterator.init(self.trimmedInput());
        }

        pub fn ints(self: Self, comptime T: type) IntIterator(T) {
            return IntIterator(T).init(self.trimmedInput());
        }

        pub fn grid(self: Self, allocator: std.mem.Allocator) CharGrid {
            return CharGrid.init(self.trimmedInput(), allocator) catch unreachable;
        }
    };
}

fn getInput(allocator: std.mem.Allocator, year: u32, day: u32) ![]u8 {
    var cachebuf: [256]u8 = undefined;
    const cache_path = try std.fmt.bufPrint(&cachebuf, ".aoc_cache/{d}/{d}.in", .{ year, day });
    if (readCache(allocator, cache_path)) |b| return b;
    var urlbuf: [64]u8 = undefined;
    const url = try std.fmt.bufPrint(&urlbuf, "https://adventofcode.com/{d}/day/{d}/input", .{ year, day });
    const data = try fetchData(allocator, url);
    try writeCache(cache_path, data);
    return data;
}

fn fetchData(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    var sesbuf: [128]u8 = undefined;
    const session = std.fs.cwd().readFile(".aoc_session", &sesbuf) catch return error.MissingAocSession;
    if (session.len != 128)
        return error.InvalidAocSession;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var writer = std.Io.Writer.Allocating.init(allocator);
    errdefer writer.deinit();
    const result = try client.fetch(.{
        .location = .{ .url = url },
        .extra_headers = &[_]std.http.Header{
            .{ .name = "Cookie", .value = "session=" ++ session[0..128] },
        },
        .response_writer = &writer.writer,
    });
    if (result.status != .ok)
        return error.AdventOfCodeNetworkError;
    return writer.toOwnedSlice();
}

fn readCache(allocator: std.mem.Allocator, sub_path: []const u8) ?[]u8 {
    return std.fs.cwd().readFileAlloc(allocator, sub_path, 10 * 1024 * 1024) catch return null;
}

fn writeCache(sub_path: []const u8, data: []const u8) !void {
    const dir_name = std.fs.path.dirname(sub_path).?;
    try std.fs.cwd().makePath(dir_name);
    try std.fs.cwd().writeFile(.{ .data = data, .sub_path = sub_path });
}

pub const LineIterator = struct {
    const Self = @This();

    iterator: std.mem.TokenIterator(u8, .any),

    pub fn init(bytes: []const u8) Self {
        return .{ .iterator = std.mem.tokenizeAny(u8, bytes, "\r\n") };
    }

    pub fn next(self: *LineIterator) ?Line {
        const raw = self.iterator.next();
        if (raw) |r| return .{ .raw = r };
        return null;
    }

    pub fn peek(self: *LineIterator) ?Line {
        const raw = self.iterator.peek();
        if (raw) |r| return .{ .raw = r };
        return null;
    }
};

pub const Line = struct {
    const Self = @This();

    raw: []const u8,

    pub fn tokenize(self: Self, delimiters: []const u8, comptime delimiter_type: std.mem.DelimiterType) TokenIterator(delimiter_type) {
        const trimmed = std.mem.trim(u8, self.raw, &std.ascii.whitespace);
        return .{ .iterator = std.mem.TokenIterator(u8, delimiter_type){ .buffer = trimmed, .delimiter = delimiters, .index = 0 } };
    }

    pub fn toInt(self: Self, comptime T: type) !T {
        return try std.fmt.parseInt(T, self.raw, 10);
    }

    pub fn chars(self: Self) CharIterator {
        return .{ .buffer = self.raw };
    }

    pub fn dump(self: Self) void {
        std.debug.print("{s}\n", .{self.raw});
    }
};

pub const CharItem = struct {
    row: usize,
    col: usize,
    chr: u8,
};

pub const CharGrid = struct {
    const Self = @This();

    items: [][]u8,

    pub fn init(bytes: []const u8, allocator: std.mem.Allocator) !Self {
        var list: std.ArrayList([]u8) = try .initCapacity(allocator, bytes.len);
        defer list.deinit(allocator);
        var it = std.mem.tokenizeScalar(u8, bytes, '\n');
        while (it.next()) |l| try list.append(allocator, try allocator.dupe(u8, l));
        return .{ .items = try list.toOwnedSlice(allocator) };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.items) |i| allocator.free(i);
        allocator.free(self.items);
    }

    pub fn containsPos(self: Self, row: usize, col: usize) bool {
        return row >= 0 and row < self.items.len and col >= 0 and col < self.items[0].len;
    }

    pub fn adjacentCount(self: CharGrid, row: usize, col: usize, needle: u8) usize {
        var count: usize = 0;
        var items: [8]CharItem = undefined;
        for (self.adjacent(row, col, &items)) |a| {
            if (a.chr == needle) count += 1;
        }
        return count;
    }

    pub fn adjacent(self: Self, row: usize, col: usize, out: []CharItem) []CharItem {
        var n: usize = 0;
        const r: i32 = @intCast(row);
        const c: i32 = @intCast(col);
        const d = [_]i32{ -1, 0, 1 };
        inline for (d) |dr| {
            inline for (d) |dc| {
                if (dr == 0 and dc == 0) continue;
                if (self.item(r + dr, c + dc)) |ci| {
                    out[n] = ci;
                    n += 1;
                }
            }
        }
        return out[0..n];
    }

    pub fn item(self: Self, row: i32, col: i32) ?CharItem {
        if (row >= 0 and row < self.items.len and col >= 0 and col < self.items[0].len)
            return .{ .row = @intCast(row), .col = @intCast(col), .chr = self.items[@intCast(row)][@intCast(col)] };
        return null;
    }

    pub fn dump(self: Self) void {
        for (0..self.items.len) |row| {
            for (0..self.items[0].len) |col| {
                std.debug.print("{c}", .{self.items[row][col]});
            }
            std.debug.print("\n", .{});
        }
    }

};

pub const CharIterator = struct {
    buffer: []const u8,
    index: usize = 0,

    pub fn next(self: *CharIterator) ?u8 {
        if (self.index >= self.buffer.len) return null;
        defer self.index += 1;
        return self.buffer[self.index];
    }

    pub fn nextInt(self: *CharIterator, comptime T: type) ?T {
        if (self.index >= self.buffer.len) return null;
        defer self.index += 1;
        return std.fmt.parseInt(T, self.buffer[self.index .. self.index + 1], 10) catch unreachable;
    }

    pub fn collect(self: *CharIterator) []const u8 {
        var i: usize = 0;
        while (self.next()) |_| : (i+=1) {}
        return self.buffer[0..i];
    }
};

pub fn TokenIterator(delimiter_type: std.mem.DelimiterType) type {
    return struct {
        iterator: std.mem.TokenIterator(u8, delimiter_type),

        pub fn collectChars(self: *TokenIterator(delimiter_type), allocator: std.mem.Allocator) ![]const u8 {
            var al = try std.ArrayList(u8).initCapacity(allocator, 100);
            defer al.deinit(allocator);
            while (self.nextChar()) |c| try al.append(allocator, c);
            return try al.toOwnedSlice(allocator);
        }

        pub fn nextChar(self: *TokenIterator(delimiter_type)) ?u8 {
            if (self.iterator.peek() == null) return null;
            return self.iterator.next().?[0];
        }

        pub fn nextLine(self: *TokenIterator(delimiter_type)) ?Line {
            if (self.iterator.peek() == null) return null;
            return .{ .raw = self.iterator.next().? };
        }

        pub fn nextInt(self: *TokenIterator(delimiter_type), comptime T: type) ?T {
            if (self.iterator.peek() == null) return null;
            return std.fmt.parseInt(T, self.iterator.next().?, 10) catch unreachable;
        }

        pub fn nextFloat(self: *TokenIterator(delimiter_type), comptime T: type) ?T {
            if (self.iterator.peek() == null) return null;
            return std.fmt.parseFloat(T, self.iterator.next().?) catch unreachable;
        }
    };
}

pub fn IntIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        iterator: std.mem.SplitIterator(u8, .any),

        pub fn init(bytes: []const u8) Self {
            return .{ .iterator = std.mem.splitAny(u8, bytes, "\n") };
        }

        pub fn initDelimiters(bytes: []const u8, delimiters: []const u8) Self {
            return .{ .iterator = std.mem.splitAny(u8, bytes, delimiters) };
        }

        pub fn next(self: *Self) !?T {
            if (self.iterator.next()) |s| return try std.fmt.parseInt(T, s, 10);
            return null;
        }

        pub fn sum(self: *Self) T {
            var res: i64 = 0;
            while (self.next()) |i| res += i;
            return res;
        }

        pub fn collect(self: *Self, buf: []T) []T {
            var i: usize = 0;
            while (self.next()) |int| : (i += 1) buf[i] = int;
            return buf[0..i];
        }
    };
}

const testing = std.testing;
test "ez int line parsing" {
    const input =
        \\2199943210
        \\3987894921
        \\9856789892
        \\8767896789
        \\9899965678
    ;
    var puzzle: Puzzle(0, 0) = .{
        .allocator = testing.allocator,
        .raw_input = input,
    };

    var lit = puzzle.lines();
    var ints = puzzle.ints(usize);
    while (lit.next()) |line| {
        const int = ints.next();
        const line_int = try line.toInt(usize);
        try testing.expectEqual(int, line_int);
    }

    var lit2 = puzzle.lines();
    _ = lit2.next();
    _ = lit2.next();
    var line3 = lit2.next().?; //9856789892
    var chars = line3.chars();
    try testing.expectEqual(9, chars.nextInt(usize).?);
    try testing.expectEqual(8, chars.nextInt(usize).?);
    _ = chars.next();
    try testing.expectEqual(6, chars.nextInt(usize).?);
}

test "int line parsing" {
    const input =
        \\2199943210    120120201021
        \\3987894921    120
        \\9856789892    2321012
        \\8767896789    210101021120
        \\9899965678    210039391931
    ;
    var puzzle: Puzzle(0, 0) = .{
        .allocator = testing.allocator,
        .raw_input = input,
    };
    var tokens = puzzle.line().tokenize(&std.ascii.whitespace, .any);
    try testing.expectEqual(2199943210, tokens.nextInt(usize).?);
    try testing.expectEqual(120120201021, tokens.nextInt(usize).?);
}

test "ez char grid" {
    const input =
        \\.##.....##...##..#
        \\#..#..##...#######
        \\.........##.......
        \\..#.#...####..####
        \\#######.....######
        \\..................
    ;
    var puzzle: Puzzle(0, 0) = .{
        .allocator = testing.allocator,
        .raw_input = input,
    };
    var grid = puzzle.grid(puzzle.allocator);
    defer grid.deinit(puzzle.allocator);
    try testing.expectEqual('.', grid.items[0][0]);
    grid.items[0][0] = '#';
    try testing.expectEqual('#', grid.items[0][0]);
}

