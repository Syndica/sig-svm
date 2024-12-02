//! Constants to do with Solana's EBPF

/// Solana BPF Elf E-Flag
pub const EF_SBPF_V2: u32 = 0x20;

/// Solana BPF Elf Machine
pub const EM_SBPF: std.elf.Elf64_Half = 263;

// TODO(upgrade) these are in 0.14, we just haven't upgraded
pub const ELFOSABI_NONE: u8 = 0;
pub const EI_OSABI: u8 = 7;

pub const SBPFVersion = enum {
    V1,
    V2,
};

pub const Instruction = packed struct(u64) {
    opcode: OpCode,
    dst: Register,
    src: Register,
    off: i16,
    imm: u32,

    const OpCode = enum(u8) {
        mov64_reg = alu64_store | x | mov,
        exit = jmp | exit,
        _,

        /// load from immediate
        const ld = 0b0000;
        /// load from register
        const ldx = 0b0001;
        /// store immediate
        const st = 0b0010;
        /// store valu from register
        const stx = 0b0011;
        /// 32 bit arithmetic or load
        const alu32_load = 0b0100;
        /// control flow
        const jmp = 0b0101;
        /// product / quotient / remainder
        const pqr = 0b0110;
        /// 64 bit arithmetic or store
        const alu64_store = 0b0111;

        /// source operand modifier: `src` register
        const x = 0b1000;

        /// alu64 op code: move
        const mov = 0b10110000;

        /// jmp op code: return from program
        const exit = 0b10010000;
    };

    pub const Register = enum(u4) {
        /// Return Value
        r0,
        /// Argument 0
        r1,
        /// Argument 1
        r2,
        /// Argument 2
        r3,
        /// Argument 3
        r4,
        /// Argument 4 or stack-spill ptr
        r5,
        /// Call-preserved
        r6,
        /// Call-preserved
        r7,
        /// Call-preserved
        r8,
        /// Call-preserved
        r9,
        /// Frame pointer, System register
        r10,
        /// Stack pointer, System register
        r11,
        /// Program counter, Hidden register
        pc,
    };

    pub fn format(
        inst: Instruction,
        comptime fmt: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        comptime assert(fmt.len == 0);

        try writer.print("{}", .{inst.opcode});
    }
};

const std = @import("std");
const assert = std.debug.assert;
