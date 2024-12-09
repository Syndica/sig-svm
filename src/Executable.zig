const std = @import("std");
const ebpf = @import("ebpf.zig");
const Elf = @import("Elf.zig");
const Executable = @This();

instructions: []const ebpf.Instruction,
version: ebpf.SBPFVersion,
entry_pc: u64,

pub fn fromElf(allocator: std.mem.Allocator, elf: *const Elf) !Executable {
    return .{
        .instructions = try elf.getInstructions(allocator),
        .version = elf.version,
        .entry_pc = elf.entry_pc,
    };
}

pub fn fromAsm(allocator: std.mem.Allocator, source: []const u8) !Executable {
    const instructions = try Assembler.parse(allocator, source);
    return .{
        .instructions = instructions,
        .version = .v1,
        .entry_pc = 0,
    };
}

const Assembler = struct {
    source: []const u8,

    const Statement = union(enum) {
        label: []const u8,
        instruction: Instruction,

        const Instruction = struct {
            name: []const u8,
            operands: []const Operand,
        };
    };

    const Operand = union(enum) {
        register: ebpf.Instruction.Register,
        integer: i64,
        memory: Memory,
        label: []const u8,

        const Memory = struct {
            base: ebpf.Instruction.Register,
            offset: i16,
        };
    };

    fn parse(allocator: std.mem.Allocator, source: []const u8) ![]const ebpf.Instruction {
        var assembler: Assembler = .{ .source = source };
        const statements = try assembler.tokenize(allocator);
        defer {
            for (statements) |statement| {
                switch (statement) {
                    .instruction => |inst| allocator.free(inst.operands),
                    else => {},
                }
            }
            allocator.free(statements);
        }

        var labels: std.StringHashMapUnmanaged(u64) = .{};
        defer labels.deinit(allocator);

        try labels.put(allocator, "entrypoint", 0);
        var inst_ptr: u64 = 0;
        for (statements) |statement| {
            switch (statement) {
                .label => |name| {
                    try labels.put(allocator, name, inst_ptr);
                },
                .instruction => |inst| {
                    inst_ptr += if (std.mem.eql(u8, inst.name, "lddw")) 2 else 1;
                },
            }
        }

        var instructions: std.ArrayListUnmanaged(ebpf.Instruction) = .{};
        defer instructions.deinit(allocator);

        for (statements) |statement| {
            switch (statement) {
                .label => {},
                .instruction => |inst| {
                    const name = inst.name;
                    const operands = inst.operands;

                    const bind = ebpf.Instruction.map.get(name) orelse
                        std.debug.panic("invalid instruction: {s}", .{name});

                    const instruction: ebpf.Instruction = switch (bind.inst) {
                        .alu_binary => inst: {
                            const is_immediate = operands[1] == .integer;
                            break :inst if (is_immediate) .{
                                .opcode = @enumFromInt(bind.opc | ebpf.Instruction.k),
                                .dst = operands[0].register,
                                .src = .r0, // unused
                                .off = 0,
                                .imm = @bitCast(@as(i32, @intCast(operands[1].integer))),
                            } else .{
                                .opcode = @enumFromInt(bind.opc | ebpf.Instruction.x),
                                .dst = operands[0].register,
                                .src = operands[1].register,
                                .off = 0,
                                .imm = 0,
                            };
                        },
                        .alu_unary => .{
                            .opcode = @enumFromInt(bind.opc),
                            .dst = operands[0].register,
                            .src = .r0,
                            .off = 0,
                            .imm = 0,
                        },
                        .no_operand => .{
                            .opcode = @enumFromInt(bind.opc),
                            // all these fields are unused
                            .dst = .r0,
                            .src = .r0,
                            .off = 0,
                            .imm = 0,
                        },
                        .jump_conditional => inst: {
                            const is_immediate = operands[1] == .integer;
                            const is_label = operands[2] == .label;

                            if (is_label) {
                                @panic("TODO: label jump");
                            } else {
                                break :inst if (is_immediate) .{
                                    .opcode = @enumFromInt(bind.opc | ebpf.Instruction.k),
                                    .dst = operands[0].register,
                                    .src = .r0,
                                    .off = @intCast(operands[2].integer),
                                    .imm = @bitCast(@as(i32, @intCast(operands[1].integer))),
                                } else .{
                                    .opcode = @enumFromInt(bind.opc | ebpf.Instruction.x),
                                    .dst = operands[0].register,
                                    .src = operands[1].register,
                                    .off = @intCast(operands[2].integer),
                                    .imm = 0,
                                };
                            }
                        },
                        .jump_unconditional => .{
                            .opcode = @enumFromInt(bind.opc),
                            .dst = .r0,
                            .src = .r0,
                            .off = @intCast(operands[0].integer),
                            .imm = 0,
                        },
                        .load_dw_imm => .{
                            .opcode = .ld_dw_imm,
                            .dst = operands[0].register,
                            .src = .r0,
                            .off = 0,
                            .imm = @truncate(@as(u64, @bitCast(operands[1].integer))),
                        },
                        .load_reg => .{
                            .opcode = @enumFromInt(bind.opc),
                            .dst = operands[0].register,
                            .src = operands[1].memory.base,
                            .off = operands[1].memory.offset,
                            .imm = 0,
                        },
                        .store_reg => .{
                            .opcode = @enumFromInt(bind.opc),
                            .dst = operands[0].memory.base,
                            .src = operands[1].register,
                            .off = operands[0].memory.offset,
                            .imm = 0,
                        },
                        .store_imm => .{
                            .opcode = @enumFromInt(bind.opc),
                            .dst = operands[0].memory.base,
                            .src = .r0,
                            .off = operands[0].memory.offset,
                            .imm = @bitCast(@as(i32, @intCast(operands[1].integer))),
                        },
                        .endian => |bits| .{
                            .opcode = @enumFromInt(bind.opc),
                            .dst = operands[0].register,
                            .src = .r0,
                            .off = 0,
                            .imm = bits,
                        },
                        else => std.debug.panic("TODO: {s}", .{@tagName(bind.inst)}),
                    };

                    try instructions.append(allocator, instruction);
                    inst_ptr += 1;

                    if (bind.inst == .load_dw_imm) {
                        switch (operands[1]) {
                            .integer => |int| {
                                try instructions.append(allocator, .{
                                    .opcode = @enumFromInt(0),
                                    .dst = .r0,
                                    .src = .r0,
                                    .off = 0,
                                    .imm = @truncate(@as(u64, @bitCast(int)) >> 32),
                                });
                                inst_ptr += 1;
                            },
                            else => {},
                        }
                    }
                },
            }
        }

        return instructions.toOwnedSlice(allocator);
    }

    fn tokenize(assembler: *Assembler, allocator: std.mem.Allocator) ![]const Statement {
        var statements: std.ArrayListUnmanaged(Statement) = .{};
        defer statements.deinit(allocator);

        var lines = std.mem.splitScalar(u8, assembler.source, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue; // empty line, skip

            const trimmed_line = std.mem.trim(u8, line, " ");

            // is it a label? "ident:"
            if (std.mem.indexOfScalar(u8, trimmed_line, ':')) |index| {
                const ident = trimmed_line[0..index];
                try statements.append(allocator, .{ .label = ident });
                continue;
            }

            var operands: std.ArrayListUnmanaged(Operand) = .{};
            defer operands.deinit(allocator);

            // what's the first mnemonic of the instruction?
            var iter = std.mem.tokenizeAny(u8, trimmed_line, &.{ ' ', ',' });
            const name = iter.next() orelse @panic("no mnem");

            while (iter.next()) |op| {
                // register operand
                if (std.mem.startsWith(u8, op, "r")) {
                    const reg = std.meta.stringToEnum(ebpf.Instruction.Register, op) orelse
                        @panic("unknown register");
                    try operands.append(allocator, .{ .register = reg });
                    continue;
                }

                // address operand
                if (std.mem.startsWith(u8, op, "[")) {
                    const left_bracket = std.mem.indexOfScalar(u8, op, '[').?;
                    const right_bracket = std.mem.indexOfScalar(u8, op, ']') orelse
                        @panic("no right bracket");
                    if (left_bracket == op.len) @panic("no right bracket");

                    var base = op[left_bracket + 1 .. right_bracket];
                    var offset: i16 = 0;

                    // does it have a + or -
                    // this can appear in [r1+10] for example
                    const maybe_symbol_offset = std.mem.indexOfAny(u8, base, "+-");
                    if (maybe_symbol_offset) |symbol_offset| {
                        const symbol = base[symbol_offset..];
                        base = base[0..symbol_offset];
                        offset = try std.fmt.parseInt(i16, symbol, 0);
                    }

                    // otherwise it's just an address register argument
                    const reg = std.meta.stringToEnum(ebpf.Instruction.Register, base) orelse
                        @panic("unknown register");

                    try operands.append(allocator, .{ .memory = .{ .base = reg, .offset = offset } });
                    continue;
                }

                if (std.fmt.parseInt(i64, op, 0)) |int| {
                    try operands.append(allocator, .{ .integer = int });
                } else |err| std.debug.panic("err: {s}", .{@errorName(err)});
            }

            try statements.append(allocator, .{ .instruction = .{
                .name = name,
                .operands = try operands.toOwnedSlice(allocator),
            } });
        }

        return statements.toOwnedSlice(allocator);
    }
};

pub fn deinit(exec: *Executable, allocator: std.mem.Allocator) void {
    allocator.free(exec.instructions);
}
