const std = @import("std");

const Interrupt = @import("interrupt.zig");

const Idt = @import("Idt.zig");

const x86 = @import("x86.zig");

pub const num_exceptions: u8 = 32;

pub const InterruptRoutine = fn(*Interrupt.CpuState) usize;

const IsrError = error{
    InvalidIsrIndex,
    AlreadyExists,
};

const Exception = struct {
    tag: ExceptionTag,
    kind: ?ExceptionKind,
    error_code: bool,

    fn init(tag: ExceptionTag, kind: ?ExceptionKind, error_code: bool) Exception {
        return Exception{
            .tag = tag,
            .kind = kind,
            .error_code = error_code
        };
    }
};

const ExceptionTag = enum {
    divide_by_zero,
    debug,
    non_maskable_interrupt,
    breakpoint,
    overflow,
    bound_range_exceeded,
    invalid_opcode,
    device_not_available,
    double_fault,
    coprocessor_segment_overrun,
    invalid_tss,
    segment_not_present,
    stack_segment_fault,
    general_protection_fault,
    page_fault,
    x87_floating_point_exception,
    alignment_check,
    machine_check,
    simd_floating_point_exception,
    virtualisation_exception,
    reserved,
    security_exception,
    triple_fault,

    pub fn format(self: ExceptionTag, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const msg = switch (self) {
            .divide_by_zero => "Divide By Zero",
            .debug => "Debug",
            .non_maskable_interrupt => "Non-maskable Interrupt",
            .breakpoint => "Breakpoint",
            .overflow => "Overflow",
            .bound_range_exceeded => "Bound Range Exceeded",
            .invalid_opcode => "Invalid Opcode",
            .device_not_available => "Device Not Available",
            .double_fault => "Double Fault",
            .coprocessor_segment_overrun => "Coprocessor Segment Overrun",
            .invalid_tss => "Invalid TSS",
            .segment_not_present => "Segment Not Present",
            .stack_segment_fault => "Stack Segment Fault",
            .general_protection_fault => "General Protection Fault",
            .page_fault => "Page Fault",
            .reserved => "Reserved",
            .x87_floating_point_exception => "x87 Floating Point Exception",
            .alignment_check => "Alignment Check",
            .machine_check => "Machine Check",
            .simd_floating_point_exception => "SIMD Floating Point Exception",
            .virtualisation_exception => "Virtualisation Exception",
            .security_exception => "Security Exception",
            .triple_fault => "Triple Fault",
        };

        try writer.writeAll(msg);
    }
};

const ExceptionKind = enum {
    fault,
    fault_trap,
    interrupt,
    trap,
    abort,

    fn is_fault(self: ExceptionKind) bool {
        return self == .fault or self == .fault_trap;
    }
};

const exceptions = [num_exceptions]Exception{
    Exception.init(.divide_by_zero, .fault, true),
    Exception.init(.debug, .fault_trap, false), // Could also be considered a fault
    Exception.init(.non_maskable_interrupt, .interrupt, false),
    Exception.init(.breakpoint, .trap, false),
    Exception.init(.overflow, .trap, false),
    Exception.init(.bound_range_exceeded, .fault, false),
    Exception.init(.invalid_opcode, .fault, false),
    Exception.init(.device_not_available, .fault, false),
    Exception.init(.double_fault, .abort, false),
    Exception.init(.coprocessor_segment_overrun, .fault, false),
    Exception.init(.invalid_tss, .fault, true),
    Exception.init(.segment_not_present, .fault, true),
    Exception.init(.stack_segment_fault, .fault, true),
    Exception.init(.general_protection_fault, .fault, true),
    Exception.init(.page_fault, .fault, true),
    Exception.init(.reserved, null, false), 
    Exception.init(.x87_floating_point_exception, .fault, false),
    Exception.init(.alignment_check, .fault, true),
    Exception.init(.machine_check, .abort, false),
    Exception.init(.simd_floating_point_exception, .fault, false),
    Exception.init(.virtualisation_exception, .fault, false),

    // 0x15 - 0x1D are reserved
    Exception.init(.reserved, null, false), 
    Exception.init(.reserved, null, false), 
    Exception.init(.reserved, null, false), 
    Exception.init(.reserved, null, false), 
    Exception.init(.reserved, null, false), 
    Exception.init(.reserved, null, false), 
    Exception.init(.reserved, null, false), 
    Exception.init(.reserved, null, false), 

    Exception.init(.security_exception, null, true),
    Exception.init(.reserved, null, false), 
    
    Exception.init(.triple_fault, null, false),
    //Exception.init("FPU Error Interrupt", .interrupt, false),
};

var routines = [_]?InterruptRoutine{null} ** 48;

fn isValidIsrIndex(n: u8) bool {
    return n >= 0 or n < NUM_EXCEPTIONS; // TODO: Handle syscall interrupt
}

export fn isrHandler(state: *Interrupt.CpuState) usize {
    const index = @truncate(u8, state.int_num);

    if (!isValidIsrIndex(index)) {
        // TODO: Add index here
        @panic("Invalid interrupt index");
    }

    if (routines[index]) |routine| {
        return routine(state);

    } else {
        @panic("No routine for this index!");
    }

    return @ptrToInt(state);
}

fn addIsr(index: u8, routine: InterruptRoutine) IsrError!void {
    if (!isValidIsrIndex(index)) {
        return IsrError.InvalidIsrIndex;
    }

    if (routines[index]) |_| {
        return IsrError.AlreadyExists;
    }

    routines[index] = routine;
}

fn exception_handler(state: *Interrupt.CpuState) usize {
    const index = state.int_num;

    // TODO: Is this correct?
    const ret_esp = @ptrToInt(state);

    if (index < num_exceptions) {
        const exception = exceptions[index];

        // TODO: For some of these try and use std.debug.panic in the future
        switch (exception.tag) {
            .breakpoint => std.log.info("Breakpoint!", .{}),
            .page_fault => @panic("Page Fault"),
            .double_fault => @panic("Double Fault"),
            .general_protection_fault => @panic("General Protection Fault"),
            else =>  {
                std.log.err("Unhandled exception: {}", .{index});

                x86.hang();
            },
        }
    }

    return ret_esp;
}

pub fn init() void {
    comptime var i = 0;

    inline while (i < num_exceptions) : (i += 1) {
        Idt.openGate(i, Interrupt.runInterrupt(i)) catch |err| {
            std.log.err("Could not open ISR: {}", .{err});
        };

        addIsr(i, exception_handler) catch |err| {};
    }
}
