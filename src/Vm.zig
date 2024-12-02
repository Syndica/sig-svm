const std = @import("std");
const Input = @import("Input.zig");
const ebpf = @import("ebpf.zig");
const Vm = @This();

allocator: std.mem.Allocator,
input: *const Input,
instructions: []const ebpf.Instruction,

registers: std.EnumArray(ebpf.Instruction.Register, u64),

pub fn init(input: *const Input, allocator: std.mem.Allocator) !Vm {
    var vm: Vm = .{
        .input = input,
        .allocator = allocator,
        .registers = std.EnumArray(ebpf.Instruction.Register, u64).initFill(0),
        .instructions = try input.getInstructions(allocator),
    };

    vm.registers.set(.pc, input.entry_pc);

    return vm;
}

pub fn deinit(vm: *Vm) void {
    const allocator = vm.allocator;
    allocator.free(vm.instructions);
}

pub fn run(vm: *Vm) !void {
    while (try vm.step()) {}
}

fn step(vm: *Vm) !bool {
    const pc = vm.registers.get(.pc);
    const inst = vm.instructions[pc];

    std.debug.print("inst: {}\n", .{inst});

    return false;
}
