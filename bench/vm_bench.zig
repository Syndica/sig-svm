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
    const avg_ns, const num_instructions = try benchLong();
    std.debug.print("num inst: {}\n", .{num_instructions});
    std.debug.print(
        "avg: {}, avg: {}ns/inst\n",
        .{ std.fmt.fmtDuration(avg_ns), avg_ns / num_instructions },
    );
}

fn benchLong() !struct { u64, u64 } {
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
        Region.init(.constant, &.{}, memory.PROGRAM_START),
        Region.init(.mutable, stack_memory, memory.STACK_START),
        Region.init(.constant, &.{}, memory.HEAP_START),
        Region.init(.mutable, &.{}, memory.INPUT_START),
    }, .v1);

    return benchmarkVm(&executable, m, allocator);
}

fn benchSimple() !struct { u64, u64 } {
    const allocator = std.heap.c_allocator;
    const input_file = try std.fs.cwd().openFile("tests/elfs/rodata_section_sbpfv1.so", .{});
    const bytes = try input_file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(bytes);

    const elf = try Elf.parse(bytes);
    var executable = try Executable.fromElf(&elf);

    const stack_memory = try allocator.alloc(u8, 4096);
    defer allocator.free(stack_memory);

    const m = try MemoryMap.init(&.{
        executable.getRoRegion(),
        Region.init(.mutable, stack_memory, memory.STACK_START),
        Region.init(.constant, &.{}, memory.HEAP_START),
        Region.init(.mutable, &.{}, memory.INPUT_START),
    }, .v1);

    return benchmarkVm(&executable, m, allocator);
}

fn benchmarkVm(
    executable: *const Executable,
    m: MemoryMap,
    allocator: std.mem.Allocator,
) !struct { u64, u64 } {
    var total_ns: u64 = 0;
    var num_instructions: ?u64 = null;

    for (0..ITERS) |_| {
        var loader: Executable.BuiltinProgram = .{};
        var vm = try Vm.init(allocator, executable, m, &loader);
        defer vm.deinit();

        const start = try std.time.Instant.now();
        std.mem.doNotOptimizeAway(vm.run());
        const end = try std.time.Instant.now();
        const elapsed = end.since(start);
        total_ns += elapsed;
        if (num_instructions == null) num_instructions = vm.instruction_count;
    }

    return .{ total_ns / ITERS, num_instructions.? };
}
