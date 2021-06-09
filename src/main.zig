const std = @import("std");

const builtin = std.builtin;

const fmt = std.fmt;

const Colour = enum(u8) {
    black,
    blue,
    green,
    cyan,
    red,
    magenta,
    brown,
    light_grey,
    light_blue,
    light_green,
    light_cyan,
    light_red,
    light_magenta,
    light_brown,
    white,
};

const MultiBoot = packed struct {
    magic: i32,
    flags: i32,
    checksum: i32,
};

const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const MAGIC = 0x1BADB002;
const FLAGS = ALIGN | MEMINFO;

export var multiboot align(4) linksection(".multiboot") = MultiBoot {
    .magic = MAGIC,
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};

export var stack_bytes: [16 * 1024] u8 align(16) linksection(".bss") = undefined;

extern var __debug_info_start: u8;

extern var __debug_info_end: u8;

extern var __debug_abbrev_start: u8;

extern var __debug_abbrev_end: u8;

extern var __debug_line_start: u8;

extern var __debug_line_end: u8;

extern var __debug_ranges_start: u8;

extern var __debug_ranges_end: u8;

const stack_bytes_slice = stack_bytes[0..];

const ColourCode = packed struct {
    colour: u8,

    fn init(foreground: Colour, background: Colour) ColourCode {
        return ColourCode { .colour = (@enumToInt(background) << 4) | @enumToInt(foreground) };
    }
};

const ScreenChar = packed struct {
    char: u8,
    colour_code: ColourCode,

    fn init(char: u8, colour_code: ColourCode) ScreenChar {
        return ScreenChar { .char = char, .colour_code = colour_code };
    }
};

const Cursor = struct {
    pos: usize = 0,

    const CtrlReg: u16 = 0x3D4;

    const DataReg: u16 = 0x3D5;

    const Self = @This();

    fn init() Cursor {
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

    fn move(self: *Self) void {
        //const pos: u16 = @truncate(u16, y) * VGA_WIDTH + @truncate(u16, x);

        outb(CtrlReg, 0x0F);

        outb(DataReg, @truncate(u8, self.pos));

        outb(CtrlReg, 0x0E);

        outb(DataReg, @truncate(u8, self.pos >> 8));
    }

    fn column(self: *Self) usize {
        return self.pos % VGA_WIDTH;
    }

    fn row(self: *Self) usize {
        return self.pos / VGA_WIDTH;
    }

    fn returnLine(self: *Self) void {
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

const VGA_WIDTH = 80;

const VGA_HEIGHT = 25;

const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

const Terminal = struct {
    //row: usize = 0,

    //column: usize = 0,

    current_colour: ColourCode = ColourCode.init(.light_grey, .black),

    buffer: []ScreenChar,

    var cursor: Cursor = Cursor.init();

    const Self = @This();

    const Error = error{};

    const TerminalWriter = std.io.Writer(*Self, Error, terminalWriter); 

    fn init() Terminal {
        return Terminal {
            .buffer = @intToPtr([*]volatile ScreenChar, 0xB8000)[0..VGA_SIZE],
        };
    }

    fn putCharAt(self: *Self, screen_char: u8, x: usize, y: usize) void {
        if (screen_char == '\n') {
            // Find the current column number, subtract the total width from the column, creating a newline
            //const column = cursor.pos % VGA_WIDTH;

            //cursor.pos += VGA_WIDTH - cursor.column();

            cursor.returnLine();

            return;
        }

        const index = y * VGA_WIDTH + x;

        self.buffer[index].char = screen_char;

        self.buffer[index].colour_code = self.current_colour;

        cursor.pos += 1;
    }

    fn putChar(self: *Self, screen_char: u8) void {
        if (cursor.row() >= VGA_HEIGHT - 1) {
            self.scroll();
        }

        if (screen_char == '\n') {
            cursor.returnLine();

            return;
        }

        self.buffer[cursor.pos].char = screen_char;

        self.buffer[cursor.pos].colour_code = self.current_colour;

        //if ((cursor.column() % VGA_WIDTH) == 0 and cursor.pos > 0) {
        if (cursor.column() == VGA_WIDTH) {
            cursor.returnLine();
            //cursor.pos = (cursor.row() + 1) * VGA_WIDTH;
        //    cursor.pos += VGA_WIDTH - column;
        }

        cursor.pos += 1;

        //self.putCharAt(screen_char, self.column, self.row);
    }

    fn write(self: *Self, msg: []const u8) void {
        for (msg) |c| {
            self.putChar(c);
        }

        cursor.move();
    }

    fn writeln(self: *Self, msg: []const u8) void {
        for (msg) |c| {
            self.putChar(c);
        }

        self.putChar('\n');
    }

    fn scroll(self: *Self) void {
        const first_row: usize = VGA_WIDTH;

        // The last row as an array index
        const last_row: usize = VGA_SIZE - VGA_WIDTH;

        // The last row as per 0..VGA_HEIGHT
        const last_row_index: usize = VGA_HEIGHT - 1;

        // Copy the second row..last row (2nd param) to the first row..penultimate_row (1st param)
        std.mem.copy(ScreenChar, self.buffer[0..last_row], self.buffer[first_row..VGA_SIZE]);

        //cursor.pos = 0;

        //self.writeRowAbsolute(' ', last_row_index);

        // Reset the row to the last row (to prevent out of bounds);
        //self.row = last_row_index;
        //self.row = cursor.pos * VGA_HEIGHT;
        //cursor.pos *= VGA_HEIGHT;
        cursor.pos -= VGA_WIDTH;

        cursor.move();
    }

    fn clear(self: *Self, colour_code: ?ColourCode) void {
        std.mem.set(ScreenChar, self.buffer, ScreenChar.init(' ', colour_code orelse self.current_colour));

        cursor.pos = 0;

        cursor.move();

        //self.row = 0;

        //self.column = 0;
    }

    fn writeRowAbsolute(self: *Self, screen_char: u8, row_write: usize) void {
        const row_start: usize = row_write * VGA_WIDTH;

        const row_end: usize = row_start + VGA_WIDTH;

        // Copy from the start of the row index to the end of the row
        std.mem.set(ScreenChar, self.buffer[row_start..row_end], self.screenChar(screen_char));

        cursor.returnLine();

        //self.column = 0;

        //self.row = row_write + 1;
    }

    fn writeRow(self: *Self, screen_char: u8) void {
        self.writeRowAbsolute(screen_char, cursor.row()); 
    }

    fn screenChar(self: *Self, char: u8) ScreenChar {
        return ScreenChar.init(char, self.current_colour);
    }

    fn terminalWriter(self: *Self, msg: []const u8) Error!usize {
        self.write(msg);

        //cursor.pos += VGA_WIDTH - (cursor.column() + 1);
        //cursor.returnLine();

        //cursor.move();

        return msg.len;
    }

    fn writer(self: *Self) std.io.Writer(*Self, Error, terminalWriter) {
        return TerminalWriter{ .context = self };
    }

    fn log(self: *Self, msg: []const u8) void {
        self.writer().writeAll(msg) catch |e| switch (e) {};

        cursor.returnLine();
    }
};

export fn _start() callconv(.Naked) noreturn {
    @call(.{ .stack = stack_bytes_slice }, kmain, .{}); 

    while (true) {}
}

pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);

    var term = Terminal.init();

    const writer = term.writer();

    term.clear(ColourCode.init(.red, .red));

    term.writeRow('=');

    term.log("!!!KERNEL PANIC!!!");

    term.log(msg);

    term.writeRow('=');

    while (true) {}
}

fn kmain() void {
    var term = Terminal.init();

    //const out = Terminal.writer{ .context = &term };

    term.clear(null);

    var i: usize = 0;

    //term.writer().writeByteNTimes('a', VGA_WIDTH + 1) catch |e| switch (e) {};

    while (i < 200) : (i += 1) {
        term.writer().print("hello{}" ++ "\n", .{i}) catch |e| switch (e) {};
    }

    @panic("Something");
}

