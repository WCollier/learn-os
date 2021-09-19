const std = @import("std");

const Gdt = @import("Gdt.zig");

const Isr = @import("Isr.zig");

pub const InterruptHandler = fn() callconv(.Naked) void;

const idt_size = 256;

const Entry = packed struct {
    isr_low: u16,
    kernel_cs: u16,
    reserved: u8 = 0,
    gate_type: GateType, 
    storage_segment: bool,
    privilege: PrivilegeLevel,
    present: bool,
    isr_high: u16,

    const Self = @This();

    fn init(isr: u32, kernel_cs: u16, gate_type: GateType, privilege: PrivilegeLevel, present: bool) Self {
        return Entry {
            .isr_low = @truncate(u16, isr),
            .kernel_cs = kernel_cs,
            .reserved = 0,
            .gate_type = gate_type,
            .storage_segment = false,
            .privilege = privilege,
            .present = present,
            .isr_high = @truncate(u16, isr >> 16),
        };
    }
};

const GateType = packed enum(u4) {
    // A special case
    _empty = 0,

    task_gate_32 = 5,
    interrupt_gate_16 = 6,
    trap_gate_16 = 7,
    interrupt_gate_32 = 14,
    trap_gate_32 = 15,
};

const PrivilegeLevel = packed enum(u2) {
    ring0 = 0,
    ring1 = 1,
    ring2 = 2,
    ring3 = 3,
};

const IdtRegister = packed struct {
    limit: u16,
    base: *[idt_size]Entry, // Maybe u64?
};

const IdtError = error{
    InvalidIdtIndex,
    AlreadyExists,
};

const table_register: IdtRegister = .{
    .limit = @as(u16, @sizeOf(@TypeOf(table))),
    .base = &table,
};

// Needs align(16) here?
var table: [idt_size]Entry = [_]Entry{ Entry.init(0, 0, ._empty, .ring0, false) } ** idt_size; 

fn isValidIdtIndex(n: u8) bool {
    return n >= 0 or n < idt_size; // TODO: Handle syscall interrupt
}

pub fn openGate(index: u8, routine: InterruptHandler) IdtError!void {
    if (!isValidIdtIndex(index)) {
        return IdtError.InvalidIdtIndex;
    }

    if (table[index].present) {
        return IdtError.AlreadyExists;
    }

    // TODO: Do I need to add the index to the offset?
    table[index] = Entry.init(@ptrToInt(routine), Gdt.KERNEL_CODE_OFFSET, .interrupt_gate_32, .ring0, true); 
}

pub fn init() void {
    const table_ptr = @ptrToInt(&table_register);

    asm volatile ("lidt (%[idtr])" : : [idtr] "r" (table_ptr));

    std.log.info("{}", .{table[0]});

    //openGate(0, example_routine);

    //asm volatile ("sti");
}
