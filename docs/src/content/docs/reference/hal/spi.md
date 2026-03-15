---
title: SPI
description: Communicate with SPI peripherals in master mode.
sidebar:
  order: 5
---

The SPI module provides master-mode, full-duplex SPI communication. It operates in Mode 0 (CPOL=0, CPHA=0) with MSB-first bit order.

```zig
const avr = @import("avr_zig");
const spi = avr.spi;
```

The SPI pins are fixed by the hardware:

| Board | SS | MOSI | MISO | SCK |
|---|---|---|---|---|
| Uno / Nano | D10 | D11 | D12 | D13 |
| Mega 2560 | D53 | D51 | D50 | D52 |

## Types

### `ClockDiv`

```zig
pub const ClockDiv = enum { f2, f4, f8, f16, f32, f64, f128 };
```

SPI clock divider relative to the CPU frequency. At 16 MHz:

| Variant | Divider | Resulting clock |
|---|---|---|
| `.f2` | CPU / 2 | 8 MHz |
| `.f4` | CPU / 4 | 4 MHz |
| `.f8` | CPU / 8 | 2 MHz |
| `.f16` | CPU / 16 | 1 MHz |
| `.f32` | CPU / 32 | 500 kHz |
| `.f64` | CPU / 64 | 250 kHz |
| `.f128` | CPU / 128 | 125 kHz |

## Functions

### `init`

```zig
pub fn init(comptime clock_div: ClockDiv) void
```

Initializes SPI in master mode with the specified clock divider. Configures SS, MOSI, and SCK as outputs, MISO as input, and drives SS high.

| Parameter | Type | Description |
|---|---|---|
| `clock_div` | `ClockDiv` | Clock divider (comptime) |

### `transfer`

```zig
pub fn transfer(byte: u8) u8
```

Sends one byte and simultaneously receives one byte (full-duplex). Blocks until the transfer completes.

| Parameter | Type | Description |
|---|---|---|
| `byte` | `u8` | The byte to send |

**Returns:** the byte received from the peripheral during the transfer.

:::tip
When you only need to send data, ignore the return value: `_ = spi.transfer(0x42);`. When you only need to read, send a dummy byte: `const rx = spi.transfer(0x00);`.
:::
