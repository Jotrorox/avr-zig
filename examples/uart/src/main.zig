const std = @import("std");
const avr = @import("avr_zig");
const time = avr.hal.time;
const uart = avr.hal.uart;
const Runtime = avr.runtime.Entry(App);

pub const App = struct {
    pub const interrupts = struct {
        pub fn TIMER0_COMPA() void {
            time.handleTimer0CompareA();
        }
    };

    pub fn main() void {
        var current: u8 = 'A';
        uart.init(115200);

        while (true) {
            uart.write("UART example: ");
            uart.write_ch(current);
            uart.write("\r\n");

            current = if (current == 'Z') 'A' else current + 1;
            time.sleep(1000);
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
