//! Constants to do with Solana's EBPF

pub const EF_SBPF_V2: u32 = 0x20;

/// Solana BPF Elf Machine
pub const EM_SBPF: std.elf.Elf64_Half = 263;

// TODO(upgrade) these are in 0.14, we just haven't upgraded
pub const ELFOSABI_NONE: u8 = 0;
pub const EI_OSABI: u8 = 7;

pub const SBPFVersion = enum {
    v0,
    v1,
    v2,
    v3,
    reserved,
};

pub const Instruction = packed struct(u64) {
    opcode: OpCode,
    dst: Register,
    src: Register,
    off: i16,
    imm: u32,

    pub const OpCode = enum(u8) {
        /// BPF opcode: `lddw dst, imm` /// `dst = imm`. [DEPRECATED]
        ld_dw_imm = ld | imm | dw,
        /// bpf opcode: `ldxb dst, [src + off]` /// `dst = (src + off) as u8`.
        ld_b_reg = ldx | mem | b,
        /// bpf opcode: `ldxh dst, [src + off]` /// `dst = (src + off) as u16`.
        ld_h_reg = ldx | mem | h,
        /// bpf opcode: `ldxw dst, [src + off]` /// `dst = (src + off) as u32`.
        ld_w_reg = ldx | mem | w,
        /// bpf opcode: `ldxdw dst, [src + off]` /// `dst = (src + off) as u64`.
        ld_dw_reg = ldx | mem | dw,
        /// bpf opcode: `stb [dst + off], imm` /// `(dst + offset) as u8 = imm`.
        st_b_imm = st | mem | b,
        /// bpf opcode: `sth [dst + off], imm` /// `(dst + offset) as u16 = imm`.
        st_h_imm = st | mem | h,
        /// bpf opcode: `stw [dst + off], imm` /// `(dst + offset) as u32 = imm`.
        st_w_imm = st | mem | w,
        /// bpf opcode: `stdw [dst + off], imm` /// `(dst + offset) as u64 = imm`.
        st_dw_imm = st | mem | dw,
        /// bpf opcode: `stxb [dst + off], src` /// `(dst + offset) as u8 = src`.
        st_b_reg = stx | mem | b,
        /// bpf opcode: `stxh [dst + off], src` /// `(dst + offset) as u16 = src`.
        st_h_reg = stx | mem | h,
        /// bpf opcode: `stxw [dst + off], src` /// `(dst + offset) as u32 = src`.
        st_w_reg = stx | mem | w,
        /// bpf opcode: `stxdw [dst + off], src` /// `(dst + offset) as u64 = src`.
        st_dw_reg = stx | mem | dw,

        /// bpf opcode: `add32 dst, imm` /// `dst += imm`.
        add32_imm = alu32_load | k | add,
        /// bpf opcode: `add32 dst, src` /// `dst += src`.
        add32_reg = alu32_load | x | add,
        /// bpf opcode: `sub32 dst, imm` /// `dst = imm - dst`.
        sub32_imm = alu32_load | k | sub,
        /// bpf opcode: `sub32 dst, src` /// `dst -= src`.
        sub32_reg = alu32_load | x | sub,

        /// bpf opcode: `mul32 dst, imm` /// `dst *= imm`.
        mul32_imm = alu32_load | k | mul,

        /// bpf opcode: `mul32 dst, src` /// `dst *= src`.
        mul32_reg = alu32_load | x | mul,
        /// bpf opcode: `div32 dst, imm` /// `dst /= imm`.
        div32_imm = alu32_load | k | div,
        /// bpf opcode: `div32 dst, src` /// `dst /= src`.
        div32_reg = alu32_load | x | div,

        /// bpf opcode: `or32 dst, imm` /// `dst |= imm`.
        or32_imm = alu32_load | k | @"or",
        /// bpf opcode: `or32 dst, src` /// `dst |= src`.
        or32_reg = alu32_load | x | @"or",
        /// bpf opcode: `and32 dst, imm` /// `dst &= imm`.
        and32_imm = alu32_load | k | @"and",
        /// bpf opcode: `and32 dst, src` /// `dst &= src`.
        and32_reg = alu32_load | x | @"and",
        /// bpf opcode: `lsh32 dst, imm` /// `dst <<= imm`.
        lsh32_imm = alu32_load | k | lsh,
        /// bpf opcode: `lsh32 dst, src` /// `dst <<= src`.
        lsh32_reg = alu32_load | x | lsh,
        /// bpf opcode: `rsh32 dst, imm` /// `dst >>= imm`.
        rsh32_imm = alu32_load | k | rsh,
        /// bpf opcode: `rsh32 dst, src` /// `dst >>= src`.
        rsh32_reg = alu32_load | x | rsh,

        /// bpf opcode: `neg32 dst` /// `dst = -dst`.
        neg32 = alu32_load | neg,

        /// bpf opcode: `mod32 dst, imm` /// `dst %= imm`.
        mod32_imm = alu32_load | k | mod,
        /// bpf opcode: `mod32 dst, src` /// `dst %= src`.
        mod32_reg = alu32_load | x | mod,

        /// bpf opcode: `xor32 dst, imm` /// `dst ^= imm`.
        xor32_imm = alu32_load | k | xor,
        /// bpf opcode: `xor32 dst, src` /// `dst ^= src`.
        xor32_reg = alu32_load | x | xor,
        /// bpf opcode: `mov32 dst, imm` /// `dst = imm`.
        mov32_imm = alu32_load | k | mov,
        /// bpf opcode: `mov32 dst, src` /// `dst = src`.
        mov32_reg = alu32_load | x | mov,
        /// bpf opcode: `arsh32 dst, imm` /// `dst >>= imm (arithmetic)`.
        arsh32_imm = alu32_load | k | arsh,
        /// bpf opcode: `arsh32 dst, src` /// `dst >>= src (arithmetic)`.
        arsh32_reg = alu32_load | x | arsh,

        /// bpf opcode: `le dst` /// `dst = htole<imm>(dst), with imm in {16, 32, 64}`.
        le = alu32_load | k | end,
        /// bpf opcode: `be dst` /// `dst = htobe<imm>(dst), with imm in {16, 32, 64}`.
        be = alu32_load | x | end,

        /// bpf opcode: `add64 dst, imm` /// `dst += imm`.
        add64_imm = alu64_store | k | add,
        /// bpf opcode: `add64 dst, src` /// `dst += src`.
        add64_reg = alu64_store | x | add,
        /// bpf opcode: `sub64 dst, imm` /// `dst -= imm`.
        sub64_imm = alu64_store | k | sub,
        /// bpf opcode: `sub64 dst, src` /// `dst -= src`.
        sub64_reg = alu64_store | x | sub,

        /// bpf opcode: `mul64 dst, imm` /// `dst *= imm`.
        mul64_imm = alu64_store | k | mul,
        /// bpf opcode: `mul64 dst, src` /// `dst *= src`.
        mul64_reg = alu64_store | x | mul,
        /// bpf opcode: `div64 dst, imm` /// `dst /= imm`.
        div64_imm = alu64_store | k | div,
        /// bpf opcode: `div64 dst, src` /// `dst /= src`.
        div64_reg = alu64_store | x | div,

        /// bpf opcode: `or64 dst, imm` /// `dst |= imm`.
        or64_imm = alu64_store | k | @"or",
        /// bpf opcode: `or64 dst, src` /// `dst |= src`.
        or64_reg = alu64_store | x | @"or",
        /// bpf opcode: `and64 dst, imm` /// `dst &= imm`.
        and64_imm = alu64_store | k | @"and",
        /// bpf opcode: `and64 dst, src` /// `dst &= src`.
        and64_reg = alu64_store | x | @"and",
        /// bpf opcode: `lsh64 dst, imm` /// `dst <<= imm`.
        lsh64_imm = alu64_store | k | lsh,
        /// bpf opcode: `lsh64 dst, src` /// `dst <<= src`.
        lsh64_reg = alu64_store | x | lsh,
        /// bpf opcode: `rsh64 dst, imm` /// `dst >>= imm`.
        rsh64_imm = alu64_store | k | rsh,
        /// bpf opcode: `rsh64 dst, src` /// `dst >>= src`.
        rsh64_reg = alu64_store | x | rsh,

        /// bpf opcode: `neg64 dst` /// `dst = -dst`.
        neg64 = alu64_store | neg,

        /// bpf opcode: `mod64 dst, imm` /// `dst %= imm`.
        mod64_imm = alu64_store | k | mod,
        /// bpf opcode: `mod64 dst, src` /// `dst %= src`.
        mod64_reg = alu64_store | x | mod,

        /// bpf opcode: `xor64 dst, imm` /// `dst ^= imm`.
        xor64_imm = alu64_store | k | xor,
        /// bpf opcode: `xor64 dst, src` /// `dst ^= src`.
        xor64_reg = alu64_store | x | xor,
        /// bpf opcode: `mov64 dst, imm` /// `dst = imm`.
        mov64_imm = alu64_store | k | mov,
        /// bpf opcode: `mov64 dst, src` /// `dst = src`.
        mov64_reg = alu64_store | x | mov,
        /// bpf opcode: `arsh64 dst, imm` /// `dst >>= imm (arithmetic)`.
        arsh64_imm = alu64_store | k | arsh,
        /// bpf opcode: `arsh64 dst, src` /// `dst >>= src (arithmetic)`.
        arsh64_reg = alu64_store | x | arsh,
        /// bpf opcode: `hor64 dst, imm` /// `dst |= imm << 32`.
        hor64_imm = alu64_store | k | hor,

        /// bpf opcode: `ja +off` /// `pc += off`.
        ja = jmp | 0x0,
        /// bpf opcode: `jeq dst, imm, +off` /// `pc += off if dst == imm`.
        jeq_imm = jmp | k | jeq,
        /// bpf opcode: `jeq dst, src, +off` /// `pc += off if dst == src`.
        jeq_reg = jmp | x | jeq,
        /// bpf opcode: `jgt dst, imm, +off` /// `pc += off if dst > imm`.
        jgt_imm = jmp | k | jgt,
        /// bpf opcode: `jgt dst, src, +off` /// `pc += off if dst > src`.
        jgt_reg = jmp | x | jgt,
        /// bpf opcode: `jge dst, imm, +off` /// `pc += off if dst >= imm`.
        jge_imm = jmp | k | jge,
        /// bpf opcode: `jge dst, src, +off` /// `pc += off if dst >= src`.
        jge_reg = jmp | x | jge,
        /// bpf opcode: `jlt dst, imm, +off` /// `pc += off if dst < imm`.
        jlt_imm = jmp | k | jlt,
        /// bpf opcode: `jlt dst, src, +off` /// `pc += off if dst < src`.
        jlt_reg = jmp | x | jlt,
        /// bpf opcode: `jle dst, imm, +off` /// `pc += off if dst <= imm`.
        jle_imm = jmp | k | jle,
        /// bpf opcode: `jle dst, src, +off` /// `pc += off if dst <= src`.
        jle_reg = jmp | x | jle,
        /// bpf opcode: `jset dst, imm, +off` /// `pc += off if dst & imm`.
        jset_imm = jmp | k | jset,
        /// bpf opcode: `jset dst, src, +off` /// `pc += off if dst & src`.
        jset_reg = jmp | x | jset,
        /// bpf opcode: `jne dst, imm, +off` /// `pc += off if dst != imm`.
        jne_imm = jmp | k | jne,
        /// bpf opcode: `jne dst, src, +off` /// `pc += off if dst != src`.
        jne_reg = jmp | x | jne,
        /// bpf opcode: `jsgt dst, imm, +off` /// `pc += off if dst > imm (signed)`.
        jsgt_imm = jmp | k | jsgt,
        /// bpf opcode: `jsgt dst, src, +off` /// `pc += off if dst > src (signed)`.
        jsgt_reg = jmp | x | jsgt,
        /// bpf opcode: `jsge dst, imm, +off` /// `pc += off if dst >= imm (signed)`.
        jsge_imm = jmp | k | jsge,
        /// bpf opcode: `jsge dst, src, +off` /// `pc += off if dst >= src (signed)`.
        jsge_reg = jmp | x | jsge,
        /// bpf opcode: `jslt dst, imm, +off` /// `pc += off if dst < imm (signed)`.
        jslt_imm = jmp | k | jslt,
        /// bpf opcode: `jslt dst, src, +off` /// `pc += off if dst < src (signed)`.
        jslt_reg = jmp | x | jslt,
        /// bpf opcode: `jsle dst, imm, +off` /// `pc += off if dst <= imm (signed)`.
        jsle_imm = jmp | k | jsle,
        /// bpf opcode: `jsle dst, src, +off` /// `pc += off if dst <= src (signed)`.
        jsle_reg = jmp | x | jsle,

        /// bpf opcode: `call imm` /// syscall function call to syscall with key `imm`.
        call_imm = jmp | call,
        /// bpf opcode: tail call.
        call_reg = jmp | x | call,

        /// bpf opcode: `exit` /// `return r0`. /// valid only until sbpfv3
        exit = jmp | exit_code,
        _,
    };

    const Entry = struct {
        inst: InstructionType,
        opc: u8,
    };

    const InstructionType = union(enum) {
        alu_binary,
        alu_unary,
        load_dw_imm,
        load_abs,
        load_ind,
        load_reg,
        store_imm,
        store_reg,
        jump_unconditional,
        jump_conditional,
        syscall,
        call_imm,
        call_reg,
        endian: i64,
        no_operand,
    };

    pub const map = std.StaticStringMap(Entry).initComptime(&.{
        // zig fmt: off
        .{ "mov"  , .{ .inst = .alu_binary, .opc = mov | alu64_store } }, 
        .{ "mov64", .{ .inst = .alu_binary, .opc = mov | alu64_store } },
        .{ "mov32", .{ .inst = .alu_binary, .opc = mov | alu32_load  } },
        
        .{ "add"  , .{ .inst = .alu_binary, .opc = add | alu64_store } },
        .{ "add64", .{ .inst = .alu_binary, .opc = add | alu64_store } },
        .{ "add32", .{ .inst = .alu_binary, .opc = add | alu32_load  } },

        .{ "mul"  , .{ .inst = .alu_binary, .opc = mul | alu64_store } },
        .{ "mul64", .{ .inst = .alu_binary, .opc = mul | alu64_store } },
        .{ "mul32", .{ .inst = .alu_binary, .opc = mul | alu32_load  } },

        .{ "sub"  , .{ .inst = .alu_binary, .opc = sub | alu64_store } },
        .{ "sub64", .{ .inst = .alu_binary, .opc = sub | alu64_store } },
        .{ "sub32", .{ .inst = .alu_binary, .opc = sub | alu32_load  } },

        .{ "div"  , .{ .inst = .alu_binary, .opc = div | alu64_store } },
        .{ "div64", .{ .inst = .alu_binary, .opc = div | alu64_store } },
        .{ "div32", .{ .inst = .alu_binary, .opc = div | alu32_load  } },
        
        .{ "xor"  , .{ .inst = .alu_binary, .opc = xor | alu64_store } },
        .{ "xor64", .{ .inst = .alu_binary, .opc = xor | alu64_store } },
        .{ "xor32", .{ .inst = .alu_binary, .opc = xor | alu32_load  } },

        .{ "or"  , .{ .inst = .alu_binary, .opc = @"or" | alu64_store } },
        .{ "or64", .{ .inst = .alu_binary, .opc = @"or" | alu64_store } },
        .{ "or32", .{ .inst = .alu_binary, .opc = @"or" | alu32_load  } },

        .{ "and"  , .{ .inst = .alu_binary, .opc = @"and" | alu64_store } },
        .{ "and64", .{ .inst = .alu_binary, .opc = @"and" | alu64_store } },
        .{ "and32", .{ .inst = .alu_binary, .opc = @"and" | alu32_load  } },

        .{ "lsh"  , .{ .inst = .alu_binary, .opc = lsh | alu64_store } },
        .{ "lsh64", .{ .inst = .alu_binary, .opc = lsh | alu64_store } },
        .{ "lsh32", .{ .inst = .alu_binary, .opc = lsh | alu32_load  } },

        .{ "rsh"  , .{ .inst = .alu_binary, .opc = rsh | alu64_store } },
        .{ "rsh64", .{ .inst = .alu_binary, .opc = rsh | alu64_store } },
        .{ "rsh32", .{ .inst = .alu_binary, .opc = rsh | alu32_load  } },
        
        .{ "neg"  , .{ .inst = .alu_unary,  .opc = neg | alu64_store } },
        .{ "neg64", .{ .inst = .alu_unary,  .opc = neg | alu64_store } },
        .{ "neg32", .{ .inst = .alu_unary,  .opc = neg | alu32_load  } },

        .{ "ja"   , .{ .inst = .jump_unconditional, .opc = ja | jmp } },

        .{ "jeq"  , .{ .inst = .jump_conditional, .opc = jeq  |  jmp  } },
        .{ "jgt"  , .{ .inst = .jump_conditional, .opc = jgt  |  jmp  } },
        .{ "jge"  , .{ .inst = .jump_conditional, .opc = jge  |  jmp  } },
        .{ "jlt"  , .{ .inst = .jump_conditional, .opc = jlt  |  jmp  } },
        .{ "jle"  , .{ .inst = .jump_conditional, .opc = jle  |  jmp  } },
        .{ "jset" , .{ .inst = .jump_conditional, .opc = jset |  jmp  } },
        .{ "jne"  , .{ .inst = .jump_conditional, .opc = jne  |  jmp  } },
        .{ "jsgt" , .{ .inst = .jump_conditional, .opc = jsgt |  jmp  } },
        .{ "jsge" , .{ .inst = .jump_conditional, .opc = jsge |  jmp  } },
        .{ "jslt" , .{ .inst = .jump_conditional, .opc = jslt |  jmp  } },
        .{ "jsle" , .{ .inst = .jump_conditional, .opc = jsle |  jmp  } },
        
        .{ "exit" , .{ .inst = .no_operand,       .opc = jmp | exit_code } },
        .{ "lddw" , .{ .inst = .load_dw_imm,      .opc = ld  | imm | dw  } },

        // zig fmt: on
    });

    /// load from immediate
    pub const ld = 0b0000;
    /// load from register
    pub const ldx = 0b0001;
    /// store immediate
    pub const st = 0b0010;
    /// store valu from register
    pub const stx = 0b0011;
    /// 32 bit arithmetic  @"or" load
    pub const alu32_load = 0b0100;
    /// control flow
    pub const jmp = 0b0101;
    /// product / quotient / remainder
    pub const pqr = 0b0110;
    /// 64 bit arithmetic  @"or" store
    pub const alu64_store = 0b0111;

    /// source operand modifier: `src` register
    pub const x = 0b1000;
    /// source operand modifier: 32-bit immediate value.
    pub const k = 0b0000;

    /// size modifier: word (4 bytes).
    pub const w: u8 = 0x00;
    /// size modifier: half-word (2 bytes).
    pub const h: u8 = 0x08;
    /// size modifier: byte (1 byte).
    pub const b: u8 = 0x10;
    /// size modifier: double word (8 bytes).
    pub const dw: u8 = 0x18;
    /// size modifier: 1 byte.
    pub const @"1b": u8 = 0x20;
    /// size modifier: 2 bytes.
    pub const @"2b": u8 = 0x30;
    /// size modifier: 4 bytes.
    pub const @"4b": u8 = 0x80;
    /// size modifier: 8 bytes.
    pub const @"8b": u8 = 0x90;

    /// jmp operation code: jump always
    pub const ja: u8 = 0x00;
    ///  jmp operation code: jump if equal.
    pub const jeq: u8 = 0x10;
    ///  jmp operation code: jump if greater than.
    pub const jgt: u8 = 0x20;
    ///  jmp operation code: jump if greater or equal.
    pub const jge: u8 = 0x30;
    ///  jmp operation code: jump if `src` & `reg`.
    pub const jset: u8 = 0x40;
    ///  jmp operation code: jump if not equal.
    pub const jne: u8 = 0x50;
    ///  jmp operation code: jump if greater than (signed).
    pub const jsgt: u8 = 0x60;
    ///  jmp operation code: jump if greater or equal (signed).
    pub const jsge: u8 = 0x70;
    ///  jmp operation code: syscall function call.
    pub const call: u8 = 0x80;
    ///  jmp operation code: return from program.
    pub const exit_code: u8 = 0x90;
    ///  jmp operation code: static syscall.
    pub const syscall: u8 = 0x90;
    ///  jmp operation code: jump if lower than.
    pub const jlt: u8 = 0xa0;
    ///  jmp operation code: jump if lower or equal.
    pub const jle: u8 = 0xb0;
    ///  jmp operation code: jump if lower than (signed).
    pub const jslt: u8 = 0xc0;
    ///  jmp operation code: jump if lower or equal (signed).
    pub const jsle: u8 = 0xd0;

    /// mode modifier:
    pub const imm = 0b0000000;
    pub const abs = 0b0100000;
    pub const mem = 0b1100000;

    /// alu/alu64 operation code: addition.
    pub const add: u8 = 0x00;
    /// alu/alu64 operation code: subtraction.
    pub const sub: u8 = 0x10;

    /// alu/alu64 operation code: multiplication.
    pub const mul: u8 = 0x20;
    /// alu/alu64 operation code: division.
    pub const div: u8 = 0x30;

    /// alu/alu64 operation code: or.
    pub const @"or": u8 = 0x40;
    /// alu/alu64 operation code: and.
    pub const @"and": u8 = 0x50;
    /// alu/alu64 operation code: left shift.
    pub const lsh: u8 = 0x60;
    /// alu/alu64 operation code: right shift.
    pub const rsh: u8 = 0x70;

    /// alu/alu64 operation code: negation.
    pub const neg: u8 = 0x80;
    /// alu/alu64 operation code: modulus.
    pub const mod: u8 = 0x90;

    /// alu/alu64 operation code: exclusive or.
    pub const xor: u8 = 0xa0;
    /// alu/alu64 operation code: move.
    pub const mov: u8 = 0xb0;
    /// alu/alu64 operation code: sign extending right shift.
    pub const arsh: u8 = 0xc0;
    /// alu/alu64 operation code: endianness conversion.
    pub const end: u8 = 0xd0;
    /// alu/alu64 operation code: high or.
    pub const hor: u8 = 0xf0;

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
        /// Argument 4  @"or" stack-spill ptr
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
