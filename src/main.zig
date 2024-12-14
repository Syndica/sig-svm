const std = @import("std");
const builtin = @import("builtin");

const Elf = @import("Elf.zig");
const memory = @import("memory.zig");
const MemoryMap = memory.MemoryMap;
const Executable = @import("Executable.zig");
const Vm = @import("Vm.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
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

    const bytes = try input_file.readToEndAlloc(allocator, 10 * 1024);
    defer allocator.free(bytes);

    var executable = if (assemble)
        try Executable.fromAsm(allocator, bytes)
    else exec: {
        const elf = try Elf.parse(bytes);
        break :exec try Executable.fromElf(allocator, &elf);
    };
    defer executable.deinit(allocator);

    const input_mem = try allocator.alloc(u8, 100);
    defer allocator.free(input_mem);
    @memset(input_mem, 0xAA);

    const stack_memory = try allocator.alloc(u8, 4096);
    defer allocator.free(stack_memory);

    const m = try MemoryMap.init(&.{
        executable.getRoRegion(),
        memory.Region.init(.writeable, stack_memory, memory.STACK_START),
        memory.Region.init(.writeable, &.{}, memory.HEAP_START),
        memory.Region.init(.readable, input_mem, memory.INPUT_START),
    }, executable.version);

    var vm = try Vm.init(&executable, m, allocator);
    defer vm.deinit();
    const result = try vm.run();

    std.debug.print("result: {}, count: {}\n", .{ result, vm.instruction_count });
}

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(fmt ++ "\n", args) catch @panic("failed to print the stderr");
    std.posix.abort();
}
