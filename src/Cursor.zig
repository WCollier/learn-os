const VGA_WIDTH = @import("Vga.zig").VGA_WIDTH;

const x86 = @import("x86.zig");

pub const Cursor = struct {
    pos: usize = 0,

    const CtrlReg: u16 = 0x3D4;

    const DataReg: u16 = 0x3D5;

    const Self = @This();

    pub fn init() Cursor {
        return Cursor {};
    }

    fn enable() void {
        x86.outb(CtrlReg, 0x0A);

        x86.outb(DataReg, 0x00);
    }

    fn getPos(self: *Self) usize {
        x86.outb(CtrlReg, 0x0F);

        self.pos = 0 | x86.inb(DataReg);

        x86.outb(CtrlReg, 0x0E);

        self.pos |= @as(u16, x86.inb(DataReg)) << 8;
    }

    pub fn move(self: *Self) void {
        x86.outb(CtrlReg, 0x0F);

        x86.outb(DataReg, @truncate(u8, self.pos));

        x86.outb(CtrlReg, 0x0E);

        x86.outb(DataReg, @truncate(u8, self.pos >> 8));
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
};
