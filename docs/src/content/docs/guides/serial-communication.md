---
title: Serial Communication
description: Send debug output over UART and talk to devices on the I2C bus.
sidebar:
  order: 4
---

This guide covers the two main communication interfaces in AVR-Zig: **UART** for serial debug output to your computer, and **I2C** for talking to sensors, displays, and other peripherals on a shared two-wire bus.

## What you'll need

- A working AVR-Zig project (see [Your First Project](./basic/))
- For the I2C section: any I2C device (an SSD1306 OLED or an LCD with an I2C backpack are common choices)
- A breadboard and jumper wires

## What you'll learn

- Sending text and numbers over UART
- Writing reusable number-formatting helpers
- How the I2C bus works
- Scanning for I2C devices
- Sending data to an I2C device

## UART -- serial output to your computer

UART (Universal Asynchronous Receiver-Transmitter) is the simplest way to get information out of your microcontroller. It sends data over the USB cable to your computer, where you can read it with a serial terminal.

### Sending text

```zig
const avr = @import("avr_zig");
const time = avr.time;
const uart = avr.uart;

pub fn main() void {
    uart.init(115200);

    var counter: u16 = 0;

    while (true) {
        uart.write("count=");
        writeDecimal(counter);
        uart.write("\r\n");

        counter +%= 1;
        time.sleep(1000);
    }
}
```

`uart.init(115200)` configures the hardware for 115200 baud, 8 data bits, no parity, 1 stop bit (8N1). Call it once at the start of your program, before any writes. Currently 115200 is the only supported baud rate.

`uart.write(data)` sends a byte slice (a string literal like `"hello"` counts as a byte slice in Zig). `uart.write_ch(byte)` sends a single byte.

:::tip[`+%=` wrapping addition]
The `+%=` operator is Zig's **wrapping addition**. When `counter` reaches the maximum value of a `u16` (65535), it wraps back to 0 instead of causing a runtime error. This is useful for counters that you want to roll over naturally. Regular `+=` would trap in safe build modes if the value overflows.
:::

### Formatting numbers

UART sends raw bytes. To print a number, you need to convert each digit to its ASCII character. Here are the helper patterns used throughout the AVR-Zig examples:

**Decimal (base 10):**

```zig
fn writeDecimal(value: u16) void {
    if (value >= 10000) uart.write_ch('0' + @as(u8, @intCast(value / 10000 % 10)));
    if (value >= 1000) uart.write_ch('0' + @as(u8, @intCast(value / 1000 % 10)));
    if (value >= 100) uart.write_ch('0' + @as(u8, @intCast(value / 100 % 10)));
    if (value >= 10) uart.write_ch('0' + @as(u8, @intCast(value / 10 % 10)));
    uart.write_ch('0' + @as(u8, @intCast(value % 10)));
}
```

This prints only the digits that matter -- `42` prints as `42`, not `00042`. Each digit is computed with division and modulo, then shifted into the ASCII range by adding `'0'` (which is 48).

**Hexadecimal (base 16):**

```zig
fn writeHexByte(value: u8) void {
    writeHexNibble(value >> 4);
    writeHexNibble(value & 0x0F);
}

fn writeHexNibble(value: u8) void {
    const digit = if (value < 10) '0' + value else 'A' + (value - 10);
    uart.write_ch(digit);
}
```

Hex is useful for I2C addresses, register values, and raw sensor data -- anything where you're thinking in terms of bytes and bits.

**Boolean:**

```zig
fn writeBool(value: bool) void {
    uart.write(if (value) "true" else "false");
}
```

:::note[Why not use `std.fmt`?]
Zig's standard library has powerful formatting in `std.fmt`, but it pulls in code that's too large for an AVR's limited flash memory. These small manual formatters compile down to a handful of instructions each.
:::

### Viewing serial output

After flashing your firmware, open the serial monitor:

```sh
zig build monitor -Dboard=uno -Dtty=/dev/ttyACM0
```

This opens `screen` at 115200 baud. To exit, press `Ctrl+A` then `K`, then confirm with `y`.

You can also use any other serial terminal: `minicom`, `picocom`, PuTTY, or the Arduino IDE's serial monitor (set to 115200 baud).

## I2C -- talking to peripherals

I2C (also called TWI on AVR) is a two-wire bus that lets multiple devices share just two pins. One wire carries a clock signal (SCL), the other carries data (SDA). Each device on the bus has a unique 7-bit address.

### Wiring

I2C pins are fixed by the hardware -- you can't choose arbitrary pins:

| Board | SDA | SCL |
|---|---|---|
| Uno | A4 | A5 |
| Nano | A4 | A5 |
| Mega 2560 | D20 | D21 |

Connect your I2C device's SDA to the board's SDA, SCL to SCL, plus VCC and GND:

```
Arduino             I2C device
-------             ----------
SDA (see table) ──── SDA
SCL (see table) ──── SCL
5V  ──────────────── VCC
GND ──────────────── GND
```

AVR-Zig enables the internal pull-up resistors on SDA and SCL automatically. For short wires on a breadboard, this is usually sufficient. For longer runs or multiple devices, add external 4.7K pull-up resistors from SDA and SCL to 5V.

### Scanning the bus

The most useful first step with I2C is scanning the bus to find which devices are present and what addresses they respond at:

```zig
const avr = @import("avr_zig");
const i2c = avr.i2c;
const time = avr.time;
const uart = avr.uart;

pub fn main() void {
    uart.init(115200);
    i2c.init();

    while (true) {
        uart.write("I2C scan:\r\n");
        const count = i2c.scan(reportDevice);

        if (count == 0) {
            uart.write("  no devices found\r\n");
        }

        uart.write("\r\n");
        time.sleep(2000);
    }
}

fn reportDevice(address: u7) void {
    uart.write("  found device at 0x");
    writeHexByte(@as(u8, address));
    uart.write("\r\n");
}

fn writeHexByte(value: u8) void {
    writeHexNibble(value >> 4);
    writeHexNibble(value & 0x0F);
}

fn writeHexNibble(value: u8) void {
    const digit = if (value < 10) '0' + value else 'A' + (value - 10);
    uart.write_ch(digit);
}
```

`i2c.init()` sets up the TWI peripheral at 100 kHz (the standard I2C speed). `i2c.scan(callback)` probes every valid address (0x08 to 0x77) and calls your function for each device that responds. It returns the total count.

The callback parameter is a **comptime function pointer**. In Zig, functions are first-class values -- you pass `reportDevice` (without parentheses) and the library calls it for you. The `comptime` part means the compiler inlines the call, so there's no function-pointer overhead at runtime.

:::tip
Common I2C addresses you might see:
- `0x3C` or `0x3D` -- SSD1306 OLED display
- `0x27` or `0x3F` -- HD44780 LCD with PCF8574 I2C backpack
- `0x68` -- DS1307/DS3231 real-time clock, MPU-6050 accelerometer
- `0x76` or `0x77` -- BMP280/BME280 pressure sensor
:::

### Writing data to a device

For devices that AVR-Zig doesn't have a built-in driver for, you can use the low-level I2C API directly:

```zig
// Send a single byte to a device
fn sendByte(address: u7, data: u8) bool {
    if (!i2c.startWrite(address)) return false;
    const ok = i2c.writeData(data);
    i2c.stop();
    return ok;
}
```

Or send multiple bytes at once:

```zig
// Send a command + data byte to a device
fn sendCommand(address: u7, cmd: u8, value: u8) bool {
    const bytes = [_]u8{ cmd, value };
    return i2c.write(address, &bytes);
}
```

`i2c.write(address, bytes)` handles the full transaction: start, address, data, stop. It returns `false` if any step fails (device not responding, bus error, etc.).

For more granular control:

| Function | Description |
|---|---|
| `i2c.init()` | Initialize at 100 kHz |
| `i2c.probe(address)` | Check if a device responds |
| `i2c.scan(callback)` | Scan all addresses, call `callback` for each found |
| `i2c.write(address, bytes)` | Write a byte slice to a device (full transaction) |
| `i2c.startWrite(address)` | Begin a write transaction |
| `i2c.writeData(byte)` | Send one byte within an open transaction |
| `i2c.stop()` | End the current transaction |

The `startWrite` / `writeData` / `stop` sequence gives you control over multi-part messages where you need to send a register address followed by data without releasing the bus in between.

## UART API summary

| Function | Description |
|---|---|
| `uart.init(115200)` | Initialize UART at 115200 baud |
| `uart.write(data)` | Send a byte slice / string |
| `uart.write_ch(byte)` | Send a single byte |

UART is currently transmit-only -- there is no receive function yet. Serial data is sent on pin D0/D1 (TX/RX) on all supported boards.

## Next steps

With UART for debugging and I2C for peripherals, you're ready to drive displays. The [Displays](./displays/) guide shows you how to use an SSD1306 OLED and an HD44780 LCD.
