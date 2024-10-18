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
    class: Class,
    /// Operand code.
    opcode: Opcode,
    /// Destination register operand.
    dst: Register,
    /// Source register operand.
    src: Register,
    /// Offset operand.
    off: i16,
    /// Immediate value operand.
    imm: u32,

    pub const Class = enum(u3) {
        // zig fmt: off
        ld    = 0b000,
        ldx   = 0b001,
        st    = 0b010,
        stx   = 0b011,
        alu   = 0b100,
        jmp   = 0b101,
        jmp32 = 0b110,
        alu64 = 0b111,
        // zig fmt: on
    };

    pub const Opcode = enum(u5) {
        ldxdw = 0b01111,
        _,
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
};

const std = @import("std");
