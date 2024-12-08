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
    const registers = &vm.registers;
    const pc = registers.get(.pc);
    var next_pc: u64 = pc + 1;

    const instructions = vm.executable.instructions;
    const inst = instructions[pc];

    switch (inst.opcode) {
        .add64_reg => registers.set(inst.dst, registers.get(inst.dst) +% registers.get(inst.src)),
        .add64_imm => registers.set(
            inst.dst,
            registers.get(inst.dst) +% @as(u64, @bitCast(@as(i64, @as(i32, @bitCast(inst.imm))))),
        ),
        .add32_reg => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) +% @as(u32, @truncate(registers.get(inst.src))),
        ),
        .add32_imm => registers.set(
            inst.dst,
            @bitCast(@as(i64, @as(i32, @bitCast(@as(u32, @truncate(registers.get(inst.dst))) +% inst.imm)))),
        ),

        .mul64_reg => registers.set(
            inst.dst,
            registers.get(inst.dst) *% registers.get(inst.src),
        ),
        .mul64_imm => registers.set(
            inst.dst,
            registers.get(inst.dst) *% inst.imm,
        ),
        .mul32_reg => registers.set(
            inst.dst,
            @bitCast(@as(i64, @as(i32, @bitCast(@as(u32, @truncate(registers.get(inst.dst))))) *%
                @as(i32, @bitCast(@as(u32, @truncate(registers.get(inst.src))))))),
        ),
        .mul32_imm => registers.set(
            inst.dst,
            @bitCast(@as(i64, @as(i32, @bitCast(@as(u32, @truncate(registers.get(inst.dst))))) *%
                @as(i32, @bitCast(inst.imm)))),
        ),

        .mov64_reg => registers.set(inst.dst, registers.get(inst.src)),
        .mov64_imm => registers.set(inst.dst, inst.imm),
        .mov32_reg => registers.set(inst.dst, @as(u32, @truncate(registers.get(inst.src)))),
        .mov32_imm => registers.set(inst.dst, @as(u32, @truncate(inst.imm))),

        .div64_reg => registers.set(inst.dst, try std.math.divTrunc(u64, registers.get(inst.dst), registers.get(inst.src))),
        .div64_imm => registers.set(inst.dst, try std.math.divTrunc(u64, registers.get(inst.dst), inst.imm)),
        .div32_reg => registers.set(
            inst.dst,
            try std.math.divTrunc(u32, @truncate(registers.get(inst.dst)), @truncate(registers.get(inst.src))),
        ),
        .div32_imm => registers.set(
            inst.dst,
            try std.math.divTrunc(u32, @truncate(registers.get(inst.dst)), inst.imm),
        ),

        .lsh64_imm => registers.set(inst.dst, std.math.rotl(u64, registers.get(inst.dst), inst.imm)),

        .rsh64_imm => registers.set(inst.dst, std.math.rotr(u64, registers.get(inst.dst), inst.imm)),

        .ja => next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off),
        .jeq_imm => {
            if (registers.get(inst.dst) == inst.imm) {
                next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
            }
        },

        .exit => {
            if (vm.depth == 0) {
                return false;
            }
            @panic("TODO: return from function");
        },
        .ld_dw_imm => {
            const value: u64 = (@as(u64, instructions[next_pc].imm) << 32) | inst.imm;
            registers.set(inst.dst, value);
            next_pc += 1;
        },

        else => std.debug.panic("TODO: step {}", .{inst}),
    }

    vm.registers.set(.pc, next_pc);
    return true;
}
