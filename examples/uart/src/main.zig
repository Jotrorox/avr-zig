const avr = @import("avr_zig");
const time = avr.hal.time;
const uart = avr.hal.uart;

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
