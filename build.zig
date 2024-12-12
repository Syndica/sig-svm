const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_exe = b.addExecutable(.{
        .name = "svm",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_exe.linkLibC();

    b.installArtifact(main_exe);

    const run = b.addRunArtifact(main_exe);
    const run_step = b.step("run", "");
    if (b.args) |args| run.addArgs(args);
    run_step.dependOn(&run.step);

    // testing

    const test_step = b.step("test", "Run the test suite");
    const test_filter = b.option([]const u8, "test-filter", "");

    const lib_test_exe = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .filter = test_filter,
    });

    const svm_mod = b.addModule("svm", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const vm_test_exe = b.addTest(.{
        .root_source_file = b.path("tests/vm.zig"),
        .target = target,
        .optimize = optimize,
        .filter = test_filter,
    });
    vm_test_exe.root_module.addImport("svm", svm_mod);

    const elf_test_exe = b.addTest(.{
        .root_source_file = b.path("tests/elf.zig"),
        .target = target,
        .optimize = optimize,
        .filter = test_filter,
    });
    elf_test_exe.root_module.addImport("svm", svm_mod);

    inline for (&.{
        .{ lib_test_exe, "lib" },
        .{ vm_test_exe, "svm" },
        .{ elf_test_exe, "elf" },
    }) |entry| {
        const sub_step = b.step(b.fmt("test-{s}", .{entry[1]}), "");
        const test_run = b.addRunArtifact(entry[0]);
        sub_step.dependOn(&test_run.step);
        test_step.dependOn(sub_step);
    }

    // benchmarks

    const bench_exe = b.addExecutable(.{
        .name = "vm_bench",
        .root_source_file = b.path("bench/vm.zig"),
        .target = target,
        .optimize = optimize,
    });
    bench_exe.root_module.addImport("svm", svm_mod);

    const bench_run = b.addRunArtifact(bench_exe);
    const bench_run_step = b.step("bench", "Runs the benchmark");
    bench_run_step.dependOn(&bench_run.step);
    b.installArtifact(bench_exe);
}
