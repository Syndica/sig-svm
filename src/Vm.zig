const std = @import("std");
const Executable = @import("Executable.zig");
const ebpf = @import("ebpf.zig");
const memory = @import("memory.zig");
const MemoryMap = memory.MemoryMap;
const Vm = @This();

const log = std.log.scoped(.vm);

allocator: std.mem.Allocator,
executable: *const Executable,

registers: std.EnumArray(ebpf.Instruction.Register, u64),
memory_map: MemoryMap,

stack_pointer: u64,
call_frames: std.ArrayListUnmanaged(CallFrame),
depth: u64,
instruction_count: u64,

pub fn init(
    executable: *const Executable,
    memory_map: MemoryMap,
    allocator: std.mem.Allocator,
) !Vm {
    var vm: Vm = .{
        .executable = executable,
        .allocator = allocator,
        .registers = std.EnumArray(ebpf.Instruction.Register, u64).initFill(0),
        .memory_map = memory_map,
        .stack_pointer = 0,
        .depth = 0,
        .call_frames = try std.ArrayListUnmanaged(CallFrame).initCapacity(allocator, 64),
        .instruction_count = 0,
    };

    vm.registers.set(.r10, memory.STACK_START + 4096);
    vm.registers.set(.r1, memory.INPUT_START);
    vm.registers.set(.pc, executable.entry_pc);

    return vm;
}

pub fn deinit(vm: *Vm) void {
    vm.call_frames.deinit(vm.allocator);
}

pub fn run(vm: *Vm) !u64 {
    while (try vm.step()) {
        vm.instruction_count += 1;
    }
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
        .add64_imm => {
            registers.set(
                inst.dst,
                registers.get(inst.dst) +% @as(u64, @bitCast(@as(i64, @as(i32, @bitCast(inst.imm))))),
            );
        },
        .add32_reg => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) +% @as(u32, @truncate(registers.get(inst.src))),
        ),
        .add32_imm => registers.set(
            inst.dst,
            @bitCast(@as(i64, @as(i32, @bitCast(@as(u32, @truncate(registers.get(inst.dst))) +% inst.imm)))),
        ),

        .mul64_reg => registers.set(inst.dst, registers.get(inst.dst) *% registers.get(inst.src)),
        .mul64_imm => registers.set(inst.dst, registers.get(inst.dst) *% inst.imm),
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

        .sub64_reg => registers.set(inst.dst, registers.get(inst.dst) -% registers.get(inst.src)),
        .sub64_imm => registers.set(inst.dst, registers.get(inst.dst) -% inst.imm),
        .sub32_reg => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) -% @as(u32, @truncate(registers.get(inst.src))),
        ),
        .sub32_imm => registers.set(inst.dst, @as(u32, @truncate(registers.get(inst.dst))) -% inst.imm),

        .div64_reg => registers.set(
            inst.dst,
            try std.math.divTrunc(
                u64,
                registers.get(inst.dst),
                registers.get(inst.src),
            ),
        ),
        .div64_imm => registers.set(
            inst.dst,
            try std.math.divTrunc(
                u64,
                registers.get(inst.dst),
                inst.imm,
            ),
        ),
        .div32_reg => registers.set(
            inst.dst,
            try std.math.divTrunc(
                u32,
                @truncate(registers.get(inst.dst)),
                @truncate(registers.get(inst.src)),
            ),
        ),
        .div32_imm => registers.set(
            inst.dst,
            try std.math.divTrunc(
                u32,
                @truncate(registers.get(inst.dst)),
                inst.imm,
            ),
        ),

        .xor64_reg => registers.set(inst.dst, registers.get(inst.dst) ^ registers.get(inst.src)),
        .xor64_imm => registers.set(inst.dst, registers.get(inst.dst) ^ inst.imm),
        .xor32_reg => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) ^ @as(u32, @truncate(registers.get(inst.src))),
        ),
        .xor32_imm => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) ^ inst.imm,
        ),

        .or64_reg => registers.set(inst.dst, registers.get(inst.dst) | registers.get(inst.src)),
        .or64_imm => registers.set(inst.dst, registers.get(inst.dst) | inst.imm),
        .or32_reg => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) | @as(u32, @truncate(registers.get(inst.src))),
        ),
        .or32_imm => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) | inst.imm,
        ),

        .and64_reg => registers.set(inst.dst, registers.get(inst.dst) & registers.get(inst.src)),
        .and64_imm => registers.set(inst.dst, registers.get(inst.dst) & inst.imm),
        .and32_reg => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) & @as(u32, @truncate(registers.get(inst.src))),
        ),
        .and32_imm => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) & inst.imm,
        ),

        .mod64_reg => registers.set(
            inst.dst,
            try std.math.mod(
                u64,
                registers.get(inst.dst),
                registers.get(inst.src),
            ),
        ),
        .mod64_imm => registers.set(
            inst.dst,
            try std.math.mod(
                u64,
                registers.get(inst.dst),
                inst.imm,
            ),
        ),
        .mod32_reg => registers.set(
            inst.dst,
            try std.math.mod(
                u32,
                @truncate(registers.get(inst.dst)),
                @truncate(registers.get(inst.src)),
            ),
        ),
        .mod32_imm => registers.set(
            inst.dst,
            try std.math.mod(
                u32,
                @truncate(registers.get(inst.dst)),
                inst.imm,
            ),
        ),

        .arsh64_reg => registers.set(
            inst.dst,
            @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) >> @truncate(registers.get(inst.src))),
        ),
        .arsh64_imm => registers.set(
            inst.dst,
            @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) >> @truncate(inst.imm)),
        ),
        .arsh32_reg => registers.set(
            inst.dst,
            @as(u32, @bitCast(@as(i32, @bitCast(@as(u32, @truncate(registers.get(inst.dst))))) >>
                @truncate(registers.get(inst.src)))),
        ),
        .arsh32_imm => registers.set(
            inst.dst,
            @as(u32, @bitCast(@as(i32, @bitCast(@as(u32, @truncate(registers.get(inst.dst))))) >>
                @truncate(inst.imm))),
        ),

        .mov64_reg => registers.set(inst.dst, registers.get(inst.src)),
        .mov64_imm => {
            registers.set(inst.dst, @bitCast(@as(i64, @as(i32, @bitCast(inst.imm)))));
        },
        .mov32_reg => registers.set(inst.dst, @as(u32, @truncate(registers.get(inst.src)))),
        .mov32_imm => registers.set(inst.dst, @as(u32, @truncate(inst.imm))),

        .neg32 => registers.set(
            inst.dst,
            @as(u32, @truncate(@as(u64, @bitCast(@as(i64, -@as(i32, @bitCast(@as(u32, @truncate(registers.get(inst.dst)))))))))),
        ),
        .neg64 => registers.set(inst.dst, @bitCast(-@as(i64, @bitCast(registers.get(inst.dst))))),

        .lsh64_reg => registers.set(inst.dst, registers.get(inst.dst) << @truncate(registers.get(inst.src))),
        .lsh64_imm => registers.set(inst.dst, registers.get(inst.dst) << @truncate(inst.imm)),
        .lsh32_reg => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) << @truncate(registers.get(inst.src)),
        ),
        .lsh32_imm => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) << @truncate(inst.imm),
        ),

        .rsh64_reg => registers.set(inst.dst, registers.get(inst.dst) >> @truncate(registers.get(inst.src))),
        .rsh64_imm => registers.set(inst.dst, registers.get(inst.dst) >> @truncate(inst.imm)),
        .rsh32_reg => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) >> @truncate(registers.get(inst.src)),
        ),
        .rsh32_imm => registers.set(
            inst.dst,
            @as(u32, @truncate(registers.get(inst.dst))) >> @truncate(inst.imm),
        ),

        .ld_b_reg => {
            const vm_addr: u64 = @intCast(@as(i64, @intCast(registers.get(inst.src))) +% inst.off);
            registers.set(inst.dst, try vm.load(u8, vm_addr));
        },
        .ld_h_reg => {
            const vm_addr: u64 = @intCast(@as(i64, @intCast(registers.get(inst.src))) +% inst.off);
            registers.set(inst.dst, try vm.load(u16, vm_addr));
        },
        .ld_w_reg => {
            const vm_addr: u64 = @intCast(@as(i64, @intCast(registers.get(inst.src))) +% inst.off);
            registers.set(inst.dst, try vm.load(u32, vm_addr));
        },
        .ld_dw_reg => {
            const vm_addr: u64 = @intCast(@as(i64, @intCast(registers.get(inst.src))) +% inst.off);
            registers.set(inst.dst, try vm.load(u64, vm_addr));
        },
        .ld_dw_imm => {
            const value: u64 = (@as(u64, instructions[next_pc].imm) << 32) | inst.imm;
            registers.set(inst.dst, value);
            next_pc += 1;
        },

        .st_b_reg => {
            const vm_addr: u64 = @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) +% inst.off);
            try vm.store(u8, vm_addr, @truncate(registers.get(inst.src)));
        },
        .st_h_reg => {
            const vm_addr: u64 = @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) +% inst.off);
            try vm.store(u16, vm_addr, @truncate(registers.get(inst.src)));
        },
        .st_w_reg => {
            const vm_addr: u64 = @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) +% inst.off);
            try vm.store(u32, vm_addr, @truncate(registers.get(inst.src)));
        },
        .st_dw_reg => {
            const vm_addr: u64 = @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) +% inst.off);
            try vm.store(u64, vm_addr, registers.get(inst.src));
        },

        .st_b_imm => {
            const vm_addr: u64 = @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) +% inst.off);
            try vm.store(u8, vm_addr, @truncate(inst.imm));
        },
        .st_h_imm => {
            const vm_addr: u64 = @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) +% inst.off);
            try vm.store(u16, vm_addr, @truncate(inst.imm));
        },
        .st_w_imm => {
            const vm_addr: u64 = @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) +% inst.off);
            try vm.store(u32, vm_addr, @truncate(inst.imm));
        },
        .st_dw_imm => {
            const vm_addr: u64 = @bitCast(@as(i64, @bitCast(registers.get(inst.dst))) +% inst.off);
            try vm.store(u64, vm_addr, inst.imm);
        },

        .be => registers.set(inst.dst, switch (inst.imm) {
            inline //
            16,
            32,
            64,
            => |size| std.mem.nativeToBig(
                std.meta.Int(.unsigned, size),
                @truncate(registers.get(inst.dst)),
            ),
            else => return error.InvalidInstruction,
        }),
        .le => registers.set(inst.dst, switch (inst.imm) {
            inline //
            16,
            32,
            64,
            => |size| std.mem.nativeToLittle(
                std.meta.Int(.unsigned, size),
                @truncate(registers.get(inst.dst)),
            ),
            else => return error.InvalidInstruction,
        }),

        .ja => next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off),
        .jeq_imm => if (registers.get(inst.dst) == inst.imm) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jeq_reg => if (registers.get(inst.dst) == registers.get(inst.src)) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jne_imm => if (registers.get(inst.dst) != inst.imm) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jne_reg => if (registers.get(inst.dst) != registers.get(inst.src)) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jge_imm => if (registers.get(inst.dst) >= inst.imm) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jge_reg => if (registers.get(inst.dst) >= registers.get(inst.src)) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jgt_imm => if (registers.get(inst.dst) > inst.imm) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jgt_reg => if (registers.get(inst.dst) > registers.get(inst.src)) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jle_imm => if (registers.get(inst.dst) <= inst.imm) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jle_reg => if (registers.get(inst.dst) <= registers.get(inst.src)) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jlt_imm => if (registers.get(inst.dst) < inst.imm) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jlt_reg => if (registers.get(inst.dst) < registers.get(inst.src)) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jset_imm => if (registers.get(inst.dst) & inst.imm != 0) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jset_reg => if (registers.get(inst.dst) & registers.get(inst.src) != 0) {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },

        .jsge_imm => if (@as(i64, @bitCast(registers.get(inst.dst))) >=
            @as(i64, @as(i32, @bitCast(inst.imm))))
        {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jsge_reg => if (@as(i64, @bitCast(registers.get(inst.dst))) >=
            @as(i64, @bitCast(registers.get(inst.src))))
        {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jsgt_imm => if (@as(i64, @bitCast(registers.get(inst.dst))) >
            @as(i64, @as(i32, @bitCast(inst.imm))))
        {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jsgt_reg => if (@as(i64, @bitCast(registers.get(inst.dst))) >
            @as(i64, @bitCast(registers.get(inst.src))))
        {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jsle_imm => if (@as(i64, @bitCast(registers.get(inst.dst))) <=
            @as(i64, @as(i32, @bitCast(inst.imm))))
        {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jsle_reg => if (@as(i64, @bitCast(registers.get(inst.dst))) <=
            @as(i64, @bitCast(registers.get(inst.src))))
        {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jslt_imm => if (@as(i64, @bitCast(registers.get(inst.dst))) <
            @as(i64, @as(i32, @bitCast(inst.imm))))
        {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },
        .jslt_reg => if (@as(i64, @bitCast(registers.get(inst.dst))) <
            @as(i64, @bitCast(registers.get(inst.src))))
        {
            next_pc = @intCast(@as(i64, @intCast(next_pc)) + inst.off);
        },

        .exit => {
            if (vm.depth == 0) {
                return false;
            }

            vm.depth -= 1;
            const frame = vm.call_frames.pop();
            vm.registers.set(.r10, frame.fp);
            @memcpy(vm.registers.values[6..][0..4], &frame.caller_saved_regs);
            vm.stack_pointer -= 4096;
            next_pc = frame.return_pc;
        },

        .call_imm => {
            try vm.pushCallFrame();

            const target_pc = inst.imm;
            next_pc = target_pc;
        },

        else => std.debug.panic("TODO: step {}", .{inst}),
    }

    vm.registers.set(.pc, next_pc);
    return true;
}

fn load(vm: *Vm, T: type, vm_addr: u64) !T {
    const slice = try vm.memory_map.vmap(.load, vm_addr, @sizeOf(T));
    return std.mem.readInt(T, slice[0..@sizeOf(T)], .little);
}

fn store(vm: *Vm, T: type, vm_addr: u64, value: T) !void {
    const slice = try vm.memory_map.vmap(.store, vm_addr, @sizeOf(T));
    slice[0..@sizeOf(T)].* = @bitCast(value);
}

fn pushCallFrame(vm: *Vm) !void {
    const frame = vm.call_frames.addOneAssumeCapacity();
    @memcpy(&frame.caller_saved_regs, vm.registers.values[6..][0..4]);
    frame.fp = vm.registers.get(.r10);
    frame.return_pc = vm.registers.get(.pc) + 1;

    vm.depth += 1;
    if (vm.depth == 64) {
        return error.CallDepthExceeded;
    }

    vm.stack_pointer += 4096;
    vm.registers.set(.r10, vm.stack_pointer);
}

const CallFrame = struct {
    caller_saved_regs: [4]u64,
    fp: u64,
    return_pc: u64,
};
