---
title: Time
description: Millisecond timing, delays, and system tick.
sidebar:
  order: 6
---

The Time module provides a millisecond system tick using Timer0. It is the foundation for delays and time measurement across the library.

```zig
const avr = @import("avr_zig");
const time = avr.time;
```

:::caution
Timer0 is **reserved** by this module. Pins that use Timer0 for PWM (D5 and D6 on the Uno/Nano) cannot be used with the [PWM](/reference/hal/pwm/) module.
:::

## Functions

### `sleep`

```zig
pub fn sleep(ms: u32) void
```

Blocks for at least the specified number of milliseconds. If `ms` is `0`, returns immediately. Timer0 is initialized automatically on the first call.

| Parameter | Type | Description |
|---|---|---|
| `ms` | `u32` | Duration in milliseconds |

The MCU enters idle mode between ticks to reduce power consumption while waiting.

### `millis`

```zig
pub fn millis() u32
```

Returns the number of milliseconds elapsed since Timer0 was first started. The counter wraps around after approximately 49.7 days (`2^32` milliseconds) using wrapping arithmetic.

**Returns:** the current tick count as a `u32`.

:::tip
To measure elapsed time safely across wraps, use wrapping subtraction:
```zig
const start = time.millis();
// ... do work ...
const elapsed = time.millis() -% start;
```
:::

## Internals

Timer0 runs in CTC (Clear Timer on Compare) mode with a prescaler of 64. At 16 MHz the compare value is set to produce an interrupt every 1 ms. The interrupt handler increments an internal counter that `millis()` reads atomically with interrupts briefly disabled.

The `runtime_interrupts` declaration binds the `TIMER0_COMPA` interrupt vector to this module's handler automatically.
