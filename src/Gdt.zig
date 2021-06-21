const std = @import("std");

const GRANULARITY = 0xFFFFF;

const PROTECTED = 1 << 2;

const BLOCKS_4K = 1 << 3;

const Entry = packed struct {
    limit_low: u16,
    base_low: u24,
    access: Access,
    //base_low: u16,
    //base_middle: u8,
    //access: u8,
    limit_high: u4,
    flags: Flags,
    //flags: u4,
    base_high: u8,

    fn init(base: usize, limit: usize, access: Access, flags: Flags) Entry {
        return Entry{
            .limit_low = @truncate(u16, limit),
            .base_low = @truncate(u24, base), 
            .access = access, 
            //.base_low = @truncate(u16, base),
            //.base_middle = @truncate(u8, base >> 16),
            //.access = @truncate(u8, access),
            .limit_high = @truncate(u4, limit >> 16),
            .flags = flags,
            //.flags = @truncate(u4, flags),
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
    priv: u2,
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

pub const Ptr = packed struct {
    limit: u16,
    base: *const Entry,
};

const NULL_SEGMENT: Access = .{
    .accessed = false,
    .read_write = false,
    .direction_conforming = false,
    .executable = false,
    .descriptor = false,
    .priv = 0,
    .present = false,
};

const KERNEL_CODE_SEGMENT: Access = .{
    .accessed = false,
    .read_write = true,
    .direction_conforming = false,
    .executable = true,
    .descriptor = true,
    .priv = 0,
    .present = true,
};

const KERNEL_DATA_SEGMENT: Access = .{
    .accessed = false,
    .read_write = true,
    .direction_conforming = false,
    .executable = false,
    .descriptor = true,
    .priv = 0,
    .present = true,
};

const USER_CODE_SEGMENT: Access = .{
    .accessed = false,
    .read_write = true,
    .direction_conforming = false,
    .executable = true,
    .descriptor = true,
    .priv = 3,
    .present = true,
};

const USER_DATA_SEGMENT: Access = .{
    .accessed = false,
    .read_write = true,
    .direction_conforming = false,
    .executable = false,
    .descriptor = true,
    .priv = 3,
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

const gdt_entries align(4) = [_]Entry{
    Entry.init(0, 0, NULL_SEGMENT, NULL_FLAGS),
    Entry.init(0, GRANULARITY, KERNEL_CODE_SEGMENT, FLAGS),
    Entry.init(0, GRANULARITY, KERNEL_DATA_SEGMENT, FLAGS),
    Entry.init(0, GRANULARITY, USER_CODE_SEGMENT, FLAGS),
    Entry.init(0, GRANULARITY, USER_DATA_SEGMENT, FLAGS),
    Entry.init(0, 0, NULL_SEGMENT, NULL_FLAGS),
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
}
