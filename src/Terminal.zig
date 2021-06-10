const std = @import("std");

const Vga = @import("Vga.zig");

const Cursor = @import("Cursor.zig").Cursor;

const ColourCode = Vga.ColourCode;

const ScreenChar = Vga.ScreenChar;

const VGA_WIDTH = Vga.VGA_WIDTH;

const VGA_HEIGHT = Vga.VGA_HEIGHT;

const VGA_SIZE = Vga.VGA_SIZE;

pub const Terminal = struct {
    current_colour: ColourCode = ColourCode.init(.light_grey, .black),

    buffer: []ScreenChar,

    var cursor: Cursor = Cursor.init();

    const Self = @This();

    const Error = error{};

    pub const Writer = std.io.Writer(*Self, Error, terminalWriter); 

    pub fn init() Terminal {
        return Terminal {
            .buffer = @intToPtr([*]volatile ScreenChar, 0xB8000)[0..VGA_SIZE],
        };
    }

    fn putCharAt(self: *Self, screen_char: u8, x: usize, y: usize) void {
        if (screen_char == '\n') {
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

        self.putCharAt(screen_char, cursor.column(), cursor.row());

        if (cursor.column() == VGA_WIDTH) {
            cursor.returnLine();
        }
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

        cursor.pos -= VGA_WIDTH;

        cursor.move();
    }

    pub fn clear(self: *Self, colour_code: ?ColourCode) void {
        std.mem.set(ScreenChar, self.buffer, ScreenChar.init(' ', colour_code orelse self.current_colour));

        cursor.pos = 0;

        cursor.move();
    }

    fn writeRowAbsolute(self: *Self, screen_char: u8, row_write: usize) void {
        const row_start: usize = row_write * VGA_WIDTH;

        const row_end: usize = row_start + VGA_WIDTH;

        // Copy from the start of the row index to the end of the row
        std.mem.set(ScreenChar, self.buffer[row_start..row_end], self.screenChar(screen_char));

        cursor.returnLine();
    }

    pub fn writeRow(self: *Self, screen_char: u8) void {
        self.writeRowAbsolute(screen_char, cursor.row()); 
    }

    fn screenChar(self: *Self, char: u8) ScreenChar {
        return ScreenChar.init(char, self.current_colour);
    }

    fn terminalWriter(self: *Self, msg: []const u8) Error!usize {
        self.write(msg);

        return msg.len;
    }

    pub fn writer(self: *Self) std.io.Writer(*Self, Error, terminalWriter) {
        return Writer{ .context = self };
    }

    pub fn log(self: *Self, msg: []const u8) void {
        self.writer().writeAll(msg) catch |e| switch (e) {};

        cursor.returnLine();
    }

    pub fn print(self: *Self, comptime msg: []const u8, args: anytype) void {
        self.writer().print(msg, args) catch |e| switch (e) {};
    }
};
