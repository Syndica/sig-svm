const std = @import("std");
const builtin = @import("builtin");

const Elf = @import("Elf.zig");
const Executable = @import("Executable.zig");
const Vm = @import("Vm.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = if (builtin.mode == .Debug)
        gpa.allocator()
    else
        std.heap.c_allocator;

    var input_path: ?[]const u8 = null;

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    while (args.next()) |arg| {
        if (input_path) |file| {
            fail("input file already given: {s}", .{file});
        } else {
            input_path = arg;
        }
    }

    if (input_path == null) {
        fail("no input file provided", .{});
    }

    const input_file = try std.fs.cwd().openFile(input_path.?, .{});
    defer input_file.close();

    // var elf = try Elf.parse(allocator, input_file);
    // defer elf.deinit(allocator);
    // try elf.validate();

    var executable = try Executable.fromAsm(allocator,
        \\entrypoint:
        \\    mov32 r0, 16
        \\    exit
    );
    defer executable.deinit(allocator);

    var vm = try Vm.init(&executable, allocator);
    defer vm.deinit();
    try vm.run();
}

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(fmt ++ "\n", args) catch @panic("failed to print the stderr");
    std.posix.abort();
}
