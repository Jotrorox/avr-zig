const std = @import("std");
const avr = @import("avr_zig");
const gpio = avr.hal.gpio;
const i2c = avr.hal.i2c;
const time = avr.hal.time;
const uart = avr.hal.uart;
const ssd1306 = avr.drivers.display.ssd1306;
const Runtime = avr.runtime.Entry(App);

const Display128x64 = ssd1306.Display(128, 64);

pub const App = struct {
    var current: u8 = '!';
    var display: Display128x64 = .{};

    pub const interrupts = struct {
        pub fn TIMER0_COMPA() void {
            time.handleTimer0CompareA();
        }
    };

    pub fn main() void {
        uart.init(115200);
        i2c.init();
        gpio.init(.D13, .out);

        scanI2cBus();
        initDisplay();

        while (true) {
            uart.write_ch(current);
            current = if (current < '~') current + 1 else '!';
            if (current == '!') {
                uart.write("\r\n");
            }

            gpio.toggle(.D13);
            time.sleep(500);
        }
    }

    fn initDisplay() void {
        if (!display.init()) {
            uart.write("SSD1306 init failed\r\n");
            return;
        }

        display.clear(.off);
        display.drawPixel(64, 32, .on);
        display.drawLine(0, 0, 127, 63, .on);
        display.drawLine(0, 63, 127, 0, .on);
        display.drawLine(0, 0, 127, 0, .on);
        display.drawLine(0, 63, 127, 63, .on);
        display.drawLine(0, 0, 0, 63, .on);
        display.drawLine(127, 0, 127, 63, .on);

        if (display.present()) {
            uart.write("SSD1306 demo drawn\r\n");
        } else {
            uart.write("SSD1306 update failed\r\n");
        }
    }

    fn scanI2cBus() void {
        uart.write("I2C scan:\r\n");
        const count = i2c.scan(reportI2cDevice);
        if (count == 0) {
            uart.write("  no devices found\r\n");
        }
    }

    fn reportI2cDevice(address: u7) void {
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
