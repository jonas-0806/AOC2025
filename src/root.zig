const std = @import("std");
const aoc = @import("aoc.zig");

const puzzles_2025 = .{
    .{ .year = 2025, .day = 11, .solve = @import("2025/11.zig").solve },
};

pub fn run(allocator: std.mem.Allocator) !void {
    inline for (puzzles_2025) |d| try runPuzzle(allocator, d);
}

pub fn runLast(allocator: std.mem.Allocator) !void {
    try runPuzzle(allocator, puzzles_2025[puzzles_2025.len - 1]);
}

fn runPuzzle(allocator: std.mem.Allocator, p: anytype) !void {
    var puzzle: aoc.Puzzle(p.year, p.day) = try .init(allocator);
    defer puzzle.deinit();
    const start = try std.time.Instant.now();
    try p.solve(&puzzle);
    const end = try std.time.Instant.now();
    try puzzle.print(end.since(start) / std.time.ns_per_ms);
}

test "all" {
    std.testing.refAllDecls(@This());
}
