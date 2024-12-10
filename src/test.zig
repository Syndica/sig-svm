const std = @import("std");
const Vm = @import("Vm.zig");
const Executable = @import("Executable.zig");

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

fn testAsm(source: []const u8, expected: anytype) !void {
    const allocator = std.testing.allocator;
    var executable = try Executable.fromAsm(allocator, source);
    defer executable.deinit(allocator);

    var vm = try Vm.init(&executable, allocator);
    defer vm.deinit();

    const result = vm.run();
    try expectEqual(expected, result);
}
