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

pub fn fromAsm(allocator: std.mem.Allocator, source: []const u8) !void {
    const instructions = try Assembler.parse(allocator, source);
    _ = instructions;
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
            offset: i64,
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

        for (statements) |statement| {
            std.debug.print("statement: {}\n", .{statement});
        }

        return &.{};
    }

    fn tokenize(assembler: *Assembler, allocator: std.mem.Allocator) ![]const Statement {
        var statements: std.ArrayListUnmanaged(Statement) = .{};
        defer statements.deinit(allocator);

        var lines = std.mem.splitScalar(u8, assembler.source, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue; // empty line, skip

            const trimmed_line = std.mem.trim(u8, line, " ");

            std.debug.print("line: {s}\n", .{trimmed_line});

            // is it a label? "ident:"
            if (std.mem.indexOfScalar(u8, trimmed_line, ':')) |index| {
                const ident = trimmed_line[0..index];
                try statements.append(allocator, .{ .label = ident });
                continue;
            }

            var operands: std.ArrayListUnmanaged(Operand) = .{};
            defer operands.deinit(allocator);

            // what's the first mnemonic of the instruction?
            var iter = std.mem.tokenizeAny(u8, trimmed_line, " ,");
            const name = iter.next() orelse @panic("no mnem");

            while (iter.next()) |op| {
                if (std.mem.startsWith(u8, op, "r")) {
                    const reg = std.meta.stringToEnum(ebpf.Instruction.Register, op) orelse
                        @panic("unknown register");
                    try operands.append(allocator, .{ .register = reg });
                    continue;
                }

                if (std.fmt.parseInt(i64, op, 10)) |int| {
                    try operands.append(allocator, .{ .integer = int });
                    continue;
                } else |_| {}

                std.debug.panic("unhandled operand: {s}", .{op});
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
