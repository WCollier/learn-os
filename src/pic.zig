const x86 = @import("x86.zig");

const PIC1_COMMAND: usize = 0x20;

const PIC1_DATA: usize = 0x21;

const PIC2_COMMAND: usize = 0xA0;

const PIC2_DATA: usize = 0xA1;

const PIC_EOI: usize = 0x20; 

// ICW4 (not) needed
const ICW1_ICW4: u8 = 0x01;

// Single (cascade) mode
const ICW1_SINGLE: u8 = 0x02;

// Call address interval 4 (8)
const ICW1_INTERVAL4: u8 = 0x04;

// Level triggered (edge) mode
const ICW1_LEVEL: u8 = 0x08;

// Initilisation required!
const ICW1_INIT: u8 = 0x10;

// 8086/88 mode
const ICW4_8086: u8 = 0x01;

// Auto (normal) EOI
const ICW4_AUTO: u8 = 0x02;

// Buffered mode/slave
const ICW4_BUF_SLAVE: u8 = 0x08;

// Buffered mode/master
const ICW4_BUF_MASTER: u8 = 0x0C;

// Special fully nested (not)
const ICW4_SFNM: u8 = 0x10;

pub fn remap() void {
    const a1: u8 = x86.inb(PIC1_DATA);

    const a2: u8 = x86.inb(PIC2_DATA);

    // Just for testing
    const offset1 = 0x20;

    const offset2 = 0x28;

    // Starts init sequence (in cascade mode
    x86.outb(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);

    x86.io_wait();

    x86.outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);

    x86.io_wait();

    // ICW2: Master PIC vector offset
    x86.outb(PIC1_DATA, offset1);

    x86.io_wait();

    // ICW2: Slave PIC vector offset
    x86.outb(PIC2_DATA, offset2);

    x86.io_wait();

    // ICW3: tell master PIC that there is a slave PIC
    x86.outb(PIC1_DATA, 4);

    x86.io_wait();

    // ICW3: tell slave PIC its identity
    x86.outb(PIC1_DATA, 2);

    x86.io_wait();

    x86.outb(PIC1_DATA, ICW4_8086);

    x86.io_wait();

    x86.outb(PIC2_DATA, ICW4_8086);

    x86.io_wait();

    // Restore saved masks
    x86.outb(PIC1_DATA, a1);

    x86.outb(PIC2_DATA, a2);
}

fn sendEoi(irq: u8) void {
    // Must send to both master and slave PICs
    if (irq >= 8) {
        x86.outb(PIC2_COMMAND, PIC_EOI);
    }

    x86.outb(PIC1_COMMAND, PIC_EOI);
}
