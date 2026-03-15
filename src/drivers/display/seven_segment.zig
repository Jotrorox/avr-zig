const gpio = @import("../../hal/gpio.zig");
const time = @import("../../hal/time.zig");

pub const Common = enum {
    cathode,
    anode,
};

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

pub const DigitPins4 = struct {
    d1: gpio.Pin,
    d2: gpio.Pin,
    d3: gpio.Pin,
    d4: gpio.Pin,
};

const segment_a: u8 = 1 << 0;
const segment_b: u8 = 1 << 1;
const segment_c: u8 = 1 << 2;
const segment_d: u8 = 1 << 3;
const segment_e: u8 = 1 << 4;
const segment_f: u8 = 1 << 5;
const segment_g: u8 = 1 << 6;
const segment_dp: u8 = 1 << 7;

/// Returns a single-digit 7-segment display driver.
pub fn SingleDigit(comptime segment_pins: SegmentPins, comptime common: Common) type {
    return struct {
        const Self = @This();

        pattern: u8 = 0,

        /// Configures the segment pins and clears the display.
        pub fn init(self: *Self) void {
            initSegmentPins(segment_pins);
            self.clear();
        }

        /// Turns all segments off.
        pub fn clear(self: *Self) void {
            self.pattern = 0;
            applySegments(segment_pins, common, self.pattern);
        }

        /// Writes the raw segment pattern. Bit 0..7 map to A..DP.
        pub fn showRaw(self: *Self, pattern: u8) void {
            self.pattern = pattern;
            applySegments(segment_pins, common, self.pattern);
        }

        /// Shows one ASCII character. Unsupported characters become blank.
        pub fn showChar(self: *Self, char: u8) void {
            self.showRaw(patternForChar(char));
        }

        /// Shows one decimal digit.
        pub fn showDigit(self: *Self, digit: u4) void {
            self.showChar(@as(u8, '0') + @as(u8, digit));
        }

        /// Shows the low nibble as hexadecimal.
        pub fn showHex(self: *Self, value: u8) void {
            self.showChar(hexChar(value & 0x0F));
        }

        /// Enables or disables the decimal point.
        pub fn setDecimalPoint(self: *Self, enabled: bool) void {
            if (enabled) {
                self.pattern |= segment_dp;
            } else {
                self.pattern &= ~segment_dp;
            }

            applySegments(segment_pins, common, self.pattern);
        }
    };
}

/// Returns a multiplexed 4-digit 7-segment display driver.
pub fn FourDigit(comptime segment_pins: SegmentPins, comptime digit_pins: DigitPins4, comptime common: Common) type {
    return struct {
        const Self = @This();

        patterns: [4]u8 = [_]u8{0} ** 4,
        next_digit: u8 = 0,

        /// Configures the pins and clears the display buffer.
        pub fn init(self: *Self) void {
            initSegmentPins(segment_pins);
            initDigitPins(digit_pins);
            self.clear();
        }

        /// Clears the display buffer and turns all digits off.
        pub fn clear(self: *Self) void {
            self.patterns = [_]u8{0} ** 4;
            self.next_digit = 0;
            disableAllDigits(digit_pins, common);
            applySegments(segment_pins, common, 0);
        }

        /// Writes up to four ASCII characters into the display buffer.
        pub fn write(self: *Self, text: []const u8) void {
            @setRuntimeSafety(false);

            var index: usize = 0;
            while (index < self.patterns.len) : (index += 1) {
                self.patterns[index] = 0;
            }

            index = 0;
            while (index < text.len and index < self.patterns.len) : (index += 1) {
                self.patterns[index] = patternForChar(text[index]);
            }
        }

        /// Sets one buffered digit from an ASCII character.
        pub fn setDigit(self: *Self, index: u8, char: u8) void {
            @setRuntimeSafety(false);

            if (index >= self.patterns.len) {
                return;
            }

            self.patterns[index] = patternForChar(char);
        }

        /// Enables or disables one digit decimal point.
        pub fn setDecimalPoint(self: *Self, index: u8, enabled: bool) void {
            @setRuntimeSafety(false);

            if (index >= self.patterns.len) {
                return;
            }

            if (enabled) {
                self.patterns[index] |= segment_dp;
            } else {
                self.patterns[index] &= ~segment_dp;
            }
        }

        /// Right-aligns and displays a signed integer.
        pub fn showNumber(self: *Self, value: i16) void {
            @setRuntimeSafety(false);

            var chars = [_]u8{' '} ** 4;
            const negative = value < 0;
            const signed_value = @as(i32, value);
            const magnitude: u16 = @intCast(if (negative) -signed_value else signed_value);

            if ((!negative and magnitude > 9999) or (negative and magnitude > 999)) {
                self.write("----");
                return;
            }

            var remaining = magnitude;
            var thousands: u8 = 0;
            if (remaining >= 5000) {
                thousands += 5;
                remaining -= 5000;
            }
            if (remaining >= 2000) {
                thousands += 2;
                remaining -= 2000;
            }
            if (remaining >= 1000) {
                thousands += 1;
                remaining -= 1000;
            }

            var hundreds: u8 = 0;
            if (remaining >= 500) {
                hundreds += 5;
                remaining -= 500;
            }
            if (remaining >= 200) {
                hundreds += 2;
                remaining -= 200;
            }
            if (remaining >= 100) {
                hundreds += 1;
                remaining -= 100;
            }

            var tens: u8 = 0;
            if (remaining >= 50) {
                tens += 5;
                remaining -= 50;
            }
            if (remaining >= 20) {
                tens += 2;
                remaining -= 20;
            }
            if (remaining >= 10) {
                tens += 1;
                remaining -= 10;
            }

            const ones: u8 = @intCast(remaining);

            if (negative) {
                chars[0] = '-';
                if (hundreds != 0) {
                    chars[1] = '0' + hundreds;
                    chars[2] = '0' + tens;
                } else if (tens != 0) {
                    chars[2] = '0' + tens;
                }
                chars[3] = '0' + ones;
            } else {
                if (thousands != 0) {
                    chars[0] = '0' + thousands;
                    chars[1] = '0' + hundreds;
                    chars[2] = '0' + tens;
                } else if (hundreds != 0) {
                    chars[1] = '0' + hundreds;
                    chars[2] = '0' + tens;
                } else if (tens != 0) {
                    chars[2] = '0' + tens;
                }
                chars[3] = '0' + ones;
            }

            var index: usize = 0;
            while (index < chars.len) : (index += 1) {
                self.patterns[index] = patternForChar(chars[index]);
            }
        }

        /// Lights the next digit. Call this frequently in the main loop.
        pub fn refresh(self: *Self) void {
            @setRuntimeSafety(false);

            disableAllDigits(digit_pins, common);
            applySegments(segment_pins, common, self.patterns[self.next_digit]);
            enableDigit(digit_pins, common, self.next_digit);
            self.next_digit = (self.next_digit + 1) & 0x03;
        }

        /// Refreshes the multiplexed display for a duration.
        pub fn refreshFor(self: *Self, duration_ms: u16, digit_hold_ms: u16) void {
            const hold_ms = if (digit_hold_ms == 0) @as(u16, 1) else digit_hold_ms;
            var elapsed: u16 = 0;

            while (elapsed < duration_ms) {
                self.refresh();
                time.sleep(hold_ms);
                elapsed +|= hold_ms;
            }
        }
    };
}

fn initSegmentPins(comptime segment_pins: SegmentPins) void {
    gpio.init(segment_pins.a, .out);
    gpio.init(segment_pins.b, .out);
    gpio.init(segment_pins.c, .out);
    gpio.init(segment_pins.d, .out);
    gpio.init(segment_pins.e, .out);
    gpio.init(segment_pins.f, .out);
    gpio.init(segment_pins.g, .out);

    if (segment_pins.dp) |pin| {
        gpio.init(pin, .out);
    }
}

fn initDigitPins(comptime digit_pins: DigitPins4) void {
    gpio.init(digit_pins.d1, .out);
    gpio.init(digit_pins.d2, .out);
    gpio.init(digit_pins.d3, .out);
    gpio.init(digit_pins.d4, .out);
}

fn applySegments(comptime segment_pins: SegmentPins, comptime common: Common, pattern: u8) void {
    const on_level = common == .cathode;

    gpio.write(segment_pins.a, levelForSegment(on_level, pattern & segment_a != 0));
    gpio.write(segment_pins.b, levelForSegment(on_level, pattern & segment_b != 0));
    gpio.write(segment_pins.c, levelForSegment(on_level, pattern & segment_c != 0));
    gpio.write(segment_pins.d, levelForSegment(on_level, pattern & segment_d != 0));
    gpio.write(segment_pins.e, levelForSegment(on_level, pattern & segment_e != 0));
    gpio.write(segment_pins.f, levelForSegment(on_level, pattern & segment_f != 0));
    gpio.write(segment_pins.g, levelForSegment(on_level, pattern & segment_g != 0));

    if (segment_pins.dp) |pin| {
        gpio.write(pin, levelForSegment(on_level, pattern & segment_dp != 0));
    }
}

fn disableAllDigits(comptime digit_pins: DigitPins4, comptime common: Common) void {
    const enabled_level = common == .anode;
    const disabled_level = !enabled_level;

    gpio.write(digit_pins.d1, disabled_level);
    gpio.write(digit_pins.d2, disabled_level);
    gpio.write(digit_pins.d3, disabled_level);
    gpio.write(digit_pins.d4, disabled_level);
}

fn enableDigit(comptime digit_pins: DigitPins4, comptime common: Common, index: u8) void {
    const enabled_level = common == .anode;

    switch (index & 0x03) {
        0 => gpio.write(digit_pins.d1, enabled_level),
        1 => gpio.write(digit_pins.d2, enabled_level),
        2 => gpio.write(digit_pins.d3, enabled_level),
        else => gpio.write(digit_pins.d4, enabled_level),
    }
}

fn levelForSegment(on_level: bool, enabled: bool) bool {
    return if (enabled) on_level else !on_level;
}

fn hexChar(value: u8) u8 {
    return if (value < 10) '0' + value else 'A' + (value - 10);
}

fn patternForChar(char: u8) u8 {
    const normalized = if (char >= 'a' and char <= 'z') char - ('a' - 'A') else char;

    return switch (normalized) {
        '0' => segment_a | segment_b | segment_c | segment_d | segment_e | segment_f,
        '1' => segment_b | segment_c,
        '2' => segment_a | segment_b | segment_d | segment_e | segment_g,
        '3' => segment_a | segment_b | segment_c | segment_d | segment_g,
        '4' => segment_b | segment_c | segment_f | segment_g,
        '5' => segment_a | segment_c | segment_d | segment_f | segment_g,
        '6' => segment_a | segment_c | segment_d | segment_e | segment_f | segment_g,
        '7' => segment_a | segment_b | segment_c,
        '8' => segment_a | segment_b | segment_c | segment_d | segment_e | segment_f | segment_g,
        '9' => segment_a | segment_b | segment_c | segment_d | segment_f | segment_g,
        'A' => segment_a | segment_b | segment_c | segment_e | segment_f | segment_g,
        'B' => segment_c | segment_d | segment_e | segment_f | segment_g,
        'C' => segment_a | segment_d | segment_e | segment_f,
        'D' => segment_b | segment_c | segment_d | segment_e | segment_g,
        'E' => segment_a | segment_d | segment_e | segment_f | segment_g,
        'F' => segment_a | segment_e | segment_f | segment_g,
        'H' => segment_b | segment_c | segment_e | segment_f | segment_g,
        'I' => segment_b | segment_c,
        'J' => segment_b | segment_c | segment_d | segment_e,
        'L' => segment_d | segment_e | segment_f,
        'N' => segment_c | segment_e | segment_g,
        'O' => segment_a | segment_b | segment_c | segment_d | segment_e | segment_f,
        'P' => segment_a | segment_b | segment_e | segment_f | segment_g,
        'R' => segment_e | segment_g,
        'S' => segment_a | segment_c | segment_d | segment_f | segment_g,
        'T' => segment_d | segment_e | segment_f | segment_g,
        'U' => segment_b | segment_c | segment_d | segment_e | segment_f,
        '-' => segment_g,
        '_' => segment_d,
        ' ' => 0,
        else => 0,
    };
}
