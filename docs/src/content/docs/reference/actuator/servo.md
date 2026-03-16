---
title: Servo
description: Control standard hobby servos using Timer1 PWM output.
sidebar:
  order: 1
---

The servo driver generates 50 Hz PWM signals on Timer1 output-compare pins to control standard hobby servos. It supports one or two simultaneous servo outputs depending on the board.

```zig
const avr = @import("avr_zig");
const servo = avr.drivers.actuator.servo;
```

## Constants

```zig
pub const refresh_hz: u16 = 50;
pub const min_pulse_us: u16 = 1000;
pub const center_pulse_us: u16 = 1500;
pub const max_pulse_us: u16 = 2000;
```

| Constant | Value | Description |
|---|---|---|
| `refresh_hz` | `50` | PWM refresh rate in Hz (20 ms period) |
| `min_pulse_us` | `1000` | Minimum pulse width in microseconds (0 degrees) |
| `center_pulse_us` | `1500` | Center pulse width in microseconds (90 degrees) |
| `max_pulse_us` | `2000` | Maximum pulse width in microseconds (180 degrees) |

## Servo-capable pins

The servo driver uses Timer1 output-compare channels. Only specific pins support servo output:

| Board | Channel A | Channel B |
|---|---|---|
| Uno | `D9` | `D10` |
| Nano | `D9` | `D10` |
| Mega 2560 | `D11` | `D12` |

You can attach up to two servos simultaneously (one per channel).

:::caution
The servo driver takes exclusive ownership of Timer1. While active, the [HC-SR04 ultrasonic driver](../sensor/hc-sr04/) cannot take measurements (it will return `Timer1Unavailable`). Timer1-based [PWM](../hal/pwm/) channels are also unavailable while the servo is active.
:::

## Functions

### `supports`

```zig
pub fn supports(comptime pin: gpio.Pin) bool
```

Returns whether the given pin supports servo output on the current board.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `gpio.Pin` | The pin to check (comptime) |

**Returns:** `bool` -- `true` if the pin is connected to a Timer1 output-compare channel.

### `isActive`

```zig
pub fn isActive() bool
```

Returns whether Timer1 is currently configured for servo output.

**Returns:** `bool` -- `true` if `init` has been called and `deinit` has not.

### `init`

```zig
pub fn init(comptime pin: gpio.Pin) void
```

Configures Timer1 for 50 Hz Fast PWM mode, sets the pin as output, enables the output-compare channel, and moves the servo to the center position (1500 us).

| Parameter | Type | Description |
|---|---|---|
| `pin` | `gpio.Pin` | The servo output pin (comptime) |

**Compile constraints:**

- The pin must be a servo-capable pin. Passing an unsupported pin produces a compile error: `"servo: unsupported pin for the selected board"`.

:::note
Calling `init` on a second servo pin reuses the already-running Timer1 configuration. Both channels share the same timer, so `deinit` stops both.
:::

### `deinit`

```zig
pub fn deinit() void
```

Stops Timer1 and disconnects both output-compare channels. After calling `deinit`, Timer1 is available for other uses (HC-SR04, PWM).

### `writeMicros`

```zig
pub fn writeMicros(comptime pin: gpio.Pin, pulse_us: u16) void
```

Sets the pulse width for the given servo channel. The value is clamped to the range `min_pulse_us`--`max_pulse_us` (1000--2000 us).

| Parameter | Type | Description |
|---|---|---|
| `pin` | `gpio.Pin` | The servo output pin (comptime) |
| `pulse_us` | `u16` | Desired pulse width in microseconds |

**Compile constraints:**

- The pin must be a servo-capable pin.

### `writeDegrees`

```zig
pub fn writeDegrees(comptime pin: gpio.Pin, degrees: u8) void
```

Sets the servo position by angle. The angle is clamped to 0--180 and linearly mapped to the pulse range (1000--2000 us).

| Parameter | Type | Description |
|---|---|---|
| `pin` | `gpio.Pin` | The servo output pin (comptime) |
| `degrees` | `u8` | Target angle (0--180) |

**Compile constraints:**

- The pin must be a servo-capable pin.

## Example

```zig
const avr = @import("avr_zig");
const time = avr.time;
const servo = avr.drivers.actuator.servo;

pub fn main() void {
    time.init();

    // Start servo on D9 (Uno/Nano) -- begins at center (90 degrees)
    servo.init(.D9);

    // Sweep from 0 to 180 degrees
    var angle: u8 = 0;
    while (angle <= 180) : (angle += 1) {
        servo.writeDegrees(.D9, angle);
        time.sleep(15);
    }

    // Set precise pulse width
    servo.writeMicros(.D9, 1200);
    time.sleep(1000);

    // Release Timer1
    servo.deinit();
}
```
