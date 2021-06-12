const std = @import("std");

const termWriter = @import("Terminal.zig").terminalWriter;

const serialWriter = @import("Serial.zig").serialWriter;

pub fn log(comptime level: std.log.Level, comptime scope: @TypeOf(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    // TODO: Add back in when I understand scopes
    //const scope_prefix = "(" ++ switch (scope) {
    //.default => @tagName(scope),
    //else => if (@enumToInt(level) <= @enumToInt(std.log.Level.crit))
    //@tagName(scope)
    //else
    //return,
    //} ++ "): ";

    const prefix = "[" ++ @tagName(level) ++ "] ";

    termWriter().print(prefix ++ format ++ "\n", args);

    serialWriter().print(prefix ++ format ++ "\n", args);
}
