const std = @import("std");

const Terminal = @import("Terminal.zig").Terminal;

const ColourCode = @import("Vga.zig").ColourCode;

const builtin = std.builtin;

const fmt = std.fmt;

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

    term.clear(null);

    var i: usize = 0;

    while (i < 200) : (i += 1) {
        term.print("hello{}\n", .{i});
    }

    //@panic("Something");
}

