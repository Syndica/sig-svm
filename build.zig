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

    const lib_test_exe = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
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
    });
    vm_test_exe.root_module.addImport("svm", svm_mod);

    const elf_test_exe = b.addTest(.{
        .root_source_file = b.path("tests/elf.zig"),
        .target = target,
        .optimize = optimize,
    });
    elf_test_exe.root_module.addImport("svm", svm_mod);

    const test_step = b.step("test", "Run the test suite");

    inline for (&.{
        lib_test_exe,
        vm_test_exe,
        elf_test_exe,
    }) |exe| {
        const test_run = b.addRunArtifact(exe);
        test_step.dependOn(&test_run.step);
    }
}
