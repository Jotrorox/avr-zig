const std = @import("std");

const uno_query = std.Target.Query{
    .cpu_arch = .avr,
    .cpu_model = .{ .explicit = &std.Target.avr.cpu.atmega328p },
    .os_tag = .freestanding,
    .abi = .none,
};

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;

    _ = b.addModule("avr_zig", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "avr_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = b.resolveTargetQuery(uno_query),
            .optimize = optimize,
        }),
    });
    lib.bundle_compiler_rt = false;
    lib.bundle_ubsan_rt = false;

    b.installArtifact(lib);

    const check = b.step("check", "Build the AVR Zig library archive");
    check.dependOn(b.getInstallStep());
}
