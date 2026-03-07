const avr = @import("avr_zig");
const gpio = avr.hal.gpio;
const i2c = avr.hal.i2c;
const time = avr.hal.time;
const uart = avr.hal.uart;
const ssd1306 = avr.drivers.display.ssd1306;

const Display128x64 = ssd1306.Display(128, 64);

var current: u8 = '!';
var display: Display128x64 = .{};

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
    display.drawRect(0, 0, 128, 64, .on);
    display.fillRect(4, 4, 120, 12, .on);
    display.drawText(12, 6, "AVR ZIG", .off, ssd1306.default_font);

    display.drawRect(6, 22, 116, 16, .on);
    display.drawText(12, 27, "SSD1306 DEMO", .on, ssd1306.default_font);

    display.drawLine(8, 48, 56, 48, .on);
    display.drawLine(8, 52, 56, 52, .on);
    display.drawLine(8, 56, 56, 56, .on);

    display.fillRect(78, 44, 40, 14, .on);
    display.drawText(88, 48, "OK", .off, ssd1306.default_font);

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
