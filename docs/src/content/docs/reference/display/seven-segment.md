---
title: Seven-Segment Display
description: Drive single-digit and multiplexed 4-digit seven-segment displays.
sidebar:
  order: 3
---

The seven-segment driver controls GPIO-connected seven-segment LED displays. It supports both single-digit and multiplexed 4-digit configurations with common-cathode or common-anode wiring.

```zig
const avr = @import("avr_zig");
const seven_segment = avr.drivers.display.seven_segment;
```

## Types

### `Common`

```zig
pub const Common = enum { cathode, anode };
```

| Variant | Meaning |
|---|---|
| `.cathode` | Common-cathode display (segments light when driven high) |
| `.anode` | Common-anode display (segments light when driven low) |

### `SegmentPins`

```zig
pub const SegmentPins = struct {
    a: gpio.Pin,
    b: gpio.Pin,
    c: gpio.Pin,
    d: gpio.Pin,
    e: gpio.Pin,
    f: gpio.Pin,
    g: gpio.Pin,
    dp: ?gpio.Pin = null,
};
```

Maps segment lines A through G (and optionally the decimal point) to GPIO pins.

### `DigitPins4`

```zig
pub const DigitPins4 = struct {
    d1: gpio.Pin,
    d2: gpio.Pin,
    d3: gpio.Pin,
    d4: gpio.Pin,
};
```

Maps the four digit-enable lines to GPIO pins for multiplexed displays.

## `SingleDigit`

```zig
pub fn SingleDigit(comptime segment_pins: SegmentPins, comptime common: Common) type
```

Returns a driver for a single seven-segment digit.

### Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `pattern` | `u8` | `0` | Current segment bitmask (bits 0--7 map to A--DP) |

### Methods

#### `init`

```zig
pub fn init(self: *Self) void
```

Configures all segment pins as outputs and clears the display.

#### `clear`

```zig
pub fn clear(self: *Self) void
```

Turns all segments off.

#### `showRaw`

```zig
pub fn showRaw(self: *Self, pattern: u8) void
```

Writes a raw segment bitmask. Bits 0--6 correspond to segments A--G; bit 7 is the decimal point.

#### `showChar`

```zig
pub fn showChar(self: *Self, char: u8) void
```

Displays an ASCII character. Unsupported characters are shown as blank (all segments off).

#### `showDigit`

```zig
pub fn showDigit(self: *Self, digit: u4) void
```

Displays a decimal digit (0--15 maps to `'0'`--`'F'` in the character table).

#### `showHex`

```zig
pub fn showHex(self: *Self, value: u8) void
```

Displays the low nibble of `value` as a hexadecimal character (0--F).

#### `setDecimalPoint`

```zig
pub fn setDecimalPoint(self: *Self, enabled: bool) void
```

Turns the decimal point on or off without changing the other segments.

## `FourDigit`

```zig
pub fn FourDigit(
    comptime segment_pins: SegmentPins,
    comptime digit_pins: DigitPins4,
    comptime common: Common,
) type
```

Returns a driver for a multiplexed 4-digit display. Because all four digits share the same segment lines, only one digit is lit at a time. You must call `refresh()` frequently to cycle through the digits fast enough for persistence of vision.

### Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `patterns` | `[4]u8` | all zeros | Segment bitmasks for each digit |
| `next_digit` | `u8` | `0` | Index of the next digit to light |

### Methods

#### `init`

```zig
pub fn init(self: *Self) void
```

Configures all segment and digit pins as outputs and clears the display buffer.

#### `clear`

```zig
pub fn clear(self: *Self) void
```

Clears the display buffer and turns all digits off.

#### `write`

```zig
pub fn write(self: *Self, text: []const u8) void
```

Writes up to four ASCII characters into the display buffer, starting from the leftmost digit. Extra characters are ignored.

#### `setDigit`

```zig
pub fn setDigit(self: *Self, index: u8, char: u8) void
```

Sets one digit in the buffer from an ASCII character. `index` 0 is the leftmost digit.

#### `setDecimalPoint`

```zig
pub fn setDecimalPoint(self: *Self, index: u8, enabled: bool) void
```

Enables or disables the decimal point on a specific digit.

#### `showNumber`

```zig
pub fn showNumber(self: *Self, value: i16) void
```

Right-aligns and displays a signed integer. Displayable range is -999 to 9999. Values outside this range show `"----"`.

#### `refresh`

```zig
pub fn refresh(self: *Self) void
```

Lights the next digit in the rotation. Call this frequently (every few milliseconds) in your main loop to maintain the illusion that all digits are lit simultaneously.

#### `refreshFor`

```zig
pub fn refreshFor(self: *Self, duration_ms: u16, digit_hold_ms: u16) void
```

Repeatedly calls `refresh()` for a total of `duration_ms` milliseconds, holding each digit lit for `digit_hold_ms` milliseconds.

| Parameter | Type | Description |
|---|---|---|
| `duration_ms` | `u16` | Total refresh duration |
| `digit_hold_ms` | `u16` | Time each digit stays lit per cycle (minimum 1) |

## Supported characters

The driver can display the following ASCII characters. Any character not listed below is shown as blank.

| Characters | Display |
|---|---|
| `0`--`9` | Decimal digits |
| `A`--`F` | Hex digits (also matches lowercase `a`--`f`) |
| `H`, `I`, `J`, `L`, `N`, `O`, `P`, `R`, `S`, `T`, `U` | Letters |
| `-` | Minus sign (segment G) |
| `_` | Underscore (segment D) |
| ` ` (space) | Blank |
