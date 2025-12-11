const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("zaoc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    mod.addImport("clipboard", b.dependency("clipboard", .{}).module("clipboard"));
    // const roaring_dep = b.dependency("roaring", .{});
    // const roaring_mod = roaring_dep.module("roaring64_mod");
    // mod.addImport("roaring", roaring_mod);
    // Add the CRoaring C implementation
    //mod.addCSourceFile(.{
    //    .file = roaring_dep.path("croaring/roaring.c"),
    //    .flags = &.{"-std=c11"},
    //});
    //mod.addIncludePath(roaring_dep.path("croaring"));
    const exe = b.addExecutable(.{
        .name = "zaoc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zaoc", .module = mod },
            },
            }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
