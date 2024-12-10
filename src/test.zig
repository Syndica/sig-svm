const std = @import("std");
const Vm = @import("Vm.zig");
const Executable = @import("Executable.zig");

const expectEqual = std.testing.expectEqual;

test "basic mov" {
    const allocator = std.testing.allocator;
    var executable = try Executable.fromAsm(allocator,
        \\entrypoint:
        \\  mov32 r0, 16
        \\  exit
    );
    defer executable.deinit(allocator);

    var vm = try Vm.init(&executable, allocator);
    defer vm.deinit();

    const result = try vm.run();
    try expectEqual(16, result);
}
