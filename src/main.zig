const std = @import("std");
const builtin = @import("builtin");

const Elf = @import("Elf.zig");
const memory = @import("memory.zig");
const Executable = @import("Executable.zig");
const Vm = @import("Vm.zig");
const ebpf = @import("ebpf.zig");
const syscalls = @import("syscalls.zig");

const MemoryMap = memory.MemoryMap;

const TEST_INPUT = @embedFile("test_input.hex");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 100 }) = .{};
    defer _ = gpa.deinit();
    const allocator = if (builtin.mode == .Debug)
        gpa.allocator()
    else
        std.heap.c_allocator;

    var input_path: ?[]const u8 = null;
    var assemble: bool = false;

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-a")) {
            assemble = true;
            continue;
        }

        if (input_path) |file| {
            fail("input file already given: {s}", .{file});
        } else {
            input_path = arg;
        }
    }
    if (input_path == null) {
        fail("no input file provided", .{});
    }

    const input_file = try std.fs.cwd().openFile(input_path.?, .{});
    defer input_file.close();

    const bytes = try input_file.readToEndAlloc(allocator, ebpf.MAX_FILE_SIZE);
    defer allocator.free(bytes);

    var loader: Executable.BuiltinProgram = .{};
    defer loader.deinit(allocator);

    inline for (.{
        .{ "sol_log_", syscalls.log },
        .{ "sol_log_64_", syscalls.log64 },
        .{ "sol_log_pubkey", syscalls.logPubkey },
        .{ "sol_log_compute_units_", syscalls.logComputeUnits },
        .{ "sol_memset_", syscalls.memset },
        .{ "sol_memcpy_", syscalls.memcpy },
        .{ "abort", syscalls.abort },
    }) |entry| {
        const name, const function = entry;
        _ = try loader.functions.registerFunctionHashed(
            allocator,
            name,
            function,
        );
    }

    var executable = if (assemble)
        try Executable.fromAsm(allocator, bytes)
    else exec: {
        const elf = try Elf.parse(bytes, allocator, &loader);
        break :exec try Executable.fromElf(allocator, &elf);
    };
    defer executable.deinit(allocator);

    const input_mem = try allocator.alloc(u8, TEST_INPUT.len);
    defer allocator.free(input_mem);
    @memcpy(input_mem, TEST_INPUT);

    const heap_mem = try allocator.alloc(u8, 0x40000);
    defer allocator.free(heap_mem);
    @memset(heap_mem, 0x00);

    const stack_memory = try allocator.alloc(u8, 4096 * 64);
    defer allocator.free(stack_memory);
    @memset(stack_memory, 0);

    const m = try MemoryMap.init(&.{
        executable.getRoRegion(),
        memory.Region.init(.mutable, stack_memory, memory.STACK_START),
        memory.Region.init(.mutable, heap_mem, memory.HEAP_START),
        memory.Region.init(.mutable, input_mem, memory.INPUT_START),
    }, executable.version);

    var vm = try Vm.init(allocator, &executable, m, &loader);
    defer vm.deinit();
    const result = try vm.run();

    std.debug.print("result: {}, count: {}\n", .{ result, vm.instruction_count });
}

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(fmt ++ "\n", args) catch @panic("failed to print the stderr");
    std.posix.abort();
}
