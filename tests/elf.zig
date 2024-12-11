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
        &.{},
        memory.PROGRAM_START + 0x120,
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
        &.{},
        42,
    );
}

fn testElfWithMemory(
    elf: *const Elf,
    program_memory: []const u8,
    expected: anytype,
) !void {
    const allocator = std.testing.allocator;
    var executable = try Executable.fromElf(elf);

    const mutable = try allocator.dupe(u8, program_memory);
    defer allocator.free(mutable);

    const m = try MemoryMap.init(&.{
        elf.getRoRegion() orelse Region.init(.readable, &.{}, memory.PROGRAM_START),
        Region.init(.readable, &.{}, memory.STACK_START),
        Region.init(.readable, &.{}, memory.HEAP_START),
        Region.init(.writeable, mutable, memory.INPUT_START),
    }, .v1);

    var vm = try Vm.init(&executable, m, allocator);
    defer vm.deinit();

    const result = vm.run();
    try expectEqual(expected, result);
}
