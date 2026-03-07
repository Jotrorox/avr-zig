const std = @import("std");
const Builder = std.Build;

pub fn build(b: *std.Build) !void {
    const uno = std.Target.Query{
        .cpu_arch = .avr,
        .cpu_model = .{ .explicit = &std.Target.avr.cpu.atmega328p },
        .os_tag = .freestanding,
        .abi = .none,
    };

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/start.zig"),
        .target = b.resolveTargetQuery(uno),
        .optimize = .ReleaseSafe,
    });

    const exe = b.addExecutable(.{
        .name = "avr-arduino-zig",
        .root_module = root_module,
    });

    exe.bundle_compiler_rt = false;
    exe.bundle_ubsan_rt = false;

    exe.linker_script = b.path("src/linker.ld");

    b.installArtifact(exe);

    const tty = b.option(
        []const u8,
        "tty",
        "Specify the port to which the Arduino is connected (defaults to /dev/ttyACM0)",
    ) orelse "/dev/ttyACM0";

    const bin_path = b.getInstallPath(.{ .custom = exe.installed_path orelse "./bin" }, exe.out_filename);

    const flash_command = blk: {
        var tmp: std.ArrayListUnmanaged(u8) = .{};
        defer tmp.deinit(b.allocator);
        try tmp.appendSlice(b.allocator, "-Uflash:w:");
        try tmp.appendSlice(b.allocator, bin_path);
        try tmp.appendSlice(b.allocator, ":e");
        break :blk try tmp.toOwnedSlice(b.allocator);
    };

    const upload = b.step("upload", "Upload the code to an Arduino device using avrdude");
    const avrdude = b.addSystemCommand(&.{
        "avrdude",
        "-carduino",
        "-patmega328p",
        "-D",
        "-P",
        tty,
        flash_command,
    });
    upload.dependOn(&avrdude.step);
    avrdude.step.dependOn(&exe.step);

    const objdump = b.step("objdump", "Show dissassembly of the code using avr-objdump");
    const avr_objdump = b.addSystemCommand(&.{
        "avr-objdump",
        "-dh",
        bin_path,
    });
    objdump.dependOn(&avr_objdump.step);
    avr_objdump.step.dependOn(&exe.step);

    const monitor = b.step("monitor", "Opens a monitor to the serial output");
    const screen = b.addSystemCommand(&.{
        "screen",
        tty,
        "115200",
    });
    monitor.dependOn(&screen.step);

    b.default_step.dependOn(&exe.step);
}
