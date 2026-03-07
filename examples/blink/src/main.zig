const avr = @import("avr_zig");
const gpio = avr.hal.gpio;
const time = avr.hal.time;

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
