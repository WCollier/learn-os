const std = @import("std");

const ColourCode = @import("Vga.zig").ColourCode;

const Terminal = @import("Terminal.zig").Terminal;

const Serial = @import("Serial.zig").Serial;

const Log = @import("Log.zig");

const Gdt = @import("Gdt.zig");

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

export var multiboot align(4) linksection(".multiboot") = MultiBoot{
    .magic = MAGIC,
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};

export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

const stack_bytes_slice = stack_bytes[0..];

export fn _start() callconv(.Naked) noreturn {
    @call(.{ .stack = stack_bytes_slice }, kmain, .{});

    while (true) {}
}

pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);

    Terminal.clear(ColourCode.init(.red, .red));

    Terminal.writeRow('=');

    std.log.crit("!!!KERNEL PANIC!!!", .{});

    // Better way to do an empty line?
    if (msg.len > 0) {
        std.log.crit("\n{s}", .{msg});
    }

    // TODO: For after paging, heap allocation, etc
    //termWriter.print("{}", .{error_return_trace});

    Terminal.writeRow('=');

    while (true) {}
}

pub const log = Log.log;

fn kmain() void {
    Terminal.clear(null);

    Serial.init();

    std.log.info("Boot!", .{});

    Gdt.init();

    //@panic("Something");
}
