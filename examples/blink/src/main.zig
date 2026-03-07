const std = @import("std");
const avr = @import("avr_zig");
const gpio = avr.hal.gpio;
const time = avr.hal.time;
const Runtime = avr.runtime.Entry(App);

pub const App = struct {
    pub const interrupts = struct {
        pub fn TIMER0_COMPA() void {
            time.handleTimer0CompareA();
        }
    };

    pub fn main() void {
        gpio.init(.D13, .out);

        while (true) {
            gpio.toggle(.D13);
            time.sleep(500);
        }
    }
};

export fn _unhandled_vector() void {
    Runtime.unhandledVector();
}

pub export fn _start() noreturn {
    Runtime.start();
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    Runtime.panic(msg, error_return_trace, return_address);
}
