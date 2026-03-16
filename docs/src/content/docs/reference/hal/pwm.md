---
title: PWM
description: Control LED brightness and motor speed with pulse-width modulation.
sidebar:
  order: 7
---

The PWM module generates 8-bit pulse-width modulation output on timer-capable pins.

```zig
const avr = @import("avr_zig");
const pwm = avr.pwm;
```

:::caution
Timer0 is reserved by the [Time](./time/) module for the system tick. Pins that use Timer0 (D5 and D6 on the Uno/Nano) are **not** available for PWM and will produce a compile error.
:::

## PWM-capable pins

| Board | Available pins |
|---|---|
| Uno / Nano | D3, D9, D10, D11 |
| Mega 2560 | D2, D3, D5, D6, D7, D8, D9, D10, D11, D12, D44, D45, D46 |

## Constants

### `max_duty`

```zig
pub const max_duty = 255;
```

The maximum duty cycle value (100% duty).

### `default_frequency_hz`

```zig
pub const default_frequency_hz = CPU_FREQ / 64 / 256;
```

The PWM output frequency. At 16 MHz with a prescaler of 64, this is approximately **976 Hz**.

## Functions

### `supports`

```zig
pub fn supports(comptime pin: gpio.Pin) bool
```

Returns `true` if the pin supports PWM output on the current board. This check excludes Timer0 pins.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `gpio.Pin` | The pin to check (comptime) |

### `init`

```zig
pub fn init(comptime pin: gpio.Pin) void
```

Initializes PWM output on a pin. Configures the underlying timer (if not already running), sets the pin as an output, and starts with a duty cycle of 0.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `gpio.Pin` | The pin to enable PWM on (comptime) |

**Compile errors:**

- `"pwm: selected pin uses Timer0, which is reserved by hal.time"` -- if the pin maps to Timer0
- `"pwm: unsupported pin for the selected board"` -- if the pin has no PWM channel

### `write`

```zig
pub fn write(comptime pin: gpio.Pin, duty: u8) void
```

Sets the PWM duty cycle on a pin that was previously initialized with `init`.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `gpio.Pin` | The pin (comptime) |
| `duty` | `u8` | Duty cycle: `0` (always low) to `255` (always high) |
