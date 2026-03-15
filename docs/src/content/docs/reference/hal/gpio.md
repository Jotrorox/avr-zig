---
title: GPIO
description: Configure, read, and write digital I/O pins.
sidebar:
  order: 1
---

The GPIO module controls digital input and output pins on the microcontroller.

```zig
const avr = @import("avr_zig");
const gpio = avr.gpio;
```

## Types

### `Pin`

An enum of all digital pins available on the selected board. Pin values are resolved at compile time based on your `-Dboard` setting.

| Board | Pins |
|---|---|
| Uno | `D0`..`D13`, `A0`..`A5` |
| Nano | `D0`..`D13`, `A0`..`A5` |
| Mega 2560 | `D0`..`D53`, `A0`..`A15` |

### `Direction`

```zig
const Direction = enum { in, out };
```

| Variant | Meaning |
|---|---|
| `.in` | Configure the pin as an input |
| `.out` | Configure the pin as an output |

## Functions

### `init`

```zig
pub fn init(comptime pin: Pin, comptime dir: Direction) void
```

Sets a pin's direction. Must be called before reading or writing a pin.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `Pin` | The pin to configure (comptime) |
| `dir` | `Direction` | `.in` for input, `.out` for output (comptime) |

### `read`

```zig
pub fn read(comptime pin: Pin) bool
```

Reads the current level of a pin. Returns `true` if the pin is high, `false` if low.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `Pin` | The pin to read (comptime) |

### `write`

```zig
pub fn write(comptime pin: Pin, high: bool) void
```

Drives a pin high or low.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `Pin` | The pin to write (comptime) |
| `high` | `bool` | `true` for high, `false` for low |

### `toggle`

```zig
pub fn toggle(comptime pin: Pin) void
```

Flips the current output state of a pin. If the pin is high it goes low, and vice versa.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `Pin` | The pin to toggle (comptime) |

### `setPullup`

```zig
pub fn setPullup(comptime pin: Pin, enabled: bool) void
```

Enables or disables the internal pull-up resistor on a pin. The pin should be configured as an input first.

| Parameter | Type | Description |
|---|---|---|
| `pin` | `Pin` | The pin to configure (comptime) |
| `enabled` | `bool` | `true` to enable the pull-up, `false` to disable |

:::note
All pin arguments are `comptime` -- they must be known at compile time. This lets the compiler resolve the exact hardware registers and bit masks, producing tight machine code with zero runtime overhead.
:::
