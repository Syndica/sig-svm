const std = @import("std");
const builtin = @import("builtin");
const Vm = @import("Vm.zig");
const Executable = @import("Executable.zig");

/// prints a null-terminated utf-8 string
pub fn syscallString(
    vm: *Vm,
) Executable.SyscallError!void {
    const vm_addr = vm.registers.get(.r1);
    const len = vm.registers.get(.r2);
    const host_addr = try vm.memory_map.vmap(.constant, vm_addr, len);
    const string = std.mem.sliceTo(host_addr, 0);
    if (!builtin.is_test) std.debug.print("{s}", .{string});
}
