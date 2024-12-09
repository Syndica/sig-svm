const std = @import("std");
const Input = @import("Input.zig");
const ebpf = @import("ebpf.zig");
const Vm = @This();

const log = std.log.scoped(.vm);

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

    std.debug.print("r0 value: {}\n", .{vm.registers.get(.r0)});
}

fn step(vm: *Vm) !bool {
    const pc = vm.registers.get(.pc);
    var next_pc = pc + 1;
    const inst = vm.instructions[pc];

    switch (inst.opcode) {
        .mov64_reg => vm.registers.set(inst.dst, vm.registers.get(inst.src)),
        .add64_imm => vm.registers.set(inst.dst, vm.registers.get(inst.dst) +% inst.imm),
        .call_imm => {
            const target_pc = inst.imm;
            next_pc = target_pc;
            std.debug.print("target pc: {}\n", .{target_pc});
        },
        .ld_dw_imm => {
            const large_immediate = @as(u64, inst.imm) | @as(u64, @bitCast(vm.instructions[pc + 1]));
            vm.registers.set(inst.dst, large_immediate);
            next_pc += 1;
        },
        else => std.debug.panic("TODO: step {s}", .{@tagName(inst.opcode)}),
    }

    vm.registers.set(.pc, next_pc);

    return true;
}
