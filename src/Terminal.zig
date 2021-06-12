const std = @import("std");

const Vga = @import("Vga.zig");

const Cursor = @import("Cursor.zig").Cursor;

const ColourCode = Vga.ColourCode;

const ScreenChar = Vga.ScreenChar;

const VGA_WIDTH = Vga.VGA_WIDTH;

const VGA_HEIGHT = Vga.VGA_HEIGHT;

const VGA_SIZE = Vga.VGA_SIZE;

fn TerminalWriter() type {
    return struct {
        const Error = error{};

        const Writer = std.io.Writer(*Self, Error, write); 

        const Self = @This();

        fn write(self: *Self, bytes: []const u8) Error!usize {
            Terminal.write(bytes);

            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn log(self: *Self, msg: []const u8) void {
            self.writer().writeAll(msg) catch |e| switch (e) {};

            Terminal.returnLine();
        }

        pub fn print(self: *Self, comptime msg: []const u8, args: anytype) void {
            self.writer().print(msg, args) catch |e| switch (e) {};
        }
    };
}

pub fn terminalWriter() TerminalWriter() {
    return .{};
}

pub const Terminal = struct {
    const buffer = @intToPtr([*]volatile ScreenChar, 0xB8000);

    var cursor: Cursor = Cursor.init();

    var current_colour: ColourCode = ColourCode.init(.light_grey, .black);

    fn putCharAt(screen_char: u8, x: usize, y: usize) void {
        if (screen_char == '\n') {
            cursor.returnLine();

            return;
        }

        const index = y * VGA_WIDTH + x;

        buffer[index].char = screen_char;

        buffer[index].colour_code = current_colour;

        cursor.pos += 1;
    }

    fn putChar(screen_char: u8) void {
        if (cursor.row() >= VGA_HEIGHT - 1) {
            scroll();
        }

        putCharAt(screen_char, cursor.column(), cursor.row());

        if (cursor.column() == VGA_WIDTH) {
            cursor.returnLine();
        }
    }

    fn write(msg: []const u8) void {
        for (msg) |c| {
            putChar(c);
        }

        cursor.move();
    }

    fn writeln(msg: []const u8) void {
        for (msg) |c| {
            putChar(c);
        }

        putChar('\n');
    }

    fn scroll() void {
        const first_row: usize = VGA_WIDTH;

        // The last row as an array index
        const last_row: usize = VGA_SIZE - VGA_WIDTH;

        // The last row as per 0..VGA_HEIGHT
        const last_row_index: usize = VGA_HEIGHT - 1;

        const buffer_array = bufferAsSlice();
        
        // Copy the second row..last row (2nd param) to the first row..last_row (1st param)
        std.mem.copy(ScreenChar, buffer_array[0..last_row], buffer_array[first_row..VGA_SIZE]);

        cursor.pos -= VGA_WIDTH;

        cursor.move();
    }

    pub fn clear(colour_code: ?ColourCode) void {
        std.mem.set(ScreenChar, buffer[0..VGA_SIZE], ScreenChar.init(' ', colour_code orelse current_colour));

        cursor.pos = 0;

        cursor.move();
    }

    fn writeRowAbsolute(screen_char: u8, row_write: usize) void {
        const row_start: usize = row_write * VGA_WIDTH;

        const row_end: usize = row_start + VGA_WIDTH;

        // Copy from the start of the row index to the end of the row
        std.mem.set(ScreenChar, bufferAsSlice()[row_start..row_end], screenChar(screen_char));

        cursor.returnLine();
    }

    fn returnLine() void {
        cursor.returnLine();
    }

    pub fn writeRow(screen_char: u8) void {
        writeRowAbsolute(screen_char, cursor.row()); 
    }

    fn screenChar(char: u8) ScreenChar {
        return ScreenChar.init(char, current_colour);
    }

    fn bufferAsSlice() []ScreenChar {
        return buffer[0..VGA_SIZE];
    }
};
