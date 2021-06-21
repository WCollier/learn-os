const std = @import("std");
const builtin = std.builtin;

pub fn build(b: *std.build.Builder) !void {
    const target = std.zig.CrossTarget{
        .os_tag = .freestanding,
        .cpu_arch = .i386,
        .cpu_model = .{
            .explicit = &std.Target.x86.cpu._i386,
        },
    };

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("learn-os", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setLinkerScriptPath("linker.ld");
    exe.setTarget(target);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const qemu = b.step("qemu", "Run qemu");

    const run_gdb = b.option(bool, "gdb", "Run qemu with gdb") orelse false;

    var run_qemu_args = std.ArrayList([] const u8).init(b.allocator);

    try run_qemu_args.appendSlice(&[_][]const u8 {
        "qemu-system-i386",
        "-kernel",
        "zig-out/bin/learn-os",
        "-serial",
        "stdio",
        "-no-reboot",
    });

    if (run_gdb) {
        try run_qemu_args.appendSlice(&[_][]const u8{ "-S", "-s" });
    }

    const run_qemu = b.addSystemCommand(run_qemu_args.items);

    qemu.dependOn(&run_qemu.step);

    run_qemu.step.dependOn(&exe.step);

    b.default_step.dependOn(&run_qemu.step);
}
