---
title: Board support
description: Board definitions, pin mappings, and build options for Uno, Nano, and Mega 2560.
sidebar:
  order: 1
---

AVR-Zig supports three Arduino-compatible boards. The board selection determines which pins, peripherals, and upload parameters are available at compile time.

```zig
const avr = @import("avr_zig");
const Board = avr.Board;
const current_board = avr.current_board;
```

## Board selection

Set the board with the `-Dboard` build option. If omitted, it defaults to `uno`.

```sh
zig build -Dboard=uno        # Arduino Uno (default)
zig build -Dboard=nano       # Arduino Nano
zig build -Dboard=mega2560   # Arduino Mega 2560
```

The selected board is available at comptime:

```zig
const avr = @import("avr_zig");

if (avr.current_board == .mega2560) {
    // Mega-specific code
}
```

## Types

### `Board`

```zig
pub const Board = enum {
    uno,
    nano,
    mega2560,
};
```

### `current_board`

```zig
pub const current_board: Board
```

The board selected at build time. This is a comptime constant resolved from the `-Dboard` option.

## Boards

### Arduino Uno

| Property | Value |
|---|---|
| MCU | ATmega328P |
| Clock | 16 MHz |
| Digital pins | `D0`--`D13`, `A0`--`A5` (20 total) |
| Analog inputs | `A0`--`A5` (6 channels) |
| PWM pins | `D3`, `D9`, `D10`, `D11` |
| Servo pins | `D9` (Timer1 A), `D10` (Timer1 B) |
| SPI pins | SS=`D10`, MOSI=`D11`, MISO=`D12`, SCK=`D13` |
| I2C pins | SDA=`A4`, SCL=`A5` |
| Default TTY | `/dev/ttyACM0` |

### Arduino Nano

| Property | Value |
|---|---|
| MCU | ATmega328P |
| Clock | 16 MHz |
| Digital pins | `D0`--`D13`, `A0`--`A5` (20 total) |
| Analog inputs | `A0`--`A7` (8 channels) |
| PWM pins | `D3`, `D9`, `D10`, `D11` |
| Servo pins | `D9` (Timer1 A), `D10` (Timer1 B) |
| SPI pins | SS=`D10`, MOSI=`D11`, MISO=`D12`, SCK=`D13` |
| I2C pins | SDA=`A4`, SCL=`A5` |
| Default TTY | `/dev/ttyUSB0` |

:::note
The Nano has two additional analog-only inputs (`A6`, `A7`) that cannot be used as digital GPIO. These pins return `null` from `analogDigitalPin`.
:::

### Arduino Mega 2560

| Property | Value |
|---|---|
| MCU | ATmega2560 |
| Clock | 16 MHz |
| Digital pins | `D0`--`D53`, `A0`--`A15` (70 total) |
| Analog inputs | `A0`--`A15` (16 channels) |
| PWM pins | `D2`, `D3`, `D5`, `D6`, `D7`, `D8`, `D9`, `D10`, `D11`, `D12`, `D13`, `D44`, `D45`, `D46` |
| Servo pins | `D11` (Timer1 A), `D12` (Timer1 B) |
| SPI pins | SS=`D53`, MOSI=`D51`, MISO=`D50`, SCK=`D52` |
| I2C pins | SDA=`D20`, SCL=`D21` |
| Default TTY | `/dev/ttyACM0` |

## Timer allocation

Different peripherals share hardware timers. Be aware of these constraints:

| Timer | Used by | Notes |
|---|---|---|
| Timer0 | [`time`](/reference/hal/time/) | Reserved after `time.init()`. PWM on Timer0 pins (`D5`/`D6` on Uno/Nano, `D4` on Mega) is blocked. |
| Timer1 | [`servo`](/reference/actuator/servo/), [`hc_sr04`](/reference/sensor/hc-sr04/), [`pwm`](/reference/hal/pwm/) | Servo takes exclusive ownership. HC-SR04 borrows temporarily and restores state. |
| Timer2+ | [`pwm`](/reference/hal/pwm/) | Available for PWM output on supported pins. |

## Build options

### `-Dboard`

Selects the target board. Accepted values: `uno`, `nano`, `mega2560`. Defaults to `uno`.

### `-Dtty`

Overrides the serial device path used for uploading and the serial monitor. Defaults to `/dev/ttyACM0` (Uno, Mega) or `/dev/ttyUSB0` (Nano).

```sh
zig build upload -Dtty=/dev/ttyUSB1
```

### `-Dupload_profile`

Selects the upload profile. Accepted values: `default`, `nano_old_bootloader`. Only relevant for the Nano board.

```sh
zig build upload -Dboard=nano -Dupload_profile=nano_old_bootloader
```

The `nano_old_bootloader` profile uses 57600 baud instead of 115200 for older Nano clones with the ATmega328P old bootloader.

### `-Doptimize`

Standard Zig optimization mode for firmware builds. Defaults to `ReleaseSafe`.

## Build steps

When building firmware with `-Dapp_root`, the build system registers these additional steps:

### `zig build upload`

Flashes the compiled firmware to the board using `avrdude`. The programmer and baud rate are selected automatically based on the board:

| Board | Programmer | Baud |
|---|---|---|
| Uno | `-carduino` | (default) |
| Nano | `-carduino` | 115200 (or 57600 with old bootloader profile) |
| Mega 2560 | `-cwiring` | 115200 |

### `zig build objdump`

Runs `avr-objdump -dh` on the compiled ELF binary to display disassembly and section headers.

### `zig build monitor`

Opens a serial monitor using `screen` at 115200 baud on the configured TTY device.

## Example

```zig
const avr = @import("avr_zig");
const gpio = avr.gpio;
const uart = avr.uart;

pub fn main() void {
    uart.init();

    // Board-aware pin selection
    const led_pin: gpio.Pin = switch (avr.current_board) {
        .uno, .nano => .D13,
        .mega2560 => .D13,
    };

    gpio.init(led_pin, .out);
    gpio.write(led_pin, true);

    uart.write("Board ready\r\n");
}
```
