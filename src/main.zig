const std = @import("std");
const zaoc = @import("zaoc");

pub fn main() !void {
    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();

    try zaoc.runLast(gpa.allocator());
}
