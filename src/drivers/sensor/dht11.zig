const gpio = @import("../../hal/gpio.zig");
const time = @import("../../hal/time.zig");
const platform = @import("../../platform/current.zig");

const sample_offset_us: u16 = 35;
const response_timeout_us: u16 = 120;
const bit_timeout_us: u16 = 90;
const cycles_per_us = platform.CPU_FREQ / 1_000_000;

pub const Error = error{
    Timeout,
    Checksum,
};

pub const Reading = struct {
    humidity: u8,
    humidity_decimal: u8,
    temperature: u8,
    temperature_decimal: u8,
};

/// Reads one sensor sample.
pub fn read(comptime pin: gpio.Pin) Error!Reading {
    var bytes = [_]u8{ 0, 0, 0, 0, 0 };

    startSignal(pin);
    try awaitResponse(pin);

    for (&bytes) |*byte| {
        byte.* = try readByte(pin);
    }

    const checksum = bytes[0] +% bytes[1] +% bytes[2] +% bytes[3];
    if (checksum != bytes[4]) {
        return error.Checksum;
    }

    return .{
        .humidity = bytes[0],
        .humidity_decimal = bytes[1],
        .temperature = bytes[2],
        .temperature_decimal = bytes[3],
    };
}

fn startSignal(comptime pin: gpio.Pin) void {
    gpio.init(pin, .out);
    gpio.write(pin, true);
    delayUs(5);
    gpio.write(pin, false);
    time.sleep(20);
    gpio.write(pin, true);
    delayUs(40);
    gpio.init(pin, .in);
    gpio.setPullup(pin, false);
}

fn awaitResponse(comptime pin: gpio.Pin) Error!void {
    try waitForState(pin, false, response_timeout_us);
    try waitForState(pin, true, response_timeout_us);
    try waitForState(pin, false, response_timeout_us);
}

fn readByte(comptime pin: gpio.Pin) Error!u8 {
    var value: u8 = 0;

    inline for (0..8) |_| {
        value <<= 1;
        if (try readBit(pin)) {
            value |= 1;
        }
    }

    return value;
}

fn readBit(comptime pin: gpio.Pin) Error!bool {
    try waitForState(pin, true, bit_timeout_us);
    delayUs(sample_offset_us);

    const bit = gpio.read(pin);
    try waitForState(pin, false, response_timeout_us);
    return bit;
}

fn waitForState(comptime pin: gpio.Pin, expected: bool, timeout_us: u16) Error!void {
    var elapsed: u16 = 0;
    while (gpio.read(pin) != expected) : (elapsed += 1) {
        if (elapsed >= timeout_us) {
            return error.Timeout;
        }
        delayUs(1);
    }
}

fn delayUs(us: u16) void {
    var remaining = us;
    while (remaining > 0) : (remaining -= 1) {
        inline for (0..cycles_per_us) |_| {
            asm volatile ("nop");
        }
    }
}
