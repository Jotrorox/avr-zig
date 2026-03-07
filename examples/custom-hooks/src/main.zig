const std = @import("std");
const avr = @import("avr_zig");
const gpio = avr.hal.gpio;
const time = avr.hal.time;
const uart = avr.hal.uart;

const DemoMode = enum {
    panic,
    unhandled_vector,
};

const demo_mode: DemoMode = .panic;

pub const interrupts = struct {
    pub fn TIMER0_COMPA() void {
        time.handleTimer0CompareA();
    }
};

pub fn main() void {
    uart.init(115200);
    gpio.init(.D13, .out);

    uart.write("custom-hooks example\r\n");
    uart.write("set demo_mode to .panic or .unhandled_vector\r\n");
    blinkCountdown();

    switch (demo_mode) {
        .panic => @panic("custom panic override triggered"),
        .unhandled_vector => {
            unhandledVector();
            while (true) {}
        },
    }
}

pub fn unhandledVector() void {
    uart.write("custom unhandled vector override\r\n");
    blinkForever(100);
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    _ = error_return_trace;
    _ = return_address;

    uart.write("custom panic override: ");
    uart.write(msg);
    uart.write("\r\n");
    blinkForever(350);
}

fn blinkCountdown() void {
    var count: u8 = 3;
    while (count > 0) : (count -= 1) {
        gpio.toggle(.D13);
        time.sleep(250);
        gpio.toggle(.D13);
        time.sleep(750);
    }
}

fn blinkForever(delay_ms: u16) noreturn {
    while (true) {
        gpio.toggle(.D13);
        time.sleep(delay_ms);
    }
}
