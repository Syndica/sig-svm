const std = @import("std");
const Vm = @import("Vm.zig");
const Executable = @import("Executable.zig");

const expectEqual = std.testing.expectEqual;

test "mov" {
    try testAsm(
        \\entrypoint:
        \\  mov r0, 16
        \\  exit
    , 16);

    try testAsm(
        \\entrypoint:
        \\  mov r1, 16
        \\  mov r0, r1
        \\  exit
    , 16);
}

test "add" {
    try testAsm(
        \\entrypoint:
        \\  mov r0, 10
        \\  mov r1, 20
        \\  add r0, r1
        \\  exit
    , 30);

    try testAsm(
        \\entrypoint:
        \\  mov r0, 10
        \\  add r0, -2
        \\  exit
    , 8);
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
}

// test "basic mul" {
//     const allocator = std.testing.allocator;
//     var executable = try Executable.fromAsm(allocator,
//         \\entrypoint:
//         \\  mov r0, 10
//         \\  add32 r0, -2
//         \\  exit
//     );
//     defer executable.deinit(allocator);

//     var vm = try Vm.init(&executable, allocator);
//     defer vm.deinit();

//     const result = try vm.run();
//     try expectEqual(8, result);
// }

// test "lmul loop" {
// const allocator = std.testing.allocator;
// var executable = try Executable.fromAsm(allocator,
//     \\entrypoint:
//     \\  mov r0, 0x7
//     // \\  add r1, 0xa
//     // \\  lsh r1, 0x20
//     // \\  rsh r1, 0x20
//     // \\  jeq r1, 0x0, +4
//     // \\  mov r0, 0x7
//     // \\  lmul r0, 0x7
//     // \\  add r1, -1
//     // \\  jne r1, 0x0, -3
//     \\  exit
// );
// defer executable.deinit(allocator);

// var vm = try Vm.init(&executable, allocator);
// defer vm.deinit();

// const result = try vm.run();
// try expectEqual(8, result);
// }

fn testAsm(source: []const u8, expected: anytype) !void {
    const allocator = std.testing.allocator;
    var executable = try Executable.fromAsm(allocator, source);
    defer executable.deinit(allocator);

    var vm = try Vm.init(&executable, allocator);
    defer vm.deinit();

    const result = vm.run();
    try expectEqual(expected, result);
}
