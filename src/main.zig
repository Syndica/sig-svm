const std = @import("std");
const builtin = @import("builtin");

const Input = @import("Input.zig");
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

    var input = try Input.parse(allocator, input_file);
    defer input.deinit(allocator);

    try input.validate();

    var vm = try Vm.init(&input, allocator);
    defer vm.deinit();
    try vm.run();
}

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(fmt ++ "\n", args) catch @panic("failed to print the stderr");
    std.posix.abort();
}
