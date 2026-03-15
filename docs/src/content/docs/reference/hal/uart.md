---
title: UART
description: Send serial data over USART0.
sidebar:
  order: 3
---

The UART module provides serial output over the USART0 peripheral. This is the same serial port connected to the USB-to-serial converter on most Arduino boards, so you can view the output in any serial terminal.

```zig
const avr = @import("avr_zig");
const uart = avr.uart;
```

:::caution
The UART module is currently **transmit-only** -- there is no receive capability. The only supported baud rate is **115200**.
:::

## Functions

### `init`

```zig
pub fn init(comptime baud: comptime_int) void
```

Initializes the UART transmitter. Must be called once before any `write` or `write_ch` calls. Configures USART0 with 8N1 framing and double-speed mode.

| Parameter | Type | Description |
|---|---|---|
| `baud` | `comptime_int` | Baud rate -- must be `115200` |

Passing any value other than `115200` produces the compile error: `"uart.init currently supports only 115200 baud on this Zig toolchain"`.

### `write`

```zig
pub fn write(data: []const u8) void
```

Sends every byte in `data` over the serial port, then waits for the last byte to finish transmitting.

| Parameter | Type | Description |
|---|---|---|
| `data` | `[]const u8` | The bytes to send |

### `write_ch`

```zig
pub fn write_ch(ch: u8) void
```

Sends a single byte. Blocks until the transmit data register is ready, then writes the byte.

| Parameter | Type | Description |
|---|---|---|
| `ch` | `u8` | The byte to send |

## Example

```zig
uart.init(115200);
uart.write("Hello, world!\r\n");
```

:::tip
Serial terminals expect `\r\n` (carriage return + newline) for proper line breaks.
:::
