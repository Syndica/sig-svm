const std = @import("std");
const Executable = @import("Executable.zig");
const ebpf = @import("ebpf.zig");
const Vm = @This();

const log = std.log.scoped(.vm);

allocator: std.mem.Allocator,
executable: *const Executable,
registers: std.EnumArray(ebpf.Instruction.Register, u64),

pub fn init(executable: *const Executable, allocator: std.mem.Allocator) !Vm {
    var vm: Vm = .{
        .executable = executable,
        .allocator = allocator,
        .registers = std.EnumArray(ebpf.Instruction.Register, u64).initFill(0),
    };
    vm.registers.set(.pc, executable.entry_pc);

    return vm;
}

pub fn deinit(vm: *Vm) void {
    _ = vm;
}

pub fn run(vm: *Vm) !void {
    while (try vm.step()) {}

    std.debug.print("r0 value: {}\n", .{vm.registers.get(.r0)});
}

fn step(vm: *Vm) !bool {
    const pc = vm.registers.get(.pc);
    var next_pc = pc + 1;
    const inst = vm.executable.instructions[pc];

    switch (inst.opcode) {
        .mov64_reg => vm.registers.set(inst.dst, vm.registers.get(inst.src)),
        .add64_imm => vm.registers.set(inst.dst, vm.registers.get(inst.dst) +% inst.imm),
        .call_imm => {
            const target_pc = inst.imm;
            next_pc = target_pc;
            std.debug.print("target pc: {}\n", .{target_pc});
        },
        else => std.debug.panic("TODO: step {s}", .{@tagName(inst.opcode)}),
    }

    vm.registers.set(.pc, next_pc);

    return true;
}
