const Idt = @import("Idt.zig");

pub const CpuState = packed struct {
    cr3: usize,
    gs: u32,
    fs: u32,
    es: u32,
    ds: u32,

    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,

    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    int_num: u32,
    error_code: u32,

    eip: u32,
    cs: u32,
    eflags: u32,
    user_esp: u32,
    user_ss: u32,
};

export fn common() callconv(.Naked) void {
    asm volatile (
        \\pusha // Save register state
        \\push %%ds
        \\push %%es
        \\push %%fs
        \\push %%gs
        \\mov %%cr3, %%eax
        \\push %%eax
        \\mov $0x10, %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%fs
        \\mov %%ax, %%gs
        \\mov %%esp, %%eax
        \\push %%eax
        \\call handler
        \\mov %%eax, %%esp
    );

    asm volatile (
        \\pop %%eax
        \\mov %%cr3, %%ebx
        \\cmp %%eax, %%ebx
        \\je same_cr3
        \\mov %%eax, %%cr3
        \\same_cr3:
            \\pop %%gs
            \\pop %%fs
            \\pop %%es
            \\pop %%ds
            \\popa
    );

    asm volatile (
        \\add $0x1c, %%esp
        \\.extern tss_entry
        \\mov %%esp, (tss_entry + 4)
        \\sub $0x14, %%esp
        \\iret
    );
}

// TODO: Try and remove
extern fn isrHandler(state: *CpuState) void;

export fn handler(state: *CpuState) void {
    isrHandler(state);
}

pub fn runInterrupt(comptime n: u32) Idt.InterruptHandler {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile ("cli");

            if (n != 8 and !(n >= 10 and n <= 14) and n != 17) {
                asm volatile ("pushl $0");
            }

            asm volatile (
                \\pushl %[n]
                \\jmp common
                : : [n] "n" (n)
            );
        }
    }.func;
}

