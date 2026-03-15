---
title: Your First Project
description: Set up a new AVR-Zig project from scratch and blink an LED on your Arduino.
sidebar:
  order: 1
---

This guide walks you through creating a brand-new Zig project that targets an Arduino board. By the end, the onboard LED will be blinking -- no C/C++ toolchain required.

## What you'll need

**Software:**

- [Zig](https://ziglang.org/download/) 0.15.2 or newer
- [avrdude](https://github.com/avrdudes/avrdude) (for flashing firmware to the board)

**Hardware:**

- An Arduino Uno, classic Nano, or Mega 2560
- A USB cable to connect the board to your computer

:::tip
On Linux, `avrdude` is usually available through your package manager (`apt install avrdude`, `pacman -S avrdude`, etc.). On macOS, `brew install avrdude` works. On Windows, the [avrdude releases page](https://github.com/avrdudes/avrdude/releases) provides prebuilt binaries.
:::

## Step 1 -- Create the project

Make a new directory for your project and create the three files every AVR-Zig project needs:

```sh
mkdir my-blink
cd my-blink
mkdir src
```

Your project structure will look like this:

```
my-blink/
├── build.zig
├── build.zig.zon
└── src/
    └── main.zig
```

## Step 2 -- Declare the dependency

Create `build.zig.zon` in the project root. This file tells Zig where to find the `avr_zig` package:

```zig
.{
    .name = .my_blink,
    .version = "0.1.0",
    .fingerprint = 0x0000000000000000,
    .minimum_zig_version = "0.15.2",
    .dependencies = .{
        .avr_zig = .{
            .url = "https://github.com/arcembed/avr-zig/archive/refs/heads/main.tar.gz",
            // After the first build attempt, Zig will tell you the correct
            // hash to put here. Replace the placeholder below with it.
            .hash = "REPLACE_WITH_HASH_FROM_ZIG_OUTPUT",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

:::note[Getting the hash]
The first time you run `zig build`, it will fail with a message containing the correct `.hash` value. Copy that hash string back into your `build.zig.zon` and build again. This is normal -- Zig uses it to verify the downloaded package.
:::

## Step 3 -- Create the build file

Create `build.zig` in the project root. This small wrapper hands your application off to `avr_zig`'s firmware build system:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Board selection: pass -Dboard=uno, -Dboard=nano, or -Dboard=mega2560
    const board = b.option(
        []const u8, "board", "Target board",
    ) orelse "uno";

    // Serial port for uploading and monitoring
    const tty = b.option([]const u8, "tty", "Serial device");

    // Some classic Nanos need -Dupload_profile=nano_old_bootloader
    const upload_profile = b.option(
        []const u8, "upload_profile", "Upload profile",
    ) orelse "default";

    const optimize = b.option(
        std.builtin.OptimizeMode, "optimize", "Optimization mode",
    ) orelse .ReleaseSafe;

    // Create the avr_zig dependency, passing in our app's source file
    const avr = if (tty) |serial_device|
        b.dependency("avr_zig", .{
            .app_root = b.path("src/main.zig"),
            .app_name = "my_blink",
            .board = board,
            .tty = serial_device,
            .upload_profile = upload_profile,
            .optimize = optimize,
        })
    else
        b.dependency("avr_zig", .{
            .app_root = b.path("src/main.zig"),
            .app_name = "my_blink",
            .board = board,
            .upload_profile = upload_profile,
            .optimize = optimize,
        });

    // Install the compiled firmware ELF
    b.installArtifact(avr.artifact("my_blink"));

    // Re-export the upload, objdump, and monitor steps from avr_zig
    for (&[_][]const u8{ "upload", "objdump", "monitor" }) |step_name| {
        const child = avr.builder.top_level_steps.get(step_name) orelse
            @panic("missing avr_zig step");
        const step = b.step(step_name, child.description);
        step.dependOn(&child.step);
    }
}
```

Every AVR-Zig project uses this same wrapper pattern. The key parts are:

- **`app_root`** -- points to your application source file
- **`app_name`** -- the name of the output firmware binary
- **`board`** -- selects which Arduino board to target (defaults to `"uno"`)
- The last `for` loop re-exports three useful build steps: `upload` (flash the board), `objdump` (inspect the binary), and `monitor` (open a serial console)

:::tip
You can copy this `build.zig` into any new project and only change `app_name` and the `app_root` path. Everything else stays the same.
:::

## Step 4 -- Write the blink program

Create `src/main.zig`:

```zig
const avr = @import("avr_zig");
const gpio = avr.hal.gpio;
const time = avr.hal.time;

pub fn main() void {
    // Set pin D13 as an output. On all supported boards,
    // D13 is connected to the onboard LED.
    gpio.init(.D13, .out);

    while (true) {
        gpio.toggle(.D13); // Flip the LED state
        time.sleep(500);   // Wait 500 milliseconds
    }
}
```

Let's break this down:

- **`@import("avr_zig")`** brings in the AVR-Zig library. The `avr.hal.gpio` and `avr.hal.time` modules give you pin control and timing.
- **`gpio.init(.D13, .out)`** configures pin D13 as an output. The `.D13` and `.out` values are Zig *enums* -- named constants that the compiler checks at build time. If you misspell a pin name, the compiler catches it immediately.
- **`gpio.toggle(.D13)`** flips the pin between high and low. When the pin is high, the onboard LED lights up.
- **`time.sleep(500)`** pauses for 500 milliseconds. Behind the scenes, this uses Timer0 and puts the CPU into a low-power idle mode while waiting.
- The **`while (true)`** loop keeps the program running forever, which is standard for embedded firmware -- there's no operating system to return to.

:::note[No `main` arguments, no return value]
Unlike a desktop Zig program, AVR-Zig's `main` takes no arguments and returns `void`. There is no OS, no `stdout`, and no command-line arguments on a microcontroller.
:::

## Step 5 -- Build

Compile the firmware:

```sh
zig build -Dboard=uno
```

Replace `uno` with `nano` or `mega2560` if you're using a different board. The compiled ELF file appears in `zig-out/bin/`.

## Step 6 -- Flash the board

Connect your Arduino via USB, then:

```sh
zig build upload -Dboard=uno -Dtty=/dev/ttyACM0
```

This uses `avrdude` to write the firmware to the board. The LED on pin D13 should start blinking.

**Finding your serial port:**

| OS | Typical path |
|---|---|
| Linux (Uno/Mega) | `/dev/ttyACM0` |
| Linux (Nano) | `/dev/ttyUSB0` |
| macOS | `/dev/cu.usbmodem*` or `/dev/cu.usbserial*` |
| Windows | `COM3`, `COM4`, etc. |

:::tip
On Linux, you can run `ls /dev/tty*` before and after plugging in the board to see which device appears. On macOS, `ls /dev/cu.usb*` does the same.
:::

## Step 7 -- Monitor serial output

If your program sends serial data (this blink example doesn't, but later projects will), you can open a serial terminal:

```sh
zig build monitor -Dboard=uno -Dtty=/dev/ttyACM0
```

This opens `screen` at 115200 baud. Press `Ctrl+A` then `K` to exit.

## Targeting different boards

The same source code works across all three supported boards:

```sh
# Arduino Uno (ATmega328P)
zig build upload -Dboard=uno -Dtty=/dev/ttyACM0

# Classic Arduino Nano (ATmega328P, 16 MHz)
zig build upload -Dboard=nano -Dtty=/dev/ttyUSB0

# Arduino Mega 2560 (ATmega2560)
zig build upload -Dboard=mega2560 -Dtty=/dev/ttyACM0
```

The API stays identical. Pin names like `.D13`, `.A0`, etc. are resolved at compile time for each board.

## Troubleshooting

**`avrdude: command not found`**

Install avrdude through your system package manager. See the "What you'll need" section above.

**`avrdude: ser_open(): can't open device`**

- Check the `-Dtty` path -- plug the board in and find the correct device (see the table above).
- On Linux, you may need to add your user to the `dialout` or `uucp` group: `sudo usermod -aG dialout $USER` (log out and back in after).

**Classic Nano upload fails or times out**

Some older Nano clones use a different bootloader baud rate. Try:

```sh
zig build upload -Dboard=nano -Dtty=/dev/ttyUSB0 -Dupload_profile=nano_old_bootloader
```

**Build errors about missing hash**

This is expected on the first build. Zig will print the correct hash for the `avr_zig` package -- copy it into your `build.zig.zon` and build again.

## Next steps

Your LED is blinking -- now make it interactive. The [Digital I/O](/guides/digital-io/) guide shows you how to read buttons, drive external LEDs, and send debug messages over serial.
