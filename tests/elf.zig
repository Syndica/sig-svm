//! SVM testing via ELF-files

const std = @import("std");
const svm = @import("svm");

const Vm = svm.Vm;
const Elf = svm.Elf;
const Executable = svm.Executable;
const memory = svm.memory;
const MemoryMap = memory.MemoryMap;
const Region = memory.Region;
const ebpf = svm.ebpf;

const expectEqual = std.testing.expectEqual;

test "BPF_64_64 sbpfv1" {
    // [ 1] .text             PROGBITS        0000000000000120 000120 000018 00  AX  0   0  8
    // prints the address of the first byte in the .text section

    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/reloc_64_64_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, ebpf.MAX_FILE_SIZE);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes, allocator);

    try testElfWithMemory(
        &elf,
        memory.PROGRAM_START + 0x120,
    );
}

test "BPF_64_RELATIVE data sbpv1" {
    // [ 1] .text             PROGBITS        00000000000000e8 0000e8 000020 00  AX  0   0  8
    // [ 2] .rodata           PROGBITS        0000000000000108 000108 000019 01 AMS  0   0  1
    // prints the address of the first byte in the .rodata sections
    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/reloc_64_relative_data_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, ebpf.MAX_FILE_SIZE);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes, allocator);

    try testElfWithMemory(
        &elf,
        memory.PROGRAM_START + 0x108,
    );
}

test "BPF_64_RELATIVE sbpv1" {
    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/reloc_64_relative_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, ebpf.MAX_FILE_SIZE);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes, allocator);

    try testElfWithMemory(
        &elf,
        memory.PROGRAM_START + 0x138,
    );
}

test "load elf rodata sbpfv1" {
    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/rodata_section_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, ebpf.MAX_FILE_SIZE);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes, allocator);

    try testElfWithMemory(
        &elf,
        42,
    );
}

test "static internal call sbpv1" {
    const allocator = std.testing.allocator;

    const input_file = try std.fs.cwd().openFile("tests/elfs/static_internal_call_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, ebpf.MAX_FILE_SIZE);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes, allocator);

    try testElfWithMemory(
        &elf,
        10,
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
        Region.init(.mutable, stack_memory, memory.STACK_START),
        Region.init(.constant, &.{}, memory.HEAP_START),
        Region.init(.mutable, &.{}, memory.INPUT_START),
    }, .v1);

    var vm = try Vm.init(&executable, m, allocator);
    defer vm.deinit();

    const result = vm.run();
    try expectEqual(expected, result);
}
