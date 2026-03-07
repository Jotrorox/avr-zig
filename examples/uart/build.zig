const std = @import("std");

const uno_query = std.Target.Query{
    .cpu_arch = .avr,
    .cpu_model = .{ .explicit = &std.Target.avr.cpu.atmega328p },
    .os_tag = .freestanding,
    .abi = .none,
};

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;
    const tty = b.option([]const u8, "tty", "Serial device for avrdude and screen") orelse "/dev/ttyACM0";

    const avr_dep = b.dependency("avr_zig", .{});
    const avr_mod = avr_dep.module("avr_zig");

    const exe = b.addExecutable(.{
        .name = "uart",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(uno_query),
            .optimize = optimize,
            .imports = &.{.{ .name = "avr_zig", .module = avr_mod }},
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.bundle_ubsan_rt = false;
    exe.linker_script = avr_dep.path("src/runtime/atmega328p.ld");

    b.installArtifact(exe);

    const bin_path = b.getInstallPath(.bin, exe.out_filename);
    addUploadStep(b, tty, bin_path);
    addObjdumpStep(b, bin_path);
    addMonitorStep(b, tty);
}

fn addUploadStep(b: *std.Build, tty: []const u8, bin_path: []const u8) void {
    const upload = b.step("upload", "Flash the UART example with avrdude");
    const avrdude = b.addSystemCommand(&.{
        "avrdude",
        "-carduino",
        "-patmega328p",
        "-D",
        "-P",
        tty,
        b.fmt("-Uflash:w:{s}:e", .{bin_path}),
    });
    avrdude.step.dependOn(b.getInstallStep());
    upload.dependOn(&avrdude.step);
}

fn addObjdumpStep(b: *std.Build, bin_path: []const u8) void {
    const objdump = b.step("objdump", "Disassemble the UART firmware");
    const avr_objdump = b.addSystemCommand(&.{
        "avr-objdump",
        "-dh",
        bin_path,
    });
    avr_objdump.step.dependOn(b.getInstallStep());
    objdump.dependOn(&avr_objdump.step);
}

fn addMonitorStep(b: *std.Build, tty: []const u8) void {
    const monitor = b.step("monitor", "Open a serial monitor at 115200 baud");
    const screen = b.addSystemCommand(&.{
        "screen",
        tty,
        "115200",
    });
    monitor.dependOn(&screen.step);
}
