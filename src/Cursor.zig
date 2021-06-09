const VGA_WIDTH = @import("Vga.zig").VGA_WIDTH;

pub const Cursor = struct {
    pos: usize = 0,

    const CtrlReg: u16 = 0x3D4;

    const DataReg: u16 = 0x3D5;

    const Self = @This();

    pub fn init() Cursor {
        return Cursor {};
    }

    fn enable() void {
        outb(CtrlReg, 0x0A);

        outb(DataReg, 0x00);
    }

    fn getPos(self: *Self) usize {
        outb(CtrlReg, 0x0F);

        self.pos = 0 | inb(DataReg);

        outb(CtrlReg, 0x0E);

        self.cursor |= @as(u16, inb(DataReg)) << 8;
    }

    pub fn move(self: *Self) void {
        outb(CtrlReg, 0x0F);

        outb(DataReg, @truncate(u8, self.pos));

        outb(CtrlReg, 0x0E);

        outb(DataReg, @truncate(u8, self.pos >> 8));
    }

    pub fn column(self: *Self) usize {
        return self.pos % VGA_WIDTH;
    }

    pub fn row(self: *Self) usize {
        return self.pos / VGA_WIDTH;
    }

    pub fn returnLine(self: *Self) void {
        // Find the current column number, subtract the total width from the column, creating a newline
        self.pos += VGA_WIDTH - self.column();

        self.move();
    }

    fn inb(port: u16) u8 {
        return asm volatile ("inb %[port], %[result]" 
            : [result] "={al}" (-> u8)
            : [port] "N{dx}" (port));
    }

    fn outb(port: u16, code: u8) void {
        asm volatile ("outb %[code], %[port]" : : [code] "{al}" (code), 
            [port] "N{dx}" (port));
    }
};
