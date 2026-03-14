const std = @import("std");
const avr_board = @import("build_support/avr_board.zig");

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;
    const board = avr_board.resolveBoard(b);
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
