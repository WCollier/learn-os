pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8)
        : [port] "N{dx}" (port)
    );
}

pub fn outb(port: u16, code: u8) void {
    asm volatile ("outb %[code], %[port]"
        :
        : [code] "{al}" (code),
          [port] "N{dx}" (port)
    );
}

pub fn io_wait() void {
    outb(0x80, 0);
}

pub fn hang() void {
    while (true) {
        asm volatile (
            \\cli
            \\hlt
        );
    }
}
