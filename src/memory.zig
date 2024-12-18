const std = @import("std");
const ebpf = @import("ebpf.zig");

pub const PROGRAM_START: u64 = 0x100000000;
pub const STACK_START: u64 = 0x200000000;
pub const HEAP_START: u64 = 0x300000000;
pub const INPUT_START: u64 = 0x400000000;
const VIRTUAL_ADDRESS_BITS = 32;

pub const MemoryMap = union(enum) {
    aligned: AlignedMemoryMap,

    pub fn init(regions: []const Region, version: ebpf.SBPFVersion) !MemoryMap {
        return .{ .aligned = try AlignedMemoryMap.init(regions, version) };
    }

    pub fn region(map: MemoryMap, vm_addr: u64) !Region {
        return switch (map) {
            .aligned => |aligned| aligned.region(vm_addr),
        };
    }

    pub fn vmap(
        map: MemoryMap,
        comptime state: MemoryState,
        vm_addr: u64,
        len: u64,
    ) !state.Slice() {
        return switch (map) {
            .aligned => |aligned| aligned.vmap(state, vm_addr, len),
        };
    }
};

pub const MemoryState = enum {
    mutable,
    constant,

    fn Slice(state: MemoryState) type {
        return switch (state) {
            .constant => []const u8,
            .mutable => []u8,
        };
    }

    fn Many(access: MemoryState) type {
        return switch (access) {
            .constant => [*]const u8,
            .mutable => [*]u8,
        };
    }
};

const HostMemory = union(MemoryState) {
    mutable: []u8,
    constant: []const u8,

    fn getSlice(host: HostMemory, comptime state: MemoryState) !state.Slice() {
        if (host != state) return error.AccessViolation;
        return @field(host, @tagName(state));
    }
};

pub const Region = struct {
    host_memory: HostMemory,
    vm_addr_start: u64,
    vm_addr_end: u64,

    pub fn init(comptime state: MemoryState, slice: state.Slice(), vm_addr: u64) Region {
        const vm_addr_end = vm_addr +| slice.len;

        return .{
            .host_memory = @unionInit(HostMemory, @tagName(state), slice),
            .vm_addr_start = vm_addr,
            .vm_addr_end = vm_addr_end,
        };
    }

    /// Get the underlying host slice of memory.
    ///
    /// Returns an error if you're trying to get mutable access to a constant region.
    pub fn getSlice(reg: Region, comptime state: MemoryState) !state.Slice() {
        return switch (state) {
            .constant => switch (reg.host_memory) {
                .constant => |constant| constant,
                .mutable => |mutable| mutable,
            },
            .mutable => switch (reg.host_memory) {
                .constant => return error.AccessViolation,
                .mutable => |mutable| mutable,
            },
        };
    }

    fn translate(
        reg: Region,
        comptime state: MemoryState,
        vm_addr: u64,
        len: u64,
    ) !state.Slice() {
        if (vm_addr < reg.vm_addr_start) return error.InvalidVirtualAddress;

        const host_slice = try reg.getSlice(state);
        const begin_offset = vm_addr -| reg.vm_addr_start;
        if (begin_offset + len <= host_slice.len) {
            return host_slice[begin_offset..][0..len];
        }

        return error.VirtualAccessTooLong;
    }
};

const AlignedMemoryMap = struct {
    regions: []const Region,
    version: ebpf.SBPFVersion,

    fn init(regions: []const Region, version: ebpf.SBPFVersion) !AlignedMemoryMap {
        for (regions, 1..) |reg, index| {
            if (reg.vm_addr_start >> VIRTUAL_ADDRESS_BITS != index) {
                return error.InvalidMemoryRegion;
            }
        }

        return .{
            .regions = regions,
            .version = version,
        };
    }

    fn region(map: *const AlignedMemoryMap, vm_addr: u64) !Region {
        const index = vm_addr >> VIRTUAL_ADDRESS_BITS;

        if (index >= 1 and index <= map.regions.len) {
            const reg = map.regions[index - 1];
            if (vm_addr >= reg.vm_addr_start and vm_addr < reg.vm_addr_end) {
                return reg;
            }
        }

        return error.AccessNotMapped;
    }

    fn vmap(
        map: *const AlignedMemoryMap,
        comptime state: MemoryState,
        vm_addr: u64,
        len: u64,
    ) !state.Slice() {
        const reg = try map.region(vm_addr);
        return reg.translate(state, vm_addr, len);
    }
};

const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

test "aligned vmap" {
    var program_mem: [4]u8 = .{0xFF} ** 4;
    var stack_mem: [4]u8 = .{0xDD} ** 4;

    const m = try MemoryMap.init(&.{
        Region.init(.mutable, &program_mem, PROGRAM_START),
        Region.init(.constant, &stack_mem, STACK_START),
    }, .v1);

    try expectEqual(
        program_mem[0..1],
        try m.vmap(.constant, PROGRAM_START, 1),
    );
    try expectEqual(
        program_mem[0..3],
        try m.vmap(.constant, PROGRAM_START, 3),
    );
    try expectError(
        error.VirtualAccessTooLong,
        m.vmap(.constant, PROGRAM_START, 5),
    );

    try expectError(
        error.AccessViolation,
        m.vmap(.mutable, STACK_START, 2),
    );
    try expectError(
        error.AccessViolation,
        m.vmap(.mutable, STACK_START, 5),
    );
    try expectEqual(
        stack_mem[1..3],
        try m.vmap(.constant, STACK_START + 1, 2),
    );
}

test "aligned region" {
    var program_mem: [4]u8 = .{0xFF} ** 4;
    var stack_mem: [4]u8 = .{0xDD} ** 4;

    const m = try MemoryMap.init(&.{
        Region.init(.mutable, &program_mem, PROGRAM_START),
        Region.init(.constant, &stack_mem, STACK_START),
    }, .v1);

    try expectError(
        error.AccessNotMapped,
        m.region(PROGRAM_START - 1),
    );
    try expectEqual(
        &program_mem,
        (try m.region(PROGRAM_START)).getSlice(.constant),
    );
    try expectEqual(
        &program_mem,
        (try m.region(PROGRAM_START + 3)).getSlice(.constant),
    );
    try expectError(
        error.AccessNotMapped,
        m.region(PROGRAM_START + 4),
    );

    try expectError(
        error.AccessViolation,
        (try m.region(STACK_START)).getSlice(.mutable),
    );
    try expectEqual(
        &stack_mem,
        (try m.region(STACK_START)).getSlice(.constant),
    );
    try expectEqual(
        &stack_mem,
        (try m.region(STACK_START + 3)).getSlice(.constant),
    );
    try expectError(
        error.AccessNotMapped,
        m.region(INPUT_START + 4),
    );
}

test "invalid memory region" {
    var program_mem: [4]u8 = .{0xFF} ** 4;
    var stack_mem: [4]u8 = .{0xDD} ** 4;

    try expectError(
        error.InvalidMemoryRegion,
        MemoryMap.init(&.{
            Region.init(.constant, &stack_mem, STACK_START),
            Region.init(.mutable, &program_mem, PROGRAM_START),
        }, .v1),
    );
}
