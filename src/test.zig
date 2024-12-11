const std = @import("std");
const Vm = @import("Vm.zig");
const Executable = @import("Executable.zig");
const memory = @import("memory.zig");
const MemoryMap = memory.MemoryMap;
const Region = memory.Region;

comptime {
    _ = &memory;
}

const expectEqual = std.testing.expectEqual;

test "mov" {
    try testAsm(
        \\entrypoint:
        \\  mov r1, 16
        \\  mov r0, r1
        \\  exit
    , 16);

    try testAsm(
        \\entrypoint:
        \\  mov32 r0, -1
        \\  exit
    , 0xffffffff);

    try testAsm(
        \\entrypoint:
        \\  mov32 r1, -1
        \\  mov32 r0, r1
        \\  exit
    , 0xffffffff);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 1
        \\  mov r6, r0
        \\  mov r7, r6
        \\  mov r8, r7
        \\  mov r9, r8
        \\  mov r0, r9
        \\  exit
    , 1);
}

test "add" {
    try testAsm(
        \\entrypoint:
        \\  mov32 r0, 0
        \\  mov32 r1, 2
        \\  add32 r0, 1
        \\  add32 r0, r1
        \\  exit
    , 3);
}

test "mul" {
    try testAsm(
        \\entrypoint:
        \\  mov r0, 3
        \\  mul32 r0, 4
        \\  exit
    , 12);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 3
        \\  mov r1, 4
        \\  mul32 r0, r1
        \\  exit
    , 12);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 0x40000001
        \\  mov r1, 4
        \\  mul32 r0, r1
        \\  exit
    , 4);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 0x40000001
        \\  mul r0, 4
        \\  exit
    , 0x100000004);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 0x40000001
        \\  mov r1, 4
        \\  mul r0, r1
        \\  exit
    , 0x100000004);

    try testAsm(
        \\entrypoint:
        \\  mov r0, -1
        \\  mul32 r0, 4
        \\  exit
    , 0xFFFFFFFFFFFFFFFC);
}

test "lddw" {
    try testAsm(
        \\entrypoint:
        \\  lddw r0, 0x1122334455667788
        \\  exit
    , 0x1122334455667788);

    try testAsm(
        \\entrypoint:
        \\  lddw r0, 0x0000000080000000
        \\  exit
    , 0x80000000);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 0
        \\  mov r1, 0
        \\  mov r2, 0
        \\  lddw r0, 0x1
        \\  ja +2
        \\  lddw r1, 0x1
        \\  lddw r2, 0x1
        \\  add r1, r2
        \\  add r0, r1
        \\  exit
    , 0x2);
}

test "div" {
    try testAsm(
        \\entrypoint:
        \\  mov r0, 12
        \\  lddw r1, 0x100000004
        \\  div32 r0, r1
        \\  exit
    , 0x3);

    try testAsm(
        \\entrypoint:
        \\  lddw r0, 0x10000000c
        \\  div32 r0, 4
        \\  exit
    , 0x3);

    try testAsm(
        \\entrypoint:
        \\  lddw r0, 0x10000000c
        \\  mov r1, 4
        \\  div32 r0, r1
        \\  exit
    , 0x3);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 0xc
        \\  lsh r0, 32
        \\  div r0, 4
        \\  exit
    , 0x300000000);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 0xc
        \\  lsh r0, 32
        \\  mov r1, 4
        \\  div r0, r1
        \\  exit
    , 0x300000000);

    try testAsm(
        \\entrypoint:
        \\  mov32 r0, 1
        \\  mov32 r1, 0
        \\  div r0, r1
        \\  exit
    , error.DivisionByZero);

    try testAsm(
        \\entrypoint:
        \\  mov32 r0, 1
        \\  mov32 r1, 0
        \\  div32 r0, r1
        \\  exit
    , error.DivisionByZero);
}

test "neg" {
    try testAsm(
        \\entrypoint:
        \\  mov32 r0, 2
        \\  neg32 r0
        \\  exit
    , 0xFFFFFFFE);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 2
        \\  neg r0
        \\  exit
    , 0xFFFFFFFFFFFFFFFE);

    try testAsm(
        \\entrypoint:
        \\  mov32 r0, 3
        \\  sub32 r0, 1
        \\  exit
    , 2);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 3
        \\  sub r0, 1
        \\  exit
    , 2);
}

test "alu" {
    try testAsm(
        \\entrypoint:
        \\  mov32 r0, 0
        \\  mov32 r1, 1
        \\  mov32 r2, 2
        \\  mov32 r3, 3
        \\  mov32 r4, 4
        \\  mov32 r5, 5
        \\  mov32 r6, 6
        \\  mov32 r7, 7
        \\  mov32 r8, 8
        \\  or32 r0, r5
        \\  or32 r0, 0xa0
        \\  and32 r0, 0xa3
        \\  mov32 r9, 0x91
        \\  and32 r0, r9
        \\  lsh32 r0, 22
        \\  lsh32 r0, r8
        \\  rsh32 r0, 19
        \\  rsh32 r0, r7
        \\  xor32 r0, 0x03
        \\  xor32 r0, r2
        \\  exit
    , 0x11);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 0
        \\  mov r1, 1
        \\  mov r2, 2
        \\  mov r3, 3
        \\  mov r4, 4
        \\  mov r5, 5
        \\  mov r6, 6
        \\  mov r7, 7
        \\  mov r8, 8
        \\  or r0, r5
        \\  or r0, 0xa0
        \\  and r0, 0xa3
        \\  mov r9, 0x91
        \\  and r0, r9
        \\  lsh r0, 32
        \\  lsh r0, 22
        \\  lsh r0, r8
        \\  rsh r0, 32
        \\  rsh r0, 19
        \\  rsh r0, r7
        \\  xor r0, 0x03
        \\  xor r0, r2
        \\  exit
    , 0x11);
}

test "shift" {
    try testAsm(
        \\entrypoint:
        \\  mov r0, 0x1
        \\  mov r7, 4
        \\  lsh r0, r7
        \\  exit
    , 0x10);

    try testAsm(
        \\entrypoint:
        \\  xor r0, r0
        \\  add r0, -1
        \\  rsh32 r0, 8
        \\  exit
    , 0x00ffffff);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 0x10
        \\  mov r7, 4
        \\  rsh r0, r7
        \\  exit
    , 0x1);
}

test "be" {
    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxh r0, [r1]
        \\  be16 r0
        \\  exit
    ,
        &.{ 0x11, 0x22 },
        0x1122,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxdw r0, [r1]
        \\  be16 r0
        \\  exit
    ,
        &.{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 },
        0x1122,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxw r0, [r1]
        \\  be32 r0
        \\  exit
    ,
        &.{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 },
        0x11223344,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxdw r0, [r1]
        \\  be32 r0
        \\  exit
    ,
        &.{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 },
        0x11223344,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxdw r0, [r1]
        \\  be64 r0
        \\  exit
    ,
        &.{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 },
        0x1122334455667788,
    );
}

test "load" {
    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxb r0, [r1+2]
        \\  exit
    ,
        &.{ 0xaa, 0xbb, 0x11, 0xcc, 0xdd },
        0x11,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxh r0, [r1+2]
        \\  exit
    ,
        &.{ 0xaa, 0xbb, 0x11, 0x22, 0xcc, 0xdd },
        0x2211,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxw r0, [r1+2]
        \\  exit
    ,
        &.{ 0xaa, 0xbb, 0x11, 0x22, 0x33, 0x44, 0xcc, 0xdd },
        0x44332211,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxdw r0, [r1+2]
        \\  exit
    ,
        &.{
            0xaa, 0xbb, 0x11, 0x22, 0x33, 0x44,
            0x55, 0x66, 0x77, 0x88, 0xcc, 0xdd,
        },
        0x8877665544332211,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxdw r0, [r1+6]
        \\  exit
    ,
        &.{
            0xaa, 0xbb, 0x11, 0x22, 0x33, 0x44,
            0x55, 0x66, 0x77, 0x88, 0xcc, 0xdd,
        },
        error.InvalidVirtualAddress,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  ldxdw r0, [r1+6]
        \\  exit
    ,
        &.{},
        error.AccessViolation,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov r0, r1
        \\  ldxb r9, [r0+0]
        \\  lsh r9, 0
        \\  ldxb r8, [r0+1]
        \\  lsh r8, 4
        \\  ldxb r7, [r0+2]
        \\  lsh r7, 8
        \\  ldxb r6, [r0+3]
        \\  lsh r6, 12
        \\  ldxb r5, [r0+4]
        \\  lsh r5, 16
        \\  ldxb r4, [r0+5]
        \\  lsh r4, 20
        \\  ldxb r3, [r0+6]
        \\  lsh r3, 24
        \\  ldxb r2, [r0+7]
        \\  lsh r2, 28
        \\  ldxb r1, [r0+8]
        \\  lsh r1, 32
        \\  ldxb r0, [r0+9]
        \\  lsh r0, 36
        \\  or r0, r1
        \\  or r0, r2
        \\  or r0, r3
        \\  or r0, r4
        \\  or r0, r5
        \\  or r0, r6
        \\  or r0, r7
        \\  or r0, r8
        \\  or r0, r9
        \\  exit
    ,
        &.{
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
            0x07, 0x08, 0x09,
        },
        0x9876543210,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov r0, r1
        \\  ldxh r9, [r0+0]
        \\  be16 r9
        \\  ldxh r8, [r0+2]
        \\  be16 r8
        \\  ldxh r7, [r0+4]
        \\  be16 r7
        \\  ldxh r6, [r0+6]
        \\  be16 r6
        \\  ldxh r5, [r0+8]
        \\  be16 r5
        \\  ldxh r4, [r0+10]
        \\  be16 r4
        \\  ldxh r3, [r0+12]
        \\  be16 r3
        \\  ldxh r2, [r0+14]
        \\  be16 r2
        \\  ldxh r1, [r0+16]
        \\  be16 r1
        \\  ldxh r0, [r0+18]
        \\  be16 r0
        \\  or r0, r1
        \\  or r0, r2
        \\  or r0, r3
        \\  or r0, r4
        \\  or r0, r5
        \\  or r0, r6
        \\  or r0, r7
        \\  or r0, r8
        \\  or r0, r9
        \\  exit
    ,
        &.{
            0x00, 0x01, 0x00, 0x02, 0x00, 0x04, 0x00, 0x08,
            0x00, 0x10, 0x00, 0x20, 0x00, 0x40, 0x00, 0x80,
            0x01, 0x00, 0x02, 0x00,
        },
        0x3FF,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov r0, r1
        \\  ldxw r9, [r0+0]
        \\  be32 r9
        \\  ldxw r8, [r0+4]
        \\  be32 r8
        \\  ldxw r7, [r0+8]
        \\  be32 r7
        \\  ldxw r6, [r0+12]
        \\  be32 r6
        \\  ldxw r5, [r0+16]
        \\  be32 r5
        \\  ldxw r4, [r0+20]
        \\  be32 r4
        \\  ldxw r3, [r0+24]
        \\  be32 r3
        \\  ldxw r2, [r0+28]
        \\  be32 r2
        \\  ldxw r1, [r0+32]
        \\  be32 r1
        \\  ldxw r0, [r0+36]
        \\  be32 r0
        \\  or r0, r1
        \\  or r0, r2
        \\  or r0, r3
        \\  or r0, r4
        \\  or r0, r5
        \\  or r0, r6
        \\  or r0, r7
        \\  or r0, r8
        \\  or r0, r9
        \\  exit
    ,
        &.{
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02,
            0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x08,
            0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00,
            0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x08, 0x00,
            0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00,
        },
        0x030F0F,
    );
}

test "store" {
    try testAsmWithMemory(
        \\entrypoint:
        \\  stb [r1+2], 0x11
        \\  ldxb r0, [r1+2]
        \\  exit
    ,
        &.{ 0xaa, 0xbb, 0xff, 0xcc, 0xdd },
        0x11,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  stw [r1+2], 0x44332211
        \\  ldxw r0, [r1+2]
        \\  exit
    ,
        &.{ 0xaa, 0xbb, 0xff, 0xff, 0xff, 0xff, 0xcc, 0xdd },
        0x44332211,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  stdw [r1+2], 0x44332211
        \\  ldxdw r0, [r1+2]
        \\  exit
    ,
        &.{
            0xaa, 0xbb, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff, 0xcc, 0xdd,
        },
        0x44332211,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov32 r2, 0x11
        \\  stxb [r1+2], r2
        \\  ldxb r0, [r1+2]
        \\  exit
    ,
        &.{ 0xaa, 0xbb, 0xff, 0xcc, 0xdd },
        0x11,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov32 r2, 0x2211
        \\  stxh [r1+2], r2
        \\  ldxh r0, [r1+2]
        \\  exit
    ,
        &.{ 0xaa, 0xbb, 0xff, 0xff, 0xcc, 0xdd },
        0x2211,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov32 r2, 0x44332211
        \\  stxw [r1+2], r2
        \\  ldxw r0, [r1+2]
        \\  exit
    ,
        &.{ 0xaa, 0xbb, 0xff, 0xff, 0xff, 0xff, 0xcc, 0xdd },
        0x44332211,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov r2, -2005440939
        \\  lsh r2, 32
        \\  or r2, 0x44332211
        \\  stxdw [r1+2], r2
        \\  ldxdw r0, [r1+2]
        \\  exit
    ,
        &.{
            0xaa, 0xbb, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff, 0xcc, 0xdd,
        },
        0x8877665544332211,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov r0, 0xf0
        \\  mov r2, 0xf2
        \\  mov r3, 0xf3
        \\  mov r4, 0xf4
        \\  mov r5, 0xf5
        \\  mov r6, 0xf6
        \\  mov r7, 0xf7
        \\  mov r8, 0xf8
        \\  stxb [r1], r0
        \\  stxb [r1+1], r2
        \\  stxb [r1+2], r3
        \\  stxb [r1+3], r4
        \\  stxb [r1+4], r5
        \\  stxb [r1+5], r6
        \\  stxb [r1+6], r7
        \\  stxb [r1+7], r8
        \\  ldxdw r0, [r1]
        \\  be64 r0
        \\  exit
    ,
        &.{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff },
        0xf0f2f3f4f5f6f7f8,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov r0, r1
        \\  mov r1, 0xf1
        \\  mov r9, 0xf9
        \\  stxb [r0], r1
        \\  stxb [r0+1], r9
        \\  ldxh r0, [r0]
        \\  be16 r0
        \\  exit
    ,
        &.{ 0xff, 0xff },
        0xf1f9,
    );

    try testAsmWithMemory(
        \\entrypoint:
        \\  mov r0, r1
        \\  ldxb r9, [r0+0]
        \\  stxb [r0+1], r9
        \\  ldxb r8, [r0+1]
        \\  stxb [r0+2], r8
        \\  ldxb r7, [r0+2]
        \\  stxb [r0+3], r7
        \\  ldxb r6, [r0+3]
        \\  stxb [r0+4], r6
        \\  ldxb r5, [r0+4]
        \\  stxb [r0+5], r5
        \\  ldxb r4, [r0+5]
        \\  stxb [r0+6], r4
        \\  ldxb r3, [r0+6]
        \\  stxb [r0+7], r3
        \\  ldxb r2, [r0+7]
        \\  stxb [r0+8], r2
        \\  ldxb r1, [r0+8]
        \\  stxb [r0+9], r1
        \\  ldxb r0, [r0+9]
        \\  exit
    ,
        &.{
            0x2a, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00,
        },
        0x2a,
    );
}

fn testAsm(source: []const u8, expected: anytype) !void {
    return testAsmWithMemory(source, &.{}, expected);
}

fn testAsmWithMemory(source: []const u8, program_memory: []const u8, expected: anytype) !void {
    const allocator = std.testing.allocator;
    var executable = try Executable.fromAsm(allocator, source);
    defer executable.deinit(allocator);

    const mutable = try allocator.dupe(u8, program_memory);
    defer allocator.free(mutable);

    const m = try MemoryMap.init(&.{
        Region.init(.readable, &.{}, memory.PROGRAM_START),
        Region.init(.readable, &.{}, memory.STACK_START),
        Region.init(.readable, &.{}, memory.HEAP_START),
        Region.init(.writeable, mutable, memory.INPUT_START),
    }, .v1);

    var vm = try Vm.init(&executable, m, allocator);
    defer vm.deinit();

    const result = vm.run();
    try expectEqual(expected, result);
}
