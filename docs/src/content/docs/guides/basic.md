---
title: Your First Project 
description: Get started with AVR-Zig by making your first basic project.
---

Create a small Zig application that depends on `avr_zig`, then let the package build the AVR firmware for you.

## Minimal build file

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const board = b.option([]const u8, "board", "Target board") orelse "uno";
    const tty = b.option([]const u8, "tty", "Serial device");
    const upload_profile = b.option([]const u8, "upload_profile", "Upload profile") orelse "default";
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization mode") orelse .ReleaseSafe;

    const avr = if (tty) |serial_device|
        b.dependency("avr_zig", .{
            .app_root = b.path("src/main.zig"),
            .app_name = "my_app",
            .board = board,
            .tty = serial_device,
            .upload_profile = upload_profile,
            .optimize = optimize,
        })
    else
        b.dependency("avr_zig", .{
            .app_root = b.path("src/main.zig"),
            .app_name = "my_app",
            .board = board,
            .upload_profile = upload_profile,
            .optimize = optimize,
        });

    b.installArtifact(avr.artifact("my_app"));

    for (&[_][]const u8{ "upload", "objdump", "monitor" }) |step_name| {
        const child = avr.builder.top_level_steps.get(step_name) orelse @panic("missing avr_zig step");
        const step = b.step(step_name, child.description);
        step.dependOn(&child.step);
    }
}
```

## Minimal application

```zig
const avr = @import("avr_zig");
const gpio = avr.hal.gpio;
const time = avr.hal.time;

pub fn main() void {
    gpio.init(.D13, .out);

    while (true) {
        gpio.toggle(.D13);
        time.sleep(500);
    }
}
```

## Build and flash

```sh
zig build -Dboard=uno
zig build upload -Dboard=uno -Dtty=/dev/ttyACM0
zig build monitor -Dboard=uno -Dtty=/dev/ttyACM0
```

Use `-Dboard=nano` for a classic Nano or `-Dboard=mega2560` for a Mega 2560. Classic Nano uploads can also use `-Dupload_profile=nano_old_bootloader` when needed.

If you want a complete reference project, start from one of the examples in `examples/` and keep the same tiny wrapper build pattern.

This hasn't been written yet. Sorry...
