const std = @import("std");
const avr_board = @import("build_support/avr_board.zig");
const avr_firmware = @import("build_support/avr_firmware.zig");

pub fn build(b: *std.Build) void {
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization mode for firmware builds") orelse .ReleaseSafe;
    const board = avr_board.resolveBoard(b);
    const app_root = b.option(std.Build.LazyPath, "app_root", "Path to the application root source file");

    if (app_root) |root| {
        const app_name = b.option([]const u8, "app_name", "Name of the AVR firmware artifact") orelse
            std.debug.panic("missing required -Dapp_name when -Dapp_root is provided", .{});
        const tty = b.option([]const u8, "tty", "Serial device for avrdude and screen") orelse avr_board.defaultTty(board);
        const upload_profile = avr_board.resolveUploadProfile(b);

        avr_firmware.addFirmware(b, .{
            .app_root = root,
            .app_name = app_name,
            .board = board,
            .tty = tty,
            .upload_profile = upload_profile,
            .optimize = optimize,
        });
        return;
    }

    const spec = avr_board.spec(board);

    const avr_mod = b.addModule("avr_zig", .{
        .root_source_file = b.path("src/root.zig"),
    });
    avr_board.addBoardConfig(avr_mod, b, board);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.resolveTargetQuery(spec.target_query),
        .optimize = optimize,
    });
    avr_board.addBoardConfig(lib_mod, b, board);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "avr_zig",
        .root_module = lib_mod,
    });
    lib.bundle_compiler_rt = false;
    lib.bundle_ubsan_rt = false;

    b.installArtifact(lib);

    const check = b.step("check", "Build the AVR Zig library archive");
    check.dependOn(b.getInstallStep());
}
