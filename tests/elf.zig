//! SVM testing via ELF-files

const std = @import("std");
const svm = @import("svm");

const Vm = svm.Vm;
const Elf = svm.Elf;
const Executable = svm.Executable;
const memory = svm.memory;
const MemoryMap = memory.MemoryMap;
const Region = memory.Region;

const expectEqual = std.testing.expectEqual;

test "BPF_64_64 sbpfv1" {
    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/reloc_64_64_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes);

    try testElfWithMemory(
        &elf,
        memory.PROGRAM_START + 0x120,
    );
}

test "BPF_64_RELATIVE sbpv1" {
    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/reloc_64_relative_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes);

    try testElfWithMemory(
        &elf,
        memory.PROGRAM_START + 0x138,
    );
}

test "BPF_64_RELATIVE data sbpv1" {
    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/reloc_64_relative_data_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes);

    try testElfWithMemory(
        &elf,
        memory.PROGRAM_START + 0x108,
    );
}

test "load elf rodata sbpfv1" {
    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/rodata_section_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes);

    try testElfWithMemory(
        &elf,
        42,
    );
}

fn testElfWithMemory(
    elf: *const Elf,
    expected: anytype,
) !void {
    const allocator = std.testing.allocator;
    var executable = try Executable.fromElf(allocator, elf);
    defer executable.deinit(allocator);

    const stack_memory = try allocator.alloc(u8, 4096);
    defer allocator.free(stack_memory);

    const m = try MemoryMap.init(&.{
        executable.getRoRegion(),
        Region.init(.writeable, stack_memory, memory.STACK_START),
        Region.init(.readable, &.{}, memory.HEAP_START),
        Region.init(.writeable, &.{}, memory.INPUT_START),
    }, .v1);

    var vm = try Vm.init(&executable, m, allocator);
    defer vm.deinit();

    const result = vm.run();
    try expectEqual(expected, result);
}
