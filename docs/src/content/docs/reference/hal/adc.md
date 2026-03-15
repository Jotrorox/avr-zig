---
title: ADC
description: Read analog voltages with the analog-to-digital converter.
sidebar:
  order: 2
---

The ADC module reads analog voltages and returns a 10-bit digital value (0--1023).

```zig
const avr = @import("avr_zig");
const adc = avr.adc;
```

## Types

### `AnalogPin`

An enum of the analog input pins available on the selected board.

| Board | Pins |
|---|---|
| Uno | `A0`..`A5` |
| Nano | `A0`..`A7` |
| Mega 2560 | `A0`..`A15` |

:::note
On the Nano, `A6` and `A7` are analog-only pins -- they cannot be used as digital I/O.
:::

## Functions

### `init`

```zig
pub fn init() void
```

Initializes the ADC peripheral. This is called automatically by `read()` if needed, so you usually don't need to call it yourself.

### `read`

```zig
pub fn read(comptime pin: AnalogPin) u16
```

Reads one analog sample from the given pin. Returns a 10-bit value in the range `0`--`1023`, where `0` corresponds to 0 V and `1023` corresponds to the reference voltage (AVCC, typically 5 V).

| Parameter | Type | Description |
|---|---|---|
| `pin` | `AnalogPin` | The analog pin to sample (comptime) |

The function automatically:

- Initializes the ADC if it hasn't been set up yet
- Configures the pin as an input with the pull-up disabled
- Disables the digital input buffer on the pin to reduce noise
- Starts a conversion and blocks until the result is ready
