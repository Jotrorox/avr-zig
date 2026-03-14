const std = @import("std");

pub const Board = enum {
    uno,
    mega2560,
};

pub const Spec = struct {
    target_query: std.Target.Query,
    linker_script: []const u8,
};

pub fn resolveBoard(b: *std.Build) Board {
    const value = b.option([]const u8, "board", "Target board: uno or mega2560") orelse "uno";

    if (std.mem.eql(u8, value, "uno")) {
        return .uno;
    }

    if (std.mem.eql(u8, value, "mega2560")) {
        return .mega2560;
    }

    std.debug.panic("unsupported -Dboard={s}; use 'uno' or 'mega2560'", .{value});
}

pub fn spec(board: Board) Spec {
    return switch (board) {
        .uno => .{
            .target_query = .{
                .cpu_arch = .avr,
                .cpu_model = .{ .explicit = &std.Target.avr.cpu.atmega328p },
                .os_tag = .freestanding,
                .abi = .none,
            },
            .linker_script = "src/runtime/atmega328p.ld",
        },
        .mega2560 => .{
            .target_query = .{
                .cpu_arch = .avr,
                .cpu_model = .{ .explicit = &std.Target.avr.cpu.atmega2560 },
                .os_tag = .freestanding,
                .abi = .none,
            },
            .linker_script = "src/runtime/atmega2560.ld",
        },
    };
}

pub fn addBoardConfig(module: *std.Build.Module, b: *std.Build, board: Board) void {
    const options = b.addOptions();
    options.addOption([]const u8, "board_name", @tagName(board));
    module.addOptions("avr_zig_config", options);
}

pub fn defaultTty(_: Board) []const u8 {
    return "/dev/ttyACM0";
}

pub fn addUploadStep(
    b: *std.Build,
    board: Board,
    tty: []const u8,
    description: []const u8,
    bin_path: []const u8,
) void {
    const upload = b.step("upload", description);

    const avrdude = switch (board) {
        .uno => b.addSystemCommand(&.{
            "avrdude",
            "-carduino",
            "-patmega328p",
            "-D",
            "-P",
            tty,
            b.fmt("-Uflash:w:{s}:e", .{bin_path}),
        }),
        .mega2560 => b.addSystemCommand(&.{
            "avrdude",
            "-cwiring",
            "-patmega2560",
            "-b115200",
            "-D",
            "-P",
            tty,
            b.fmt("-Uflash:w:{s}:e", .{bin_path}),
        }),
    };

    avrdude.step.dependOn(b.getInstallStep());
    upload.dependOn(&avrdude.step);
}

pub fn addObjdumpStep(b: *std.Build, description: []const u8, bin_path: []const u8) void {
    const objdump = b.step("objdump", description);
    const avr_objdump = b.addSystemCommand(&.{
        "avr-objdump",
        "-dh",
        bin_path,
    });
    avr_objdump.step.dependOn(b.getInstallStep());
    objdump.dependOn(&avr_objdump.step);
}

pub fn addMonitorStep(b: *std.Build, tty: []const u8) void {
    const monitor = b.step("monitor", "Open a serial monitor at 115200 baud");
    const screen = b.addSystemCommand(&.{
        "screen",
        tty,
        "115200",
    });
    monitor.dependOn(&screen.step);
}
