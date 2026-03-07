const avr = @import("avr_zig");
const i2c = avr.hal.i2c;
const time = avr.hal.time;
const uart = avr.hal.uart;

pub const interrupts = struct {
    pub fn TIMER0_COMPA() void {
        time.handleTimer0CompareA();
    }
};

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
