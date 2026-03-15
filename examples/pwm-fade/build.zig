const std = @import("std");

pub fn build(b: *std.Build) void {
    const board = b.option([]const u8, "board", "Target board") orelse "uno";
    const tty = b.option([]const u8, "tty", "Serial device");
    const upload_profile = b.option([]const u8, "upload_profile", "Upload profile") orelse "default";
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization mode") orelse .ReleaseSafe;

    const avr = if (tty) |serial_device|
        b.dependency("avr_zig", .{
            .app_root = b.path("src/main.zig"),
            .app_name = "pwm-fade",
            .board = board,
            .tty = serial_device,
            .upload_profile = upload_profile,
            .optimize = optimize,
        })
    else
        b.dependency("avr_zig", .{
            .app_root = b.path("src/main.zig"),
            .app_name = "pwm-fade",
            .board = board,
            .upload_profile = upload_profile,
            .optimize = optimize,
        });

    b.installArtifact(avr.artifact("pwm-fade"));

    for (&[_][]const u8{ "upload", "objdump", "monitor" }) |step_name| {
        const child = avr.builder.top_level_steps.get(step_name) orelse @panic("missing avr_zig step");
        const step = b.step(step_name, child.description);
        step.dependOn(&child.step);
    }
}
