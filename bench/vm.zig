const std = @import("std");
const svm = @import("svm");

const Vm = svm.Vm;
const Elf = svm.Elf;
const Executable = svm.Executable;
const memory = svm.memory;
const MemoryMap = memory.MemoryMap;
const Region = memory.Region;

const ITERS = 1_000;

pub fn main() !void {
    const avg_ns = try benchLong();
    std.debug.print("avg: {}\n", .{std.fmt.fmtDuration(avg_ns)});
}

fn benchLong() !u64 {
    const allocator = std.heap.c_allocator;

    var executable = try Executable.fromAsm(allocator,
        \\entrypoint:
        \\  mov r1, r2
        \\  and r1, 4095
        \\  mov r3, r10
        \\  sub r3, r1
        \\  add r3, -1
        \\  ldxb r4, [r3]
        \\  add r2, 1
        \\  jlt r2, 0x10000, -8
        \\  exit
    );
    defer executable.deinit(allocator);

    const stack_memory = try allocator.alloc(u8, 4096);
    defer allocator.free(stack_memory);

    const m = try MemoryMap.init(&.{
        Region.init(.readable, &.{}, memory.PROGRAM_START),
        Region.init(.writeable, stack_memory, memory.STACK_START),
        Region.init(.readable, &.{}, memory.HEAP_START),
        Region.init(.writeable, &.{}, memory.INPUT_START),
    }, .v1);

    return benchmarkVm(&executable, m, allocator);
}

fn benchSimple() !u64 {
    const allocator = std.heap.c_allocator;
    const input_file = try std.fs.cwd().openFile("tests/elfs/rodata_section_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes);
    var executable = try Executable.fromElf(&elf);

    const stack_memory = try allocator.alloc(u8, 4096);
    defer allocator.free(stack_memory);

    const m = try MemoryMap.init(&.{
        elf.getRoRegion() orelse Region.init(.readable, &.{}, memory.PROGRAM_START),
        Region.init(.writeable, stack_memory, memory.STACK_START),
        Region.init(.readable, &.{}, memory.HEAP_START),
        Region.init(.writeable, &.{}, memory.INPUT_START),
    }, .v1);

    const avg_ns = try benchmarkVm(&executable, m, allocator);
    return avg_ns;
}

fn benchmarkVm(
    executable: *const Executable,
    m: MemoryMap,
    allocator: std.mem.Allocator,
) !u64 {
    var total_ns: u64 = 0;
    for (0..ITERS) |_| {
        var vm = try Vm.init(executable, m, allocator);
        defer vm.deinit();

        const start = try std.time.Instant.now();
        std.mem.doNotOptimizeAway(vm.run());
        const end = try std.time.Instant.now();
        const elapsed = end.since(start);
        total_ns += elapsed;
    }

    return total_ns / ITERS;
}
