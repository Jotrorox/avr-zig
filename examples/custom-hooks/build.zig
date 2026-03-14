const std = @import("std");
const avr_board = @import("build_support.zig");

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;
    const board = avr_board.resolveBoard(b);
    const spec = avr_board.spec(board);
    const tty = b.option([]const u8, "tty", "Serial device for avrdude and screen") orelse avr_board.defaultTty(board);

    const avr_dep = b.dependency("avr_zig", .{ .board = @tagName(board) });
    const avr_mod = avr_dep.module("avr_zig");
    const target = b.resolveTargetQuery(spec.target_query);
    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "avr_zig", .module = avr_mod }},
    });

    const exe = b.addExecutable(.{
        .name = "custom-hooks",
        .root_module = b.createModule(.{
            .root_source_file = avr_dep.path("src/runtime/app_root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "avr_zig", .module = avr_mod },
                .{ .name = "app", .module = app_mod },
            },
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.bundle_ubsan_rt = false;
    exe.linker_script = avr_dep.path(spec.linker_script);

    b.installArtifact(exe);

    const bin_path = b.getInstallPath(.bin, exe.out_filename);
    avr_board.addUploadStep(b, board, tty, "Flash the custom hooks example with avrdude", bin_path);
    avr_board.addObjdumpStep(b, "Disassemble the custom hooks firmware", bin_path);
    avr_board.addMonitorStep(b, tty);
}
