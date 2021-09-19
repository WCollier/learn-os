const std = @import("std");

const GRANULARITY = 0xFFFFF;

const KERNEL_DATA = 0x10;

const TSS_ENTRY_INDEX = gdt_entries.len - 1;

const TSS_OFFSET: u16 = 0x28;

pub const KERNEL_CODE_OFFSET = 0x08;

const Entry = packed struct {
    limit_low: u16,
    base_low: u24,
    access: Access,
    limit_high: u4,
    flags: Flags,
    base_high: u8,

    fn init(base: u32, limit: u20, access: Access, flags: Flags) Entry {
        return Entry{
            .limit_low = @truncate(u16, limit),
            .base_low = @truncate(u24, base), 
            // Have to do this manually for some reason...
            // Doing below produces a triple fault (for some reason) (a bug?)
            //.access = access,
            .access = .{
                .accessed = access.accessed,
                .read_write = access.read_write,
                .direction_conforming = access.direction_conforming,
                .executable = access.executable,
                .descriptor = access.descriptor,
                .privilege = access.privilege,
                .present = access.present
            },
            .limit_high = @truncate(u4, limit >> 16),
            // Have to do this manually for some reason...
            // Doing below produces a triple fault (for some reason) (a bug?)
            // .flags = flags,
            .flags = .{
                .reserved = flags.reserved,
                .is_64 = flags.is_64,
                .bit_size = flags.bit_size,
                .granulaity = flags.granulaity,
            },
            .base_high = @truncate(u8, base >> 24),
        };
    }
};

const Access = packed struct {
    accessed: bool,
    read_write: bool,
    direction_conforming: bool,
    executable: bool,
    descriptor: bool,
    privilege: u2,
    present: bool,
};

const Flags = packed struct {
    reserved: bool = false,
    is_64: bool,
    bit_size: packed enum (u1) {
        i16,
        i32,
    },
    granulaity: bool,
};

const Tss = packed struct {
    prev: u16,
    reserved1: u16,
    esp0: Register32,
    ss0: Register16,
    esp1: Register32,
    ss1: Register16,
    ss2: Register32,
    cr3: Register32,
    eip: Register32,
    eflags: Register32,
    eax: Register32,
    ecx: Register32,
    edx: Register32,
    ebx: Register32,
    esp: Register32,
    ebp: Register32,
    esi: Register32,
    edi: Register32,
    es: Register16,
    cs: Register16,
    ss: Register16,
    ds: Register16,
    fs: Register16,
    gs: Register16,
    ldtr: Register16,
    reserved2: u16,
    io_permissions_base_offset: u16,
};

const Register16 = packed struct {
    reg: u16,
    reserved: u16,
};

const Register32 = u32;

const Ptr = packed struct {
    limit: u16,
    base: *const Entry,
};

const NULL_SEGMENT: Access = .{
    .accessed = false,
    .read_write = false,
    .direction_conforming = false,
    .executable = false,
    .descriptor = false,
    .privilege = 0,
    .present = false,
};

const KERNEL_CODE_SEGMENT: Access = .{
    .accessed = false,
    .read_write = true,
    .direction_conforming = false,
    .executable = true,
    .descriptor = true,
    .privilege = 0,
    .present = true,
};

const KERNEL_DATA_SEGMENT: Access = .{
    .accessed = false,
    .read_write = true,
    .direction_conforming = false,
    .executable = false,
    .descriptor = true,
    .privilege = 0,
    .present = true,
};

const USER_CODE_SEGMENT: Access = .{
    .accessed = false,
    .read_write = true,
    .direction_conforming = false,
    .executable = true,
    .descriptor = true,
    .privilege = 3,
    .present = true,
};

const USER_DATA_SEGMENT: Access = .{
    .accessed = false,
    .read_write = true,
    .direction_conforming = false,
    .executable = false,
    .descriptor = true,
    .privilege = 3,
    .present = true,
};

const TSS_SEGMENT: Access = .{ 
    .accessed = true,
    .read_write = false,
    .direction_conforming = false,
    .executable = true,
    .descriptor = false,
    .privilege = 0,
    .present = true,
};

const NULL_FLAGS: Flags = .{
    .is_64 = false,
    .bit_size = .i16,
    .granulaity = false,
};

// TODO: Is this correct?
const FLAGS: Flags = .{
    .is_64 = false,
    .bit_size = .i32, 
    .granulaity = true,
};

var gdt_entries align(4) = [_]Entry{
    Entry.init(0, 0, NULL_SEGMENT, NULL_FLAGS),
    Entry.init(0, GRANULARITY, KERNEL_CODE_SEGMENT, FLAGS),
    Entry.init(0, GRANULARITY, KERNEL_DATA_SEGMENT, FLAGS),
    Entry.init(0, GRANULARITY, USER_CODE_SEGMENT, FLAGS),
    Entry.init(0, GRANULARITY, USER_DATA_SEGMENT, FLAGS),
    Entry.init(0, 0, NULL_SEGMENT, NULL_FLAGS),
};

const tss_entry: Tss = {
    var tss = std.mem.zeroes(Tss);

    tss.ss0.reg = KERNEL_DATA;

    tss.io_permissions_base_offset = @sizeOf(Tss);

    return tss;
};

const gdt_ptr = Ptr{
    .limit = @as(u16, @sizeOf(@TypeOf(gdt_entries))),
    .base = &gdt_entries[0],
};

extern fn loadGdt(ptr: *const Ptr)void;

comptime {
   asm (
        \\ .type loadGdt @function
        \\loadGdt:
            \\mov +4(%esp), %eax
            \\lgdt (%eax)
            \\
            \\mov $0x10, %ax
            \\mov %ax, %ds
            \\mov %ax, %es
            \\mov %ax, %fs
            \\mov %ax, %gs
            \\mov %ax, %ss

            \\ljmp $0x08, $1f
            \\1: ret
    );
}

pub fn init() void {
    loadGdt(&gdt_ptr);

    // Must be separate for some reason...
    gdt_entries[TSS_ENTRY_INDEX] = Entry.init(@ptrToInt(&tss_entry), @sizeOf(Tss) - 1, TSS_SEGMENT, NULL_FLAGS);

    asm volatile ("ltr %[offset]" : : [offset] "r" (TSS_OFFSET));
}

