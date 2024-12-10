const std = @import("std");
const Executable = @import("Executable.zig");
const ebpf = @import("ebpf.zig");
const Vm = @This();

const log = std.log.scoped(.vm);

allocator: std.mem.Allocator,
executable: *const Executable,
registers: std.EnumArray(ebpf.Instruction.Register, u64),
depth: u64,

pub fn init(executable: *const Executable, allocator: std.mem.Allocator) !Vm {
    var vm: Vm = .{
        .executable = executable,
        .allocator = allocator,
        .registers = std.EnumArray(ebpf.Instruction.Register, u64).initFill(0),
        .depth = 0,
    };
    vm.registers.set(.pc, executable.entry_pc);

    return vm;
}

pub fn deinit(vm: *Vm) void {
    _ = vm;
}

pub fn run(vm: *Vm) !u64 {
    while (try vm.step()) {}
    return vm.registers.get(.r0);
}

fn step(vm: *Vm) !bool {
    const pc = vm.registers.get(.pc);
    const next_pc = pc + 1;
    const inst = vm.executable.instructions[pc];

    switch (inst.opcode) {
        .mov32_imm => vm.registers.set(inst.dst, inst.imm),
        .exit => {
            if (vm.depth == 0) {
                return false;
            }

            @panic("TODO: return from function");
        },
        else => std.debug.panic("TODO: step {}", .{inst}),
    }

    vm.registers.set(.pc, next_pc);

    return true;
}
