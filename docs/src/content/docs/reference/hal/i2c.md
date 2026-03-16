---
title: I2C
description: Communicate with I2C/TWI peripherals in master mode.
sidebar:
  order: 4
---

The I2C module provides master-mode communication over the TWI (Two-Wire Interface) bus. It is used by display drivers like the [SSD1306](../display/ssd1306/) and [HD44780](../display/hd44780/).

```zig
const avr = @import("avr_zig");
const i2c = avr.i2c;
```

The I2C pins are fixed by the hardware:

| Board | SDA | SCL |
|---|---|---|
| Uno / Nano | A4 | A5 |
| Mega 2560 | D20 | D21 |

## Constants

### `default_clock_hz`

```zig
pub const default_clock_hz = 100_000;
```

The default I2C clock frequency (100 kHz, Standard Mode).

## Functions

### `init`

```zig
pub fn init() void
```

Initializes I2C at the default clock rate (100 kHz). Configures the SDA and SCL pins as inputs with internal pull-ups enabled.

### `initWithFrequency`

```zig
pub fn initWithFrequency(comptime clock_hz: comptime_int) void
```

Initializes I2C at a custom clock rate.

| Parameter | Type | Description |
|---|---|---|
| `clock_hz` | `comptime_int` | The desired clock frequency in Hz (comptime) |

**Compile errors:**

- `"I2C clock must be greater than zero"` -- if `clock_hz <= 0`
- `"I2C clock is too high for the configured CPU frequency"` -- if `clock_hz > CPU_FREQ / 16`
- `"Computed TWBR value does not fit in 8 bits"` -- if the computed register value exceeds 255

### `probe`

```zig
pub fn probe(address: u7) bool
```

Checks whether a device at the given 7-bit address responds on the bus. Sends a START condition and the address byte, then releases the bus.

| Parameter | Type | Description |
|---|---|---|
| `address` | `u7` | 7-bit I2C device address |

**Returns:** `true` if the device acknowledged, `false` otherwise.

### `scan`

```zig
pub fn scan(comptime on_found: fn (u7) void) usize
```

Probes every valid I2C address from `0x08` to `0x77` and calls `on_found` for each device that responds.

| Parameter | Type | Description |
|---|---|---|
| `on_found` | `fn (u7) void` | Callback invoked with each responding address (comptime) |

**Returns:** the total number of devices found.

### `write`

```zig
pub fn write(address: u7, bytes: []const u8) bool
```

Writes a complete message to a device. Sends START, address, all bytes, then STOP.

| Parameter | Type | Description |
|---|---|---|
| `address` | `u7` | 7-bit I2C device address |
| `bytes` | `[]const u8` | Data to send |

**Returns:** `true` on success, `false` if any step failed.

### `startWrite`

```zig
pub fn startWrite(address: u7) bool
```

Begins a write transaction by sending START and the address byte. You must call `stop()` when finished.

| Parameter | Type | Description |
|---|---|---|
| `address` | `u7` | 7-bit I2C device address |

**Returns:** `true` if the device acknowledged.

### `writeData`

```zig
pub fn writeData(byte: u8) bool
```

Writes one data byte within an active transaction (after `startWrite`).

| Parameter | Type | Description |
|---|---|---|
| `byte` | `u8` | The byte to send |

**Returns:** `true` if the byte was acknowledged.

### `stop`

```zig
pub fn stop() void
```

Ends the current I2C transaction by sending a STOP condition.

:::note
The `write()` function handles START and STOP automatically. You only need `startWrite` / `writeData` / `stop` when building multi-part transactions -- for example, writing a register address followed by data in separate steps.
:::
