const std = @import("std");
const avr_board = @import("avr_board.zig");

pub const FirmwareOptions = struct {
    app_root: std.Build.LazyPath,
    app_name: []const u8,
    board: avr_board.Board,
    tty: []const u8,
    upload_profile: avr_board.UploadProfile,
    optimize: std.builtin.OptimizeMode,
};

pub fn addFirmware(b: *std.Build, options: FirmwareOptions) void {
    const spec = avr_board.spec(options.board);

    const avr_mod = b.addModule("avr_zig", .{
        .root_source_file = b.path("src/root.zig"),
    });
    avr_board.addBoardConfig(avr_mod, b, options.board);

    const target = b.resolveTargetQuery(spec.target_query);
    const app_mod = b.createModule(.{
        .root_source_file = options.app_root,
        .target = target,
        .optimize = options.optimize,
        .imports = &.{.{ .name = "avr_zig", .module = avr_mod }},
    });

    const exe = b.addExecutable(.{
        .name = options.app_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/runtime/app_root.zig"),
            .target = target,
            .optimize = options.optimize,
            .imports = &.{
                .{ .name = "avr_zig", .module = avr_mod },
                .{ .name = "app", .module = app_mod },
            },
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.bundle_ubsan_rt = false;
    exe.linker_script = b.path(spec.linker_script);

    b.installArtifact(exe);

    const bin_path = b.getInstallPath(.bin, exe.out_filename);
    avr_board.addUploadStep(b, options.board, options.upload_profile, options.tty, "Flash the AVR firmware with avrdude", bin_path);
    avr_board.addObjdumpStep(b, "Disassemble the AVR firmware", bin_path);
    avr_board.addMonitorStep(b, options.tty);
}
