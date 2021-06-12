const std = @import("std");

const x86 = @import("x86.zig");

const Com1 = 0x3F8;

// Using an ideal makes is annoying with having to use @enumToInt
const Reg0: u16 = Com1;

const Reg1: u16 = Com1 + 1;

const Reg2: u16 = Com1 + 2;

const Reg3: u16 = Com1 + 3;

const Reg4: u16 = Com1 + 4;

const Reg5: u16 = Com1 + 5;

fn SerialWriter() type {
    return struct {
        const Error = error{};

        const Writer = std.io.Writer(*Self, Error, write);

        const Self = @This();

        fn write(self: *Self, msg: []const u8) Error!usize {
            Serial.write(msg);

            return msg.len;
        }

        pub fn writer(self: *Self) std.io.Writer(*Self, Error, write) {
            return Writer{ .context = self };
        }

        pub fn log(self: *Self, msg: []const u8) void {
            self.writer().writeAll(msg) catch |e| switch (e) {};
        }

        pub fn print(self: *Self, comptime msg: []const u8, args: anytype) void {
            self.writer().print(msg, args) catch |e| switch (e) {};
        }
    };
}

// TODO: Add SerialReader

pub fn serialWriter() SerialWriter() {
    return .{};
}

pub const Serial = struct {
    const Error = error{};

    const Self = @This();

    // TODO: Add error
    pub const Writer = std.io.Writer(*Self, Error, serialWriter);

    pub fn init() void {
        x86.outb(Reg1, 0x00);

        x86.outb(Reg3, 0x80);

        x86.outb(Reg0, 0x03);

        x86.outb(Reg1, 0x00);

        x86.outb(Reg3, 0x03);

        x86.outb(Reg2, 0xC7);

        x86.outb(Reg4, 0x0B);

        x86.outb(Reg4, 0x1E);

        x86.outb(Reg0, 0xAE);

        // TODO: Error handling here
        if (x86.inb(Reg0) != 0xAE) {}

        x86.outb(Reg4, 0x0F);
    }

    pub fn receive() u8 {
        // While not received
        while ((x86.inb(Reg5) & 1) == 0) {}

        return x86.inb(Com1);
    }

    pub fn writeChar(send: u8) void {
        // While is transit empty
        while ((x86.inb(Reg5) & 0x20) == 0) {}

        x86.outb(Com1, send);
    }

    pub fn write(msg: []const u8) void {
        for (msg) |char| {
            writeChar(char);
        }
    }
};
