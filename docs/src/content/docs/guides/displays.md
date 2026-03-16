---
title: Displays
description: Drive an SSD1306 OLED and an HD44780 LCD from your Arduino.
sidebar:
  order: 5
---

This guide shows you how to use two of the most common hobbyist displays with AVR-Zig: the **SSD1306** 128x64 OLED (graphical, over I2C) and the **HD44780** 16x2 character LCD (text, over an I2C backpack).

Both communicate over I2C, so make sure you're comfortable with the basics from the [Serial Communication](./serial-communication/) guide.

## SSD1306 OLED display

The SSD1306 is a small monochrome OLED screen, typically 128x64 pixels and about 0.96 inches diagonal. It's sharp, fast, and needs only four wires.

### What you'll need

- An SSD1306 OLED module (128x64, I2C variant -- the 4-pin version)
- A breadboard and jumper wires

### Wiring

```
Arduino             SSD1306 OLED
-------             ------------
SDA (A4 / D20) ──── SDA
SCL (A5 / D21) ──── SCL
5V  ──────────────── VCC
GND ──────────────── GND
```

Use A4/A5 on the Uno and Nano, or D20/D21 on the Mega 2560. Most SSD1306 modules have an onboard voltage regulator and work fine at 5V.

### Drawing on the OLED

The SSD1306 driver uses a **framebuffer** -- a block of memory that represents every pixel on screen. You draw into the framebuffer with functions like `drawRect` and `drawText`, then call `present()` to push the entire buffer to the display over I2C.

```zig
const avr = @import("avr_zig");
const time = avr.time;
const uart = avr.uart;
const ssd1306 = avr.drivers.display.ssd1306;

const Display = ssd1306.Display(128, 64);

var display: Display = .{};

pub fn main() void {
    uart.init(115200);

    if (!display.init()) {
        uart.write("SSD1306 not found\r\n");
        while (true) { time.sleep(500); }
    }

    // Clear the screen
    display.clear(.off);

    // Draw a border around the entire screen
    display.drawRect(0, 0, 128, 64, .on);

    // Draw a filled bar near the top
    display.fillRect(4, 4, 120, 12, .on);

    // Write text (inverted colors on the filled bar)
    display.drawText(12, 6, "AVR ZIG", .off, ssd1306.default_font);

    // Write normal text below
    display.drawText(12, 27, "Hello OLED!", .on, ssd1306.default_font);

    // Draw some lines
    display.drawLine(8, 48, 56, 48, .on);
    display.drawLine(8, 56, 56, 56, .on);

    // Push the framebuffer to the display
    if (display.present()) {
        uart.write("Display updated\r\n");
    } else {
        uart.write("Display update failed\r\n");
    }

    while (true) {
        time.sleep(500);
    }
}
```

Let's break down the key parts:

**Creating the display:**

```zig
const Display = ssd1306.Display(128, 64);
var display: Display = .{};
```

`ssd1306.Display(128, 64)` is a **comptime function call** that returns a type. In Zig, types can be created and manipulated at compile time. This generates a display type with a framebuffer sized exactly for 128x64 pixels. The `= .{}` initializes it with default values (address `0x3C`, all pixels off).

:::note[Zig concept: comptime types]
`Display(128, 64)` doesn't create a display -- it creates a *type*. Think of it like a template or generic in other languages. The resulting type has the right buffer size baked in, so there's no runtime allocation. This is a common Zig pattern for hardware drivers where dimensions are known at compile time.
:::

**The `var` declaration:**

The display is declared as `var` (not `const`) because its internal framebuffer gets modified by drawing operations. It's declared at file scope (outside any function) because the framebuffer is too large for the AVR's limited stack.

**Colors:**

The `Color` enum has two values: `.on` (pixel lit) and `.off` (pixel dark). For `drawText`, the color applies to the text pixels -- use `.off` on a filled background for inverted text.

**`init()` and `present()`:**

Both return `bool`. `init()` returns `false` if the display doesn't respond at the expected I2C address. `present()` returns `false` if the I2C transfer fails. Always check these in real projects.

### SSD1306 drawing API

| Function | Description |
|---|---|
| `display.init()` | Initialize the display over I2C. Returns `bool`. |
| `display.clear(color)` | Fill the entire framebuffer with `.on` or `.off` |
| `display.drawPixel(x, y, color)` | Set a single pixel |
| `display.drawRect(x, y, w, h, color)` | Draw a rectangle outline |
| `display.fillRect(x, y, w, h, color)` | Draw a filled rectangle |
| `display.drawLine(x0, y0, x1, y1, color)` | Draw a line between two points |
| `display.drawText(x, y, text, color, font)` | Draw a string using a bitmap font |
| `display.present()` | Send the framebuffer to the display. Returns `bool`. |

Coordinates are in pixels. `(0, 0)` is the top-left corner. The default font is `ssd1306.default_font` (5x7 pixels per character).

:::tip[If the display doesn't respond]
Some SSD1306 modules use address `0x3D` instead of the default `0x3C`. Use the I2C scan example from the [Serial Communication](./serial-communication/) guide to find the actual address, then set it before calling `init()`:
```zig
display.address = 0x3D;
```
:::

## HD44780 character LCD

The HD44780 is the classic green (or blue) character LCD. The most common size is 16 columns by 2 rows (a "1602"). When paired with a PCF8574 I2C backpack module, it only needs four wires.

### What you'll need

- A 16x2 (or 20x4) LCD with an I2C backpack soldered on
- A breadboard and jumper wires

### Wiring

```
Arduino             LCD I2C backpack
-------             ----------------
SDA (A4 / D20) ──── SDA
SCL (A5 / D21) ──── SCL
5V  ──────────────── VCC
GND ──────────────── GND
```

Same I2C wiring as the SSD1306. If you have both connected, they'll share the bus -- each responds to its own address.

### Writing text to the LCD

```zig
const avr = @import("avr_zig");
const hd44780_i2c = avr.drivers.display.hd44780_i2c;
const time = avr.time;
const uart = avr.uart;

const Display = hd44780_i2c.Display(16, 2);

var display: Display = .{};

pub fn main() void {
    uart.init(115200);

    if (!display.init()) {
        uart.write("LCD not found\r\n");
        while (true) { time.sleep(500); }
    }

    // Write text to each row
    display.writeLine(0, "Hello from Zig!");
    display.writeLine(1, "AVR-Zig v0.1");

    // Send the buffer to the LCD
    if (display.present()) {
        uart.write("LCD updated\r\n");
    } else {
        uart.write("LCD update failed\r\n");
    }

    while (true) {
        time.sleep(500);
    }
}
```

Like the SSD1306 driver, the HD44780 driver uses a buffer-then-present pattern:

1. Write text into the internal buffer with `writeLine()` or `put()`
2. Call `present()` to send the buffer contents to the display hardware

**`Display(16, 2)`** creates a type for a 16-column, 2-row LCD. For a 20x4 display, use `Display(20, 4)`.

**`writeLine(row, text)`** writes a string to the given row (0-indexed). If the text is shorter than the display width, the rest of the row is filled with spaces. If it's longer, it's truncated.

**`put(column, row, char)`** writes a single character at a specific position -- useful for updating one character without rewriting the entire line.

### Updating the display in a loop

Here's an example that cycles through ASCII characters:

```zig
pub fn main() void {
    uart.init(115200);

    if (!display.init()) {
        uart.write("LCD not found\r\n");
        while (true) { time.sleep(500); }
    }

    var offset: u8 = 0;

    while (true) {
        display.writeLine(0, "ASCII table:");

        // Fill row 1 with 16 consecutive ASCII characters
        var col: u8 = 0;
        while (col < 16) : (col += 1) {
            const char = 0x20 + ((offset + col) % 95); // Printable ASCII range
            display.put(col, 1, char);
        }

        _ = display.present();

        offset +%= 16;
        time.sleep(1500);
    }
}
```

### HD44780 API summary

| Function | Description |
|---|---|
| `display.init()` | Initialize the LCD. Returns `bool`. |
| `display.clear()` | Clear the text buffer (fill with spaces) |
| `display.writeLine(row, text)` | Write a string to a row |
| `display.put(col, row, char)` | Write a single character at a position |
| `display.present()` | Send the buffer to the LCD. Returns `bool`. |

:::tip[If the LCD doesn't respond]
The most common I2C backpack addresses are `0x27` and `0x3F`. The driver defaults to `0x27`. If yours uses a different address:
```zig
display.address = hd44780_i2c.alternate_address; // 0x3F
```
Or use the I2C scan to find the correct address.
:::

## 7-segment displays

AVR-Zig also includes a driver for 7-segment displays (single digit and 4-digit multiplexed). These are driven directly via GPIO pins rather than I2C. See the `seven-segment-single` and `seven-segment-4-digit` examples in the repository for complete working code.

## Next steps

Now that you can show information on a display, try reading data from sensors. The [Sensors](./sensors/) guide covers the DHT11 temperature/humidity sensor and the HC-SR04 ultrasonic distance sensor.
