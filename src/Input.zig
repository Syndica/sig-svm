//! Represents the input ELF file

const std = @import("std");
const ebpf = @import("ebpf.zig");

const elf = std.elf;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Input = @This();

handle: std.fs.File,
header: elf.Elf64_Ehdr,
shdrs: std.ArrayListUnmanaged(elf.Elf64_Shdr) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},

pub fn parse(allocator: Allocator, input_file: std.fs.File) !Input {
    const header_buffer = try preadAllAlloc(allocator, input_file, 0, @sizeOf(elf.Elf64_Ehdr));
    defer allocator.free(header_buffer);

    var input: Input = .{
        .header = @as(*align(1) const elf.Elf64_Ehdr, @ptrCast(header_buffer)).*,
        .handle = input_file,
    };

    // section header offset
    const shoff = input.header.e_shoff;
    // number of section headers
    const shnum = input.header.e_shnum;
    // total size of the section headers
    const shsize = shnum * @sizeOf(elf.Elf64_Shdr);

    const shdrs_buffer = try preadAllAlloc(allocator, input_file, shoff, shsize);
    defer allocator.free(shdrs_buffer);
    const shdrs = @as([*]align(1) const elf.Elf64_Shdr, @ptrCast(shdrs_buffer.ptr))[0..shnum];
    try input.shdrs.appendUnalignedSlice(allocator, shdrs);

    // read the string table
    const shstrtab = try input.preadShdrContentsAlloc(allocator, input.header.e_shstrndx);
    defer allocator.free(shstrtab);
    try input.strtab.appendSlice(allocator, shstrtab);

    return input;
}

pub fn deinit(input: *Input, allocator: Allocator) void {
    input.shdrs.deinit(allocator);
    input.strtab.deinit(allocator);
}

pub fn run(input: *Input, allocator: std.mem.Allocator) !void {
    const instructions = try input.getInstructions(allocator);
    defer allocator.free(instructions);

    for (instructions) |inst| {
        switch (inst.opcode) {
            else => std.debug.panic("TODO: run {d}", .{inst.opcode}),
        }
    }
}

/// Validates the Input. Returns errors for issues encountered.
pub fn validate(input: *Input) !void {
    const header = input.header;

    // ensure 64-bit class
    if (header.e_ident[elf.EI_CLASS] != elf.ELFCLASS64) {
        return error.WrongClass;
    }
    // ensure little endian
    if (header.e_ident[elf.EI_DATA] != elf.ELFDATA2LSB) {
        return error.WrongEndianess;
    }
    // ensure no OS_ABI was set
    if (header.e_ident[ebpf.EI_OSABI] != ebpf.ELFOSABI_NONE) {
        return error.WrongAbi;
    }
    // ensure the ELF was compiled for BPF or possibly the custom SBPF machine number
    if (header.e_machine != elf.EM.BPF and @intFromEnum(header.e_machine) != ebpf.EM_SBPF) {
        return error.WrongMachine;
    }
    // ensure that this is a `.so`, dynamic library file
    if (header.e_type != .DYN) {
        return error.NotDynElf;
    }

    // TODO: what value should be used for V1? this leads us vulnerable to
    // having corrupt values pass.
    const sbpf_version: ebpf.SBPFVersion = if (header.e_flags == ebpf.EF_SBPF_V2)
        @panic("V2 sbpf not supported")
    else
        .V1;

    _ = sbpf_version;

    // ensure there is only one ".text" section
    {
        var count: u32 = 0;
        for (input.shdrs.items) |shdr| {
            if (std.mem.eql(u8, input.getString(shdr.sh_name), ".text")) {
                count += 1;
            }
        }
        if (count != 1) {
            return error.WrongNumberOfTextSections;
        }
    }

    // writable sections are not supported in our usecase
    // that will include ".bss", and ".data" sections that are writable
    // ".data.rel" is allowed though.
    for (input.shdrs.items) |shdr| {
        const name = input.getString(shdr.sh_name);
        if (std.mem.startsWith(u8, name, ".bss")) {
            return error.WritableSectionsNotSupported;
        }
        if (std.mem.startsWith(u8, name, ".data") and !std.mem.startsWith(u8, name, ".data.rel")) {
            // TODO: use a packed struct here, this is ugly
            if (shdr.sh_flags & (elf.SHF_ALLOC | elf.SHF_WRITE) == elf.SHF_ALLOC | elf.SHF_WRITE) {
                return error.WritableSectionsNotSupported;
            }
        }
    }

    // ensure all of the section headers are within bounds
    for (input.shdrs.items) |shdr| {
        const start = shdr.sh_offset;
        const end = try std.math.add(usize, start, shdr.sh_size);

        const file_size = (try input.handle.stat()).size;
        if (start > file_size or end > file_size) return error.Oob;
    }

    // ensure that the entry point is inside of the ".text" section
    const entrypoint = header.e_entry;
    const text_section = input.getShdrByName(".text") orelse
        return error.ShdrNotFound;

    if (entrypoint < text_section.sh_addr or
        entrypoint > text_section.sh_addr +| text_section.sh_size)
    {
        return error.EntrypointOutsideTextSection;
    }
}

fn getInstructions(input: *const Input, allocator: std.mem.Allocator) ![]const ebpf.Instruction {
    const text_section_index = input.getShdrIndexByName(".text") orelse
        return error.ShdrNotFound;
    const text_bytes: []align(@alignOf(ebpf.Instruction)) u8 =
        @alignCast(try input.preadShdrContentsAlloc(allocator, text_section_index));
    return std.mem.bytesAsSlice(ebpf.Instruction, text_bytes);
}

/// Allocates, reads, and returns the contents of a section header.
fn preadShdrContentsAlloc(
    self: *const Input,
    allocator: Allocator,
    index: u32,
) ![]u8 {
    assert(index < self.shdrs.items.len);
    const shdr = self.shdrs.items[index];
    const sh_offset = shdr.sh_offset;
    const sh_size = shdr.sh_size;
    return preadAllAlloc(allocator, self.handle, sh_offset, sh_size);
}

/// Allocates, reads, and returns the contents of the file at `file[offset..][0..size]`.
fn preadAllAlloc(
    allocator: Allocator,
    handle: std.fs.File,
    offset: u64,
    size: u64,
) ![]u8 {
    const buffer = try allocator.alloc(u8, size);
    errdefer allocator.free(buffer);
    const amt = try handle.preadAll(buffer, offset);
    if (amt != size) return error.InputOutput;
    return buffer;
}

/// Returns the string for a given index into the string table.
fn getString(self: *const Input, off: u32) [:0]const u8 {
    assert(off < self.strtab.items.len);
    return std.mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
}

fn getShdrIndexByName(self: *const Input, name: []const u8) ?u32 {
    for (self.shdrs.items, 0..) |shdr, i| {
        const shdr_name = self.getString(shdr.sh_name);
        if (std.mem.eql(u8, shdr_name, name)) {
            return @intCast(i);
        }
    }
    return null;
}

fn getShdrByName(self: *const Input, name: []const u8) ?elf.Elf64_Shdr {
    const index = self.getShdrIndexByName(name) orelse return null;
    return self.shdrs.items[index];
}
