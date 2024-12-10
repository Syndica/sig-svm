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

    pub fn region(map: MemoryMap, access: AccessType, vm_addr: u64) !Region {
        return switch (map) {
            .aligned => |aligned| aligned.region(access, vm_addr),
        };
    }

    pub fn vmap(map: MemoryMap, access: AccessType, vm_addr: u64, len: u64) ![]u8 {
        return switch (map) {
            .aligned => |aligned| aligned.vmap(access, vm_addr, len),
        };
    }
};

const AccessType = enum {
    load,
    store,
};

const MemoryState = enum {
    readable,
    writeable,
};

pub const Region = struct {
    slice: []u8,
    vm_addr_start: u64,
    vm_addr_end: u64,
    state: MemoryState,

    // TODO: use the `state` to ensure `slice` is immutable for readonly regions
    pub fn init(slice: []u8, vm_addr: u64, state: MemoryState) Region {
        const vm_addr_end = vm_addr +| slice.len;

        return .{
            .slice = slice,
            .vm_addr_start = vm_addr,
            .vm_addr_end = vm_addr_end,
            .state = state,
        };
    }

    fn translate(reg: Region, vm_addr: u64, len: u64) ![]u8 {
        if (vm_addr < reg.vm_addr_start) return error.InvalidVirtualAddress;

        const begin_offset = vm_addr -| reg.vm_addr_start;
        if (len <= reg.slice.len) {
            return (reg.slice.ptr + begin_offset)[0..len];
        }

        return error.InvalidVirtualAddress;
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

    fn region(map: *const AlignedMemoryMap, access: AccessType, vm_addr: u64) !Region {
        const index = vm_addr >> VIRTUAL_ADDRESS_BITS;

        if (index >= 1 and index <= map.regions.len) {
            const reg = map.regions[index - 1];

            if (vm_addr >= reg.vm_addr_start and
                vm_addr < reg.vm_addr_end and
                (access == .load or reg.state == .writeable))
            {
                return reg;
            }
        }
        return error.AccessViolation;
    }

    fn vmap(map: *const AlignedMemoryMap, access: AccessType, vm_addr: u64, len: u64) ![]u8 {
        const reg = try map.region(access, vm_addr);
        return reg.translate(vm_addr, len);
    }
};

const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

test "aligned vmap" {
    var program_mem: [4]u8 = .{0xFF} ** 4;
    var stack_mem: [4]u8 = .{0xDD} ** 4;

    const m = try MemoryMap.init(&.{
        Region.init(&program_mem, PROGRAM_START, .writeable),
        Region.init(&stack_mem, STACK_START, .readable),
    }, .v1);

    try expectEqual(
        program_mem[0..1],
        try m.vmap(.load, PROGRAM_START, 1),
    );
    try expectEqual(
        program_mem[0..3],
        try m.vmap(.load, PROGRAM_START, 3),
    );
    try expectError(
        error.InvalidVirtualAddress,
        m.vmap(.load, PROGRAM_START, 5),
    );

    try expectError(
        error.AccessViolation,
        m.vmap(.store, STACK_START, 2),
    );
    try expectError(
        error.AccessViolation,
        m.vmap(.store, STACK_START, 5),
    );
    try expectEqual(
        stack_mem[1..3],
        try m.vmap(.load, STACK_START + 1, 2),
    );
}

test "aligned region" {
    var program_mem: [4]u8 = .{0xFF} ** 4;
    var stack_mem: [4]u8 = .{0xDD} ** 4;

    const m = try MemoryMap.init(&.{
        Region.init(&program_mem, PROGRAM_START, .writeable),
        Region.init(&stack_mem, STACK_START, .readable),
    }, .v1);

    try expectError(
        error.AccessViolation,
        m.region(.load, PROGRAM_START - 1),
    );
    try expectEqual(
        &program_mem,
        (try m.region(.load, PROGRAM_START)).slice,
    );
    try expectEqual(
        &program_mem,
        (try m.region(.load, PROGRAM_START + 3)).slice,
    );
    try expectError(
        error.AccessViolation,
        m.region(.load, PROGRAM_START + 4),
    );

    try expectError(
        error.AccessViolation,
        m.region(.store, STACK_START),
    );
    try expectEqual(
        &stack_mem,
        (try m.region(.load, STACK_START)).slice,
    );
    try expectEqual(
        &stack_mem,
        (try m.region(.load, STACK_START + 3)).slice,
    );
    try expectError(
        error.AccessViolation,
        m.region(.load, INPUT_START + 4),
    );
}

test "invalid memory region" {
    var program_mem: [4]u8 = .{0xFF} ** 4;
    var stack_mem: [4]u8 = .{0xDD} ** 4;

    try expectError(
        error.InvalidMemoryRegion,
        MemoryMap.init(&.{
            Region.init(&stack_mem, STACK_START, .readable),
            Region.init(&program_mem, PROGRAM_START, .writeable),
        }, .v1),
    );
}
